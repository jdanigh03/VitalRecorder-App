import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/reminder.dart';
import '../models/user.dart';
import 'calendar_service.dart';
import 'cuidador_service.dart';
import 'reports_cache.dart';

class AnalyticsService with CacheableMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CalendarService _calendarService = CalendarService();
  final CuidadorService _cuidadorService = CuidadorService();

  User? get currentUser => _auth.currentUser;

  /// Determina si un recordatorio está realmente vencido
  /// Un recordatorio NO está vencido si:
  /// 1. Está completado
  /// 2. Su fecha/hora es futura
  /// 3. Fue creado después de su hora programada el mismo día
  bool isReallyOverdue(Reminder reminder, DateTime now) {
    if (reminder.isCompleted) return false;
    
    final scheduledDateTime = reminder.dateTime.toLocal();
    final createdAt = reminder.createdAt?.toLocal();
    
    // Si la fecha programada es futura, no está vencido
    if (scheduledDateTime.isAfter(now)) return false;
    
    // Si es el mismo día y se creó después de la hora programada, no está vencido
    final scheduledDay = DateTime(scheduledDateTime.year, scheduledDateTime.month, scheduledDateTime.day);
    final today = DateTime(now.year, now.month, now.day);
    
    if (scheduledDay.isAtSameMomentAs(today) && createdAt != null) {
      if (createdAt.isAfter(scheduledDateTime)) {
        return false; // Creado después de la hora programada
      }
    }
    
    return scheduledDateTime.isBefore(now);
  }

  /// Calcula estadísticas reales para el período especificado
  Future<Map<String, dynamic>> calculateRealStats({
    required DateTime startDate,
    required DateTime endDate,
    List<Reminder>? allReminders,
    List<UserModel>? allPatients,
  }) async {
    final cacheKey = cache.generateAnalyticsKey(
      operation: 'calculateRealStats',
      startDate: startDate,
      endDate: endDate,
    );

    return await withCache(cacheKey, () async {
      final now = DateTime.now();
      final reminders = allReminders ?? await _cuidadorService.getAllRemindersFromPatients();
      final patients = allPatients ?? await _cuidadorService.getPacientes();

      // Filtrar recordatorios por período
      final periodReminders = reminders.where((r) {
        return r.dateTime.isAfter(startDate.subtract(Duration(seconds: 1))) &&
               r.dateTime.isBefore(endDate.add(Duration(days: 1)));
      }).toList();

      // Calcular métricas básicas
      final totalReminders = periodReminders.length;
      final completedReminders = periodReminders.where((r) => r.isCompleted).length;
      final overdueReminders = periodReminders.where((r) => isReallyOverdue(r, now)).length;
      final todayReminders = periodReminders.where((r) {
        final today = DateTime(now.year, now.month, now.day);
        final reminderDay = DateTime(r.dateTime.year, r.dateTime.month, r.dateTime.day);
        return reminderDay.isAtSameMomentAs(today);
      }).length;

      // Calcular adherencia real (solo sobre recordatorios que debieron ocurrir)
      final dueReminders = periodReminders.where((r) {
        return r.isCompleted || isReallyOverdue(r, now);
      }).toList();
      
      final adherenceRate = dueReminders.isNotEmpty 
          ? ((completedReminders / dueReminders.length) * 100).round()
          : 0;

      // Distribución por tipos
      final medicationCount = periodReminders.where((r) => 
        r.type.toLowerCase().contains('medic') || r.type == 'Medicación'
      ).length;
      final taskCount = periodReminders.where((r) => 
        r.type.toLowerCase().contains('tarea') || r.type == 'Tarea'
      ).length;
      final appointmentCount = periodReminders.where((r) => 
        r.type.toLowerCase().contains('cita') || r.type == 'Cita'
      ).length;

      return {
        'totalPacientes': patients.length,
        'totalRecordatorios': totalReminders,
        'recordatoriosActivos': reminders.where((r) => r.isActive).length,
        'completadosHoy': periodReminders.where((r) {
          final today = DateTime(now.year, now.month, now.day);
          final reminderDay = DateTime(r.dateTime.year, r.dateTime.month, r.dateTime.day);
          return reminderDay.isAtSameMomentAs(today) && r.isCompleted;
        }).length,
        'alertasHoy': todayReminders - periodReminders.where((r) {
          final today = DateTime(now.year, now.month, now.day);
          final reminderDay = DateTime(r.dateTime.year, r.dateTime.month, r.dateTime.day);
          return reminderDay.isAtSameMomentAs(today) && r.isCompleted;
        }).length,
        'adherenciaGeneral': adherenceRate,
        'recordatoriosHoy': todayReminders,
        'vencidos': overdueReminders,
        'completados': completedReminders,
        'recordatoriosPorTipo': {
          'medicacion': medicationCount,
          'tareas': taskCount,
          'citas': appointmentCount,
        },
      };
    });
  }

  /// Genera datos para gráfico de tendencias de adherencia
  Future<List<Map<String, dynamic>>> getTrendData({
    required DateTime startDate,
    required DateTime endDate,
    List<Reminder>? allReminders,
  }) async {
    final cacheKey = cache.generateAnalyticsKey(
      operation: 'getTrendData',
      startDate: startDate,
      endDate: endDate,
    );

    return await withCache(cacheKey, () async {
      final reminders = allReminders ?? await _cuidadorService.getAllRemindersFromPatients();
      final trendData = <Map<String, dynamic>>[];
      
      // Generar datos por día
      for (var date = startDate; date.isBefore(endDate) || date.isAtSameMomentAs(endDate); 
           date = date.add(Duration(days: 1))) {
        
        final dayStart = DateTime(date.year, date.month, date.day);
        final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);
        
        final dayReminders = reminders.where((r) => 
          r.dateTime.isAfter(dayStart.subtract(Duration(seconds: 1))) &&
          r.dateTime.isBefore(dayEnd.add(Duration(seconds: 1)))
        ).toList();
        
        final completed = dayReminders.where((r) => r.isCompleted).length;
        final due = dayReminders.where((r) => 
          r.isCompleted || isReallyOverdue(r, DateTime.now())
        ).length;
        
        final adherence = due > 0 ? (completed / due * 100).round() : 0;
        
        trendData.add({
          'date': date,
          'adherence': adherence,
          'completed': completed,
          'total': dayReminders.length,
          'overdue': dayReminders.where((r) => isReallyOverdue(r, DateTime.now())).length,
        });
      }
      
      return trendData;
    });
  }

  /// Calcula estadísticas por paciente
  Future<List<Map<String, dynamic>>> getPatientStats({
    required DateTime startDate,
    required DateTime endDate,
    List<Reminder>? allReminders,
    List<UserModel>? allPatients,
  }) async {
    try {
      final now = DateTime.now();
      final reminders = allReminders ?? await _cuidadorService.getAllRemindersFromPatients();
      final patients = allPatients ?? await _cuidadorService.getPacientes();
      
      final patientStats = <Map<String, dynamic>>[];
      
      for (final patient in patients) {
        final patientReminders = reminders.where((r) => 
          r.userId == patient.userId &&
          r.dateTime.isAfter(startDate.subtract(Duration(seconds: 1))) &&
          r.dateTime.isBefore(endDate.add(Duration(days: 1)))
        ).toList();
        
        final total = patientReminders.length;
        final completed = patientReminders.where((r) => r.isCompleted).length;
        final overdue = patientReminders.where((r) => isReallyOverdue(r, now)).length;
        final pending = patientReminders.where((r) => 
          !r.isCompleted && !isReallyOverdue(r, now)
        ).length;
        
        final due = patientReminders.where((r) => 
          r.isCompleted || isReallyOverdue(r, now)
        ).length;
        
        final adherence = due > 0 ? ((completed / due) * 100).round() : 0;
        
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
  Map<String, dynamic> getTypeDistribution(List<Reminder> reminders) {
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
    List<Reminder>? allReminders,
    List<UserModel>? allPatients,
  }) async {
    try {
      final now = DateTime.now();
      final reminders = allReminders ?? await _cuidadorService.getAllRemindersFromPatients();
      final patients = allPatients ?? await _cuidadorService.getPacientes();
      
      final alerts = <Map<String, dynamic>>[];
      
      for (final reminder in reminders) {
        if (isReallyOverdue(reminder, now)) {
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
          final overdueDuration = now.difference(reminder.dateTime);
          
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