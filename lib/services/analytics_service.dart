import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/reminder_new.dart';
import '../models/user.dart';
import '../reminder_service_new.dart';
import 'cuidador_service.dart';
import 'reports_cache.dart';

class AnalyticsService with CacheableMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ReminderServiceNew _reminderService = ReminderServiceNew();
  final CuidadorService _cuidadorService = CuidadorService();

  User? get currentUser => _auth.currentUser;

  // Método obsoleto - las estadísticas ahora usan confirmaciones individuales

  /// Calcula estadísticas reales para el período especificado
  Future<Map<String, dynamic>> calculateRealStats({
    required DateTime startDate,
    required DateTime endDate,
    List<ReminderNew>? allReminders,
    List<UserModel>? allPatients,
  }) async {
    final cacheKey = cache.generateAnalyticsKey(
      operation: 'calculateRealStats',
      startDate: startDate,
      endDate: endDate,
    );

    return await withCache(cacheKey, () async {
      final reminders = allReminders ?? await _cuidadorService.getAllRemindersFromPatients();
      final patients = allPatients ?? await _cuidadorService.getPacientes();

      // Usar el servicio de cuidador que ya calcula estadísticas con el nuevo sistema
      final stats = await _cuidadorService.getCuidadorStats();
      
      // Distribución por tipos
      final medicationCount = reminders.where((r) => 
        r.type.toLowerCase().contains('medic') || r.type == 'Medicación'
      ).length;
      final taskCount = reminders.where((r) => 
        r.type.toLowerCase().contains('tarea') || r.type == 'Tarea'
      ).length;
      final appointmentCount = reminders.where((r) => 
        r.type.toLowerCase().contains('cita') || r.type == 'Cita'
      ).length;

      return {
        'totalPacientes': patients.length,
        'totalRecordatorios': stats['totalRecordatorios'] ?? 0,
        'recordatoriosActivos': stats['recordatoriosActivos'] ?? 0,
        'completadosHoy': stats['completadosHoy'] ?? 0,
        'alertasHoy': stats['alertasHoy'] ?? 0,
        'adherenciaGeneral': stats['adherenciaGeneral'] ?? 0,
        'recordatoriosHoy': stats['recordatoriosHoy'] ?? 0,
        'vencidos': 0,
        'completados': stats['completadosHoy'] ?? 0,
        'recordatoriosPorTipo': {
          'medicacion': medicationCount,
          'tareas': taskCount,
          'citas': appointmentCount,
        },
      };
    });
  }

  /// Genera datos para gráfico de tendencias de adherencia
  /// TODO: Actualizar para usar confirmaciones del nuevo sistema
  Future<List<Map<String, dynamic>>> getTrendData({
    required DateTime startDate,
    required DateTime endDate,
    List<ReminderNew>? allReminders,
  }) async {
    final cacheKey = cache.generateAnalyticsKey(
      operation: 'getTrendData',
      startDate: startDate,
      endDate: endDate,
    );

    return await withCache(cacheKey, () async {
      final reminders = allReminders ?? await _cuidadorService.getAllRemindersFromPatients();
      final trendData = <Map<String, dynamic>>[];
      
      // Generar datos por día - TEMPORAL: sin verificar completados
      for (var date = startDate; date.isBefore(endDate) || date.isAtSameMomentAs(endDate); 
           date = date.add(Duration(days: 1))) {
        
        final dayStart = DateTime(date.year, date.month, date.day);
        final dayEnd = dayStart.add(Duration(days: 1));
        
        final dayReminders = reminders.where((r) => 
          r.startDate.isBefore(dayEnd) && r.endDate.isAfter(dayStart)
        ).toList();
        
        // TODO: Obtener confirmaciones para calcular completados
        final completed = 0;
        final total = dayReminders.length;
        final adherence = 0;
        
        trendData.add({
          'date': date,
          'adherence': adherence,
          'completed': completed,
          'total': total,
          'overdue': 0,
        });
      }
      
      return trendData;
    });
  }

  /// Calcula estadísticas por paciente
  /// TODO: Actualizar para usar confirmaciones del nuevo sistema
  Future<List<Map<String, dynamic>>> getPatientStats({
    required DateTime startDate,
    required DateTime endDate,
    List<ReminderNew>? allReminders,
    List<UserModel>? allPatients,
  }) async {
    try {
      final now = DateTime.now();
      final reminders = allReminders ?? await _cuidadorService.getAllRemindersFromPatients();
      final patients = allPatients ?? await _cuidadorService.getPacientes();
      
      final patientStats = <Map<String, dynamic>>[];
      
      for (final patient in patients) {
        // Usar servicio de cuidador para obtener stats reales
        final stats = await _cuidadorService.getEstadisticasPaciente(patient.userId!);
        final patientReminders = reminders.where((r) => 
          r.userId == patient.userId
        ).toList();
        
        final total = stats['totalRecordatorios'] as int;
        final completed = stats['completados'] as int;
        final overdue = 0; // TODO
        final pending = stats['pendientes'] as int;
        final adherence = stats['adherencia'] as int;
        
        // Distribución por tipos para este paciente
        final medicationCount = patientReminders.where((r) => 
          r.type.toLowerCase().contains('medic') || r.type == 'Medicación'
        ).length;
        final taskCount = patientReminders.where((r) => 
          r.type.toLowerCase().contains('tarea') || r.type == 'Tarea'
        ).length;
        final appointmentCount = patientReminders.where((r) => 
          r.type.toLowerCase().contains('cita') || r.type == 'Cita'
        ).length;
        
        patientStats.add({
          'patient': patient,
          'totalRecordatorios': total,
          'completados': completed,
          'vencidos': overdue,
          'pendientes': pending,
          'adherencia': adherence,
          'recordatoriosPorTipo': {
            'medicacion': medicationCount,
            'tareas': taskCount,
            'citas': appointmentCount,
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
    final tasks = reminders.where((r) => 
      r.type.toLowerCase().contains('tarea') || r.type == 'Tarea'
    ).length;
    final appointments = reminders.where((r) => 
      r.type.toLowerCase().contains('cita') || r.type == 'Cita'
    ).length;
    final others = reminders.length - medication - tasks - appointments;
    
    return {
      'medicacion': medication,
      'tareas': tasks,
      'citas': appointments,
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
      
      final alerts = <Map<String, dynamic>>[];
      
      for (final reminder in reminders) {
        // Excluir recordatorios pausados de las alertas
        if (reminder.isPaused) continue;
        
        // TODO: Verificar vencimiento con confirmaciones
        final nextOccurrence = reminder.getNextOccurrence();
        final isOverdue = nextOccurrence == null || nextOccurrence.isBefore(now);
        
        if (isOverdue) {
          final patient = patients.firstWhere(
            (p) => p.userId == reminder.userId,
            orElse: () => UserModel(
              email: 'unknown@example.com',
              persona: UserPersona(nombres: 'Desconocido', apellidos: ''),
              settings: UserSettings(telefono: ''),
              createdAt: DateTime.now(),
            ),
          );
          
          // Calcular cuánto tiempo lleva vencido
          final overdueDuration = nextOccurrence != null ? now.difference(nextOccurrence) : Duration.zero;
          
          alerts.add({
            'reminder': reminder,
            'patient': patient,
            'overdueDuration': overdueDuration,
            'severity': _getAlertSeverity(overdueDuration),
          });
        }
      }
      
      // Ordenar por severidad y tiempo vencido
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
  
  /// Verifica si un recordatorio está realmente vencido
  /// TODO: Actualizar para verificar con confirmaciones
  bool isReallyOverdue(ReminderNew reminder, DateTime now) {
    // Obtener próxima ocurrencia
    final nextOccurrence = reminder.getNextOccurrence();
    if (nextOccurrence == null) {
      // No hay más ocurrencias futuras, verificar si el rango ya terminó
      return reminder.endDate.isBefore(now);
    }
    // No está vencido si tiene próxima ocurrencia futura
    return false;
  }

  int _getAlertSeverity(Duration overdueDuration) {
    if (overdueDuration.inHours >= 24) return 3; // Crítica
    if (overdueDuration.inHours >= 6) return 2;  // Alta
    if (overdueDuration.inHours >= 2) return 1;  // Media
    return 0; // Baja
  }

  Map<String, dynamic> _getEmptyStats() {
    return {
      'totalPacientes': 0,
      'totalRecordatorios': 0,
      'recordatoriosActivos': 0,
      'completadosHoy': 0,
      'alertasHoy': 0,
      'adherenciaGeneral': 0,
      'recordatoriosHoy': 0,
      'vencidos': 0,
      'completados': 0,
      'recordatoriosPorTipo': {
        'medicacion': 0,
        'tareas': 0,
        'citas': 0,
      },
    };
  }
}