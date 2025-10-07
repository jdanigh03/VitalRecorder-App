import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/reminder.dart';

class ReminderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Referencia a la colección global de recordatorios
  CollectionReference get _remindersCollection {
    return _firestore.collection('reminders');
  }

  // Obtener el ID del usuario actual
  String? get _currentUserId {
    return _auth.currentUser?.uid;
  }

  // Crear un nuevo recordatorio
  Future<bool> createReminder(Reminder reminder) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return false;

      final collection = _remindersCollection;
      
      // Generar ID único si no lo tiene
      final docId = reminder.id.isEmpty ? collection.doc().id : reminder.id;
      final newReminder = reminder.copyWith(id: docId);

      // Agregar el userId al mapa de datos
      final dataMap = newReminder.toMap();
      dataMap['userId'] = userId;
      
      // Convertir DateTime a Timestamp para Firestore
      dataMap['dateTime'] = Timestamp.fromDate(newReminder.dateTime);
      
      // Agregar createdAt con la fecha del servidor (como en la rama original)
      dataMap['createdAt'] = FieldValue.serverTimestamp();

      await collection.doc(docId).set(dataMap);
      return true;
    } catch (e) {
      print('Error creando recordatorio: $e');
      return false;
    }
  }

  // Actualizar un recordatorio existente
  Future<bool> updateReminder(Reminder reminder) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return false;
      
      final collection = _remindersCollection;
      
      // Agregar el userId al mapa de datos
      final dataMap = reminder.toMap();
      dataMap['userId'] = userId;
      
      // Convertir DateTime a Timestamp para Firestore
      dataMap['dateTime'] = Timestamp.fromDate(reminder.dateTime);

      await collection.doc(reminder.id).update(dataMap);
      return true;
    } catch (e) {
      print('Error actualizando recordatorio: $e');
      return false;
    }
  }

  // Eliminar un recordatorio
  Future<bool> deleteReminder(String reminderId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return false;
      
      final collection = _remindersCollection;

      await collection.doc(reminderId).delete();
      return true;
    } catch (e) {
      print('Error eliminando recordatorio: $e');
      return false;
    }
  }

  // Obtener todos los recordatorios del usuario
  Future<List<Reminder>> getAllReminders() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return [];
      
      final collection = _remindersCollection;

      final snapshot = await collection
          .where('userId', isEqualTo: userId)
          .get();
          
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _convertTimestampToDateTime(data);
      }).toList();
    } catch (e) {
      print('Error obteniendo recordatorios: $e');
      return [];
    }
  }

  // Stream para escuchar cambios en tiempo real
  Stream<List<Reminder>> getRemindersStream() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);
    
    final collection = _remindersCollection;

    return collection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _convertTimestampToDateTime(data);
      }).toList();
    });
  }

  // Método auxiliar para convertir Timestamp a DateTime
  Reminder _convertTimestampToDateTime(Map<String, dynamic> data) {
    // Convertir Timestamp a DateTime si es necesario
    if (data['dateTime'] is Timestamp) {
      data['dateTime'] = (data['dateTime'] as Timestamp).toDate().toIso8601String();
    }
    return Reminder.fromMap(data);
  }

  // Obtener recordatorios por tipo
  Future<List<Reminder>> getRemindersByType(String type) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return [];
      
      final collection = _remindersCollection;

      final snapshot = await collection
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: type)
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

  // Obtener recordatorios por fecha
  Future<List<Reminder>> getRemindersByDate(DateTime date) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return [];
      
      final collection = _remindersCollection;

      // Inicio y fin del día
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final snapshot = await collection
          .where('userId', isEqualTo: userId)
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

  // Obtener recordatorios para un rango de fechas
  Future<List<Reminder>> getRemindersForDateRange(DateTime startDate, DateTime endDate) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return [];
      
      final collection = _remindersCollection;

      final snapshot = await collection
          .where('userId', isEqualTo: userId)
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

  // Marcar recordatorio como completado
  Future<bool> markAsCompleted(String reminderId, bool isCompleted) async {
    try {
      final collection = _remindersCollection;

      await collection.doc(reminderId).update({
        'isCompleted': isCompleted,
      });
      return true;
    } catch (e) {
      print('Error marcando recordatorio como completado: $e');
      return false;
    }
  }

  // Obtener estadísticas de recordatorios
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
}
