import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/reminder_new.dart';
import '../models/user.dart';
import '../models/reminder_confirmation.dart';
import '../reminder_service_new.dart';
import 'cuidador_service.dart';
import 'reports_cache.dart';

class AnalyticsService with CacheableMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ReminderServiceNew _reminderService = ReminderServiceNew();
  final CuidadorService _cuidadorService = CuidadorService();

  User? get currentUser => _auth.currentUser;

  /// Calcula estadísticas reales para el período especificado usando confirmaciones
  Future<Map<String, dynamic>> calculateRealStats({
    required DateTime startDate,
    required DateTime endDate,
    List<ReminderNew>? allReminders,
    List<UserModel>? allPatients,
    String? patientId,
  }) async {
    final cacheKey = cache.generateAnalyticsKey(
      operation: 'calculateRealStats',
      startDate: startDate,
      endDate: endDate,
      patientId: patientId,
    );

    return await withCache(cacheKey, () async {
      var reminders = allReminders ?? await _cuidadorService.getAllRemindersFromPatients();
      var patients = allPatients ?? await _cuidadorService.getPacientes();

      if (patientId != null) {
        reminders = reminders.where((r) => r.userId == patientId).toList();
        patients = patients.where((p) => p.userId == patientId).toList();
      }

      // IMPORTANTE: Filtrar recordatorios inactivos/archivados para las estadísticas
      reminders = reminders.where((r) => r.isActive).toList();

      // Obtener todas las confirmaciones del rango
      final confirmations = await _reminderService.getConfirmationsForRange(
        startDate: startDate,
        endDate: endDate,
        patientId: patientId,
      );

      // Filtrar confirmaciones pausadas
      final activeConfirmations = confirmations.where((c) => c.status != ConfirmationStatus.PAUSED).toList();
      
      final confirmedCount = activeConfirmations.where((c) => c.status == ConfirmationStatus.CONFIRMED).length;
      
      // Considerar vencidos los que tienen estado MISSED o los PENDING que ya pasaron
      final now = DateTime.now();
      final missedCount = activeConfirmations.where((c) => 
        c.status == ConfirmationStatus.MISSED || 
        (c.status == ConfirmationStatus.PENDING && c.scheduledTime.isBefore(now))
      ).length;
      
      // Pendientes son solo los futuros
      final pendingCount = activeConfirmations.where((c) => 
        c.status == ConfirmationStatus.PENDING && c.scheduledTime.isAfter(now)
      ).length;
      
      // Calcular adherencia: Confirmados / (Confirmados + Omitidos)
      final totalForAdherence = confirmedCount + missedCount;
      final adherenceRate = totalForAdherence > 0 
          ? (confirmedCount / totalForAdherence * 100).round() 
          : 0;

      // Completados HOY
      final startOfToday = DateTime(now.year, now.month, now.day);
      final endOfToday = startOfToday.add(Duration(days: 1));
      
      final completedToday = confirmations.where((c) => 
        c.status == ConfirmationStatus.CONFIRMED &&
        c.scheduledTime.isAfter(startOfToday) &&
        c.scheduledTime.isBefore(endOfToday)
      ).length;

      // Alertas HOY
      final alertsToday = confirmations.where((c) => 
        (c.status == ConfirmationStatus.MISSED || c.status == ConfirmationStatus.PENDING) &&
        c.scheduledTime.isAfter(startOfToday) &&
        c.scheduledTime.isBefore(endOfToday)
      ).length;

      // Distribución por tipos (Consolidado)
      final medicationCount = reminders.where((r) => 
        r.type.toLowerCase().contains('medic') || r.type == 'Medicación'
      ).length;
      
      final activityCount = reminders.where((r) => 
        r.type.toLowerCase().contains('activ') || r.type == 'Actividad' ||
        r.type.toLowerCase().contains('tarea') || r.type == 'Tarea' ||
        r.type.toLowerCase().contains('cita') || r.type == 'Cita'
      ).length;

      return {
        'totalPacientes': patients.length,
        'totalRecordatorios': reminders.length,
        'recordatoriosActivos': reminders.where((r) => !r.isPaused).length,
        'completadosHoy': completedToday,
        'alertasHoy': alertsToday,
        'adherenciaGeneral': adherenceRate,
        'recordatoriosHoy': 0,
        'vencidos': missedCount,
        'completados': confirmedCount,
        'pendientes': pendingCount,
        'recordatoriosPorTipo': {
          'medicacion': medicationCount,
          'actividad': activityCount,
        },
      };
    });
  }

  /// Genera datos para gráfico de tendencias de adherencia usando confirmaciones
  Future<List<Map<String, dynamic>>> getTrendData({
    required DateTime startDate,
    required DateTime endDate,
    List<ReminderNew>? allReminders,
    String? patientId,
  }) async {
    final cacheKey = cache.generateAnalyticsKey(
      operation: 'getTrendData',
      startDate: startDate,
      endDate: endDate,
    );

    return await withCache(cacheKey, () async {
      final confirmations = await _reminderService.getConfirmationsForRange(
        startDate: startDate,
        endDate: endDate,
        patientId: patientId,
      );

      final trendData = <Map<String, dynamic>>[];
      
      // Iterar por día
      for (var date = startDate; date.isBefore(endDate) || date.isAtSameMomentAs(endDate); 
           date = date.add(Duration(days: 1))) {
        
        final dayStart = DateTime(date.year, date.month, date.day);
        final dayEnd = dayStart.add(Duration(days: 1));
        
        // Filtrar confirmaciones del día
        final dayConfirmations = confirmations.where((c) => 
          c.scheduledTime.isAfter(dayStart.subtract(Duration(milliseconds: 1))) && 
          c.scheduledTime.isBefore(dayEnd) &&
          c.status != ConfirmationStatus.PAUSED
        ).toList();
        
        final confirmed = dayConfirmations.where((c) => c.status == ConfirmationStatus.CONFIRMED).length;
        
        // Considerar vencidos los que tienen estado MISSED o los PENDING que ya pasaron (si el día ya pasó)
        final missed = dayConfirmations.where((c) => 
          c.status == ConfirmationStatus.MISSED || 
          (c.status == ConfirmationStatus.PENDING && c.scheduledTime.isBefore(DateTime.now()))
        ).length;
        
        final total = confirmed + missed;
        
        final adherence = total > 0 ? (confirmed / total * 100).round() : 0;
        
        trendData.add({
          'date': date,
          'adherence': adherence,
          'completed': confirmed,
          'total': dayConfirmations.length,
          'overdue': missed,
        });
      }
      
      return trendData;
    });
  }

  /// Calcula estadísticas por paciente usando confirmaciones
  Future<List<Map<String, dynamic>>> getPatientStats({
    required DateTime startDate,
    required DateTime endDate,
    List<ReminderNew>? allReminders,
    List<UserModel>? allPatients,
  }) async {
    try {
      final reminders = allReminders ?? await _cuidadorService.getAllRemindersFromPatients();
      final patients = allPatients ?? await _cuidadorService.getPacientes();
      
      // Obtener todas las confirmaciones del rango
      final allConfirmations = await _reminderService.getConfirmationsForRange(
        startDate: startDate,
        endDate: endDate,
      );

      final patientStats = <Map<String, dynamic>>[];
      
      for (final patient in patients) {
        final patientId = patient.userId;
        
        // Filtrar confirmaciones del paciente
        final patientConfirmations = allConfirmations.where((c) => c.userId == patientId).toList();
        final activeConfirmations = patientConfirmations.where((c) => c.status != ConfirmationStatus.PAUSED).toList();
        
        final confirmed = activeConfirmations.where((c) => c.status == ConfirmationStatus.CONFIRMED).length;
        
        final missed = activeConfirmations.where((c) => 
          c.status == ConfirmationStatus.MISSED || 
          (c.status == ConfirmationStatus.PENDING && c.scheduledTime.isBefore(DateTime.now()))
        ).length;
        
        final pending = activeConfirmations.where((c) => 
          c.status == ConfirmationStatus.PENDING && c.scheduledTime.isAfter(DateTime.now())
        ).length;
        
        final totalFinished = confirmed + missed;
        final adherence = totalFinished > 0 ? (confirmed / totalFinished * 100).round() : 0;
        
        final patientReminders = reminders.where((r) => r.userId == patientId).toList();
        
        // Distribución por tipos para este paciente
        final medicationCount = patientReminders.where((r) => 
          r.type.toLowerCase().contains('medic') || r.type == 'Medicación'
        ).length;
        
        final activityCount = patientReminders.where((r) => 
          r.type.toLowerCase().contains('activ') || r.type == 'Actividad' ||
          r.type.toLowerCase().contains('tarea') || r.type == 'Tarea' ||
          r.type.toLowerCase().contains('cita') || r.type == 'Cita'
        ).length;
        
        patientStats.add({
          'patient': patient,
          'totalRecordatorios': patientReminders.length,
          'totalEventos': patientConfirmations.length,
          'completados': confirmed,
          'vencidos': missed,
          'pendientes': pending,
          'adherencia': adherence,
          'recordatoriosPorTipo': {
            'medicacion': medicationCount,
            'actividad': activityCount,
          },
          'reminders': patientReminders,
        });
      }
      
      // Ordenar por adherencia descendente
      patientStats.sort((a, b) => b['adherencia'].compareTo(a['adherencia']));
      
      return patientStats;
    } catch (e) {
      print('Error calculando estadísticas por paciente: $e');
      return [];
    }
  }

  /// Genera datos para gráfico de distribución por tipos
  Map<String, dynamic> getTypeDistribution(List<ReminderNew> reminders) {
    final medication = reminders.where((r) => 
      r.type.toLowerCase().contains('medic') || r.type == 'Medicación'
    ).length;
    
    final activity = reminders.where((r) => 
      r.type.toLowerCase().contains('activ') || r.type == 'Actividad' ||
      r.type.toLowerCase().contains('tarea') || r.type == 'Tarea' ||
      r.type.toLowerCase().contains('cita') || r.type == 'Cita'
    ).length;
    
    final others = reminders.length - medication - activity;
    
    return {
      'medicacion': medication,
      'actividad': activity,
      'otros': others,
    };
  }

  /// Obtiene alertas críticas reales
  Future<List<Map<String, dynamic>>> getCriticalAlerts({
    List<ReminderNew>? allReminders,
    List<UserModel>? allPatients,
  }) async {
    try {
      final now = DateTime.now();
      final reminders = allReminders ?? await _cuidadorService.getAllRemindersFromPatients();
      final patients = allPatients ?? await _cuidadorService.getPacientes();
      
      // Obtener confirmaciones pendientes o vencidas recientes
      final startOfCheck = now.subtract(Duration(days: 1)); // Revisar últimas 24h
      final confirmations = await _reminderService.getConfirmationsForRange(
        startDate: startOfCheck,
        endDate: now,
      );

      final alerts = <Map<String, dynamic>>[];
      
      for (final confirmation in confirmations) {
        if (confirmation.status == ConfirmationStatus.CONFIRMED || 
            confirmation.status == ConfirmationStatus.PAUSED) continue;
            
        if (confirmation.status == ConfirmationStatus.PENDING && 
            confirmation.scheduledTime.isAfter(now)) continue;

        final reminder = reminders.firstWhere(
          (r) => r.id == confirmation.reminderId,
          orElse: () => ReminderNew(
            id: 'unknown', title: 'Desconocido', description: '', type: 'other', 
            startDate: now, endDate: now, intervalType: IntervalType.HOURS, intervalValue: 1, dailyScheduleTimes: [], isActive: false, isPaused: false
          ),
        );
        
        if (reminder.id == 'unknown') continue;

        final patient = patients.firstWhere(
          (p) => p.userId == confirmation.userId,
          orElse: () => UserModel(
            email: 'unknown@example.com',
            persona: UserPersona(nombres: 'Desconocido', apellidos: ''),
            settings: UserSettings(telefono: ''),
            createdAt: DateTime.now(),
          ),
        );
        
        final overdueDuration = now.difference(confirmation.scheduledTime);
        
        alerts.add({
          'reminder': reminder,
          'patient': patient,
          'overdueDuration': overdueDuration,
          'severity': _getAlertSeverity(overdueDuration),
          'scheduledTime': confirmation.scheduledTime,
        });
      }
      
      alerts.sort((a, b) {
        final severityComparison = b['severity'].compareTo(a['severity']);
        if (severityComparison != 0) return severityComparison;
        return (b['overdueDuration'] as Duration).compareTo(a['overdueDuration'] as Duration);
      });
      
      return alerts;
    } catch (e) {
      print('Error obteniendo alertas críticas: $e');
      return [];
    }
  }
  
  int _getAlertSeverity(Duration overdueDuration) {
    if (overdueDuration.inHours >= 24) return 3; // Crítica
    if (overdueDuration.inHours >= 6) return 2;  // Alta
    if (overdueDuration.inHours >= 2) return 1;  // Media
    return 0; // Baja
  }
}