import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/reminder.dart';
import 'bracelet_service.dart';

class ReminderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _remindersCollection {
    return _firestore.collection('reminders');
  }

  String? get _currentUserId {
    return _auth.currentUser?.uid;
  }

  /// Auto-sincronizar con la manilla si está conectada
  Future<void> _autoSyncWithBracelet() async {
    try {
      final braceletService = BraceletService();
      if (braceletService.isConnected) {
        print('Auto-sincronizando recordatorios con la manilla...');
        await braceletService.syncRemindersToBracelet();
        print('Auto-sincronización completada');
      }
    } catch (e) {
      print('Error en auto-sincronización: $e');
      // No lanzar el error, ya que la sincronización es opcional
    }
  }

  Future<bool> createReminder(Reminder reminder) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return false;
      final collection = _remindersCollection;
      final docId = reminder.id.isEmpty ? collection.doc().id : reminder.id;
      final newReminder = reminder.copyWith(id: docId, isActive: true);
      final dataMap = newReminder.toMap();
      dataMap['userId'] = userId;
      dataMap['dateTime'] = Timestamp.fromDate(newReminder.dateTime);
      dataMap['createdAt'] = FieldValue.serverTimestamp();
      await collection.doc(docId).set(dataMap);
      
      // Auto-sincronizar con la manilla
      await _autoSyncWithBracelet();
      
      return true;
    } catch (e) {
      print('Error creando recordatorio: $e');
      return false;
    }
  }

  Future<bool> updateReminder(Reminder reminder) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return false;
      final collection = _remindersCollection;
      final dataMap = reminder.toMap();
      dataMap['userId'] = userId;
      dataMap['dateTime'] = Timestamp.fromDate(reminder.dateTime);
      await collection.doc(reminder.id).update(dataMap);
      
      // Auto-sincronizar con la manilla
      await _autoSyncWithBracelet();
      
      return true;
    } catch (e) {
      print('Error actualizando recordatorio: $e');
      return false;
    }
  }

  // Borrado lógico: en lugar de borrar, se marca como inactivo
  Future<bool> deactivateReminder(String reminderId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return false;
      final collection = _remindersCollection;
      await collection.doc(reminderId).update({'isActive': false});
      
      // Auto-sincronizar con la manilla
      await _autoSyncWithBracelet();
      
      return true;
    } catch (e) {
      print('Error desactivando recordatorio: $e');
      return false;
    }
  }

  // Obtiene todos los recordatorios activos (sin filtro de fecha)
  Future<List<Reminder>> getAllReminders() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return [];
      final collection = _remindersCollection;
      
      // Consulta completa con ordenamiento (ahora que tenemos el índice)
      final snapshot = await collection
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .orderBy('dateTime', descending: false)
          .get();
          
      print('Consulta ejecutada exitosamente. Documentos encontrados: ${snapshot.docs.length}');
      
      final reminders = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        print('Procesando recordatorio: ${data['title']} - ${data['dateTime']}');
        return _convertTimestampToDateTime(data);
      }).toList();
      
      print('Recordatorios procesados exitosamente: ${reminders.length}');
      return reminders;
    } catch (e) {
      print('ERROR obteniendo recordatorios activos: $e');
      print('Stack trace: ${StackTrace.current}');
      
      if (e.toString().contains('INDEX_NOT_FOUND') || e.toString().contains('requires an index')) {
        print('*********************************************************************************');
        print('FIRESTORE: El error anterior probablemente indica que necesitas crear un índice.');
        print('Por favor, busca en los logs de la consola un enlace que empiece con:');
        print('https://console.firebase.google.com/project/.../database/firestore/indexes?create_composite=...');
        print('Copia ese enlace en tu navegador para crear el índice automáticamente.');
        print('*********************************************************************************');
      }
      return [];
    }
  }

  // Obtiene TODOS los recordatorios (activos e inactivos) para el historial
  Future<List<Reminder>> getReminderHistory() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return [];
      final collection = _remindersCollection;

      final snapshot = await collection
          .where('userId', isEqualTo: userId)
          .orderBy('dateTime', descending: true) // Más recientes primero
          .get();
          
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _convertTimestampToDateTime(data);
      }).toList();
    } catch (e) {
      print('Error obteniendo historial de recordatorios: $e');
      return [];
    }
  }

  Stream<List<Reminder>> getRemindersStream() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);
    final collection = _remindersCollection;

    return collection
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true) // Mostrar solo activos en la vista principal
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _convertTimestampToDateTime(data);
      }).toList();
    });
  }

  Reminder _convertTimestampToDateTime(Map<String, dynamic> data) {
    if (data['dateTime'] is Timestamp) {
      data['dateTime'] = (data['dateTime'] as Timestamp).toDate().toIso8601String();
    }
    return Reminder.fromMap(data);
  }

  Future<List<Reminder>> getRemindersByType(String type) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return [];
      final collection = _remindersCollection;

      final snapshot = await collection
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: type)
          .where('isActive', isEqualTo: true)
          .get();
          
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _convertTimestampToDateTime(data);
      }).toList();
    } catch (e) {
      print('Error obteniendo recordatorios por tipo: $e');
      return [];
    }
  }

  Future<List<Reminder>> getRemindersByDate(DateTime date) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return [];
      final collection = _remindersCollection;
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final snapshot = await collection
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _convertTimestampToDateTime(data);
      }).toList();
    } catch (e) {
      print('Error obteniendo recordatorios por fecha: $e');
      return [];
    }
  }

  Future<List<Reminder>> getRemindersForDateRange(DateTime startDate, DateTime endDate) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return [];
      final collection = _remindersCollection;

      final snapshot = await collection
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _convertTimestampToDateTime(data);
      }).toList();
    } catch (e) {
      print('Error obteniendo recordatorios por rango de fechas: $e');
      return [];
    }
  }

  Future<bool> markAsCompleted(String reminderId, bool isCompleted) async {
    try {
      final collection = _remindersCollection;
      await collection.doc(reminderId).update({
        'isCompleted': isCompleted,
      });
      
      // Auto-sincronizar con la manilla
      await _autoSyncWithBracelet();
      
      return true;
    } catch (e) {
      print('Error marcando recordatorio como completado: $e');
      return false;
    }
  }

  Future<Map<String, int>> getStatistics() async {
    try {
      final reminders = await getAllReminders();
      
      return {
        'total': reminders.length,
        'completados': reminders.where((r) => r.isCompleted).length,
        'pendientes': reminders.where((r) => !r.isCompleted).length,
        'medicacion': reminders.where((r) => r.type == 'Medicación').length,
        'tareas': reminders.where((r) => r.type == 'Tarea').length,
        'citas': reminders.where((r) => r.type == 'Cita').length,
      };
    } catch (e) {
      print('Error obteniendo estadísticas: $e');
      return {
        'total': 0,
        'completados': 0,
        'pendientes': 0,
        'medicacion': 0,
        'tareas': 0,
        'citas': 0,
      };
    }
  }

  // Función de debug para verificar todos los recordatorios en Firestore
  Future<void> debugReminders() async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        print('DEBUG: No hay usuario logueado');
        return;
      }
      
      print('=== DEBUG RECORDATORIOS ===');
      print('Usuario ID: $userId');
      
      // Consulta SIN filtros para ver todos los documentos del usuario
      final allSnapshot = await _remindersCollection
          .where('userId', isEqualTo: userId)
          .get();
      
      print('Total documentos encontrados: ${allSnapshot.docs.length}');
      
      for (final doc in allSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        print('---');
        print('ID: ${doc.id}');
        print('Título: ${data['title'] ?? 'Sin título'}');
        print('Activo: ${data['isActive'] ?? 'Sin campo isActive'}');
        print('Fecha: ${data['dateTime']?.runtimeType} - ${data['dateTime']}');
        print('Tipo: ${data['type'] ?? 'Sin tipo'}');
        print('UserId: ${data['userId'] ?? 'Sin userId'}');
      }
      print('=== FIN DEBUG ===');
      
    } catch (e) {
      print('Error en debug: $e');
    }
  }

  // Migrar recordatorios antiguos sin campo isActive
  Future<int> migrateOldReminders() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return 0;
      
      print('=== INICIANDO MIGRACIÓN ===');
      
      // Buscar documentos SIN el campo isActive
      final snapshot = await _remindersCollection
          .where('userId', isEqualTo: userId)
          .get();
      
      int migratedCount = 0;
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Si no tiene el campo isActive, agregarlo
        if (!data.containsKey('isActive')) {
          print('Migrando documento: ${doc.id} - ${data['title']}');
          
          await doc.reference.update({
            'isActive': true, // Por defecto, los recordatorios antiguos están activos
          });
          
          migratedCount++;
        }
      }
      
      print('=== MIGRACIÓN COMPLETADA ===');
      print('Documentos migrados: $migratedCount');
      
      return migratedCount;
      
    } catch (e) {
      print('Error en migración: $e');
      return 0;
    }
  }

  // Función de emergencia: obtener TODOS los recordatorios sin filtrar por isActive
  // Usar solo temporalmente hasta que se complete la migración
  Future<List<Reminder>> getAllRemindersEmergency() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return [];
      final collection = _remindersCollection;
      
      print('EMERGENCY: Obteniendo recordatorios SIN filtro isActive');
      
      // Solo filtrar por usuario, no por isActive
      final snapshot = await collection
          .where('userId', isEqualTo: userId)
          .orderBy('dateTime', descending: false)
          .get();
          
      print('EMERGENCY: Documentos encontrados: ${snapshot.docs.length}');
      
      final reminders = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        // Asignar isActive = true por defecto si no existe
        if (!data.containsKey('isActive')) {
          data['isActive'] = true;
        }
        return _convertTimestampToDateTime(data);
      }).toList();
      
      print('EMERGENCY: Recordatorios procesados: ${reminders.length}');
      return reminders;
    } catch (e) {
      print('EMERGENCY ERROR: $e');
      return [];
    }
  }
}
