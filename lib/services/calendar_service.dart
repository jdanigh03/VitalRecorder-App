import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CalendarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _completionsCollection {
    return _firestore.collection('reminder_completions');
  }

  String? get _currentUserId {
    return _auth.currentUser?.uid;
  }

  /// Marca un recordatorio como completado para una fecha específica
  Future<bool> markReminderCompleted(String reminderId, DateTime date) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return false;

      final dateKey = _getDateKey(date);
      final completionId = '${userId}_${reminderId}_$dateKey';

      await _completionsCollection.doc(completionId).set({
        'userId': userId,
        'reminderId': reminderId,
        'date': Timestamp.fromDate(_getStartOfDay(date)),
        'completedAt': FieldValue.serverTimestamp(),
        'dateKey': dateKey,
      });

      print('Recordatorio marcado como completado: $reminderId para fecha $dateKey');
      return true;
    } catch (e) {
      print('Error marcando recordatorio como completado: $e');
      return false;
    }
  }

  /// Desmarca un recordatorio como completado para una fecha específica
  Future<bool> unmarkReminderCompleted(String reminderId, DateTime date) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return false;

      final dateKey = _getDateKey(date);
      final completionId = '${userId}_${reminderId}_$dateKey';

      await _completionsCollection.doc(completionId).delete();

      print('Recordatorio desmarcado como completado: $reminderId para fecha $dateKey');
      return true;
    } catch (e) {
      print('Error desmarcando recordatorio como completado: $e');
      return false;
    }
  }

  /// Verifica si un recordatorio está completado para una fecha específica
  Future<bool> isReminderCompleted(String reminderId, DateTime date) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return false;

      final dateKey = _getDateKey(date);
      final completionId = '${userId}_${reminderId}_$dateKey';

      final doc = await _completionsCollection.doc(completionId).get();
      return doc.exists;
    } catch (e) {
      print('Error verificando completación de recordatorio: $e');
      return false;
    }
  }

  /// Obtiene todas las completaciones para una fecha específica
  Future<Set<String>> getCompletedReminderIds(DateTime date) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return {};

      final dateKey = _getDateKey(date);
      
      // Consulta más simple usando solo userId y dateKey
      final snapshot = await _completionsCollection
          .where('userId', isEqualTo: userId)
          .where('dateKey', isEqualTo: dateKey)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['reminderId'] as String;
      }).toSet();
    } catch (e) {
      print('Error obteniendo completaciones para fecha: $e');
      return {};
    }
  }

  /// Obtiene estadísticas de completaciones para un rango de fechas
  Future<Map<String, dynamic>> getCompletionStats(DateTime startDate, DateTime endDate) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        return {
          'totalCompletions': 0,
          'completionsByDate': <String, int>{},
          'completionsByReminder': <String, int>{},
        };
      }

      final snapshot = await _completionsCollection
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final completionsByDate = <String, int>{};
      final completionsByReminder = <String, int>{};

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final dateKey = data['dateKey'] as String;
        final reminderId = data['reminderId'] as String;

        completionsByDate[dateKey] = (completionsByDate[dateKey] ?? 0) + 1;
        completionsByReminder[reminderId] = (completionsByReminder[reminderId] ?? 0) + 1;
      }

      return {
        'totalCompletions': snapshot.docs.length,
        'completionsByDate': completionsByDate,
        'completionsByReminder': completionsByReminder,
      };
    } catch (e) {
      print('Error obteniendo estadísticas de completaciones: $e');
      return {
        'totalCompletions': 0,
        'completionsByDate': <String, int>{},
        'completionsByReminder': <String, int>{},
      };
    }
  }

  /// Limpia completaciones antiguas (más de X días)
  Future<int> cleanOldCompletions({int daysToKeep = 90}) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return 0;

      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      
      final snapshot = await _completionsCollection
          .where('userId', isEqualTo: userId)
          .where('date', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      int deletedCount = 0;
      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
        deletedCount++;
      }

      if (deletedCount > 0) {
        await batch.commit();
        print('Limpiadas $deletedCount completaciones antiguas');
      }

      return deletedCount;
    } catch (e) {
      print('Error limpiando completaciones antiguas: $e');
      return 0;
    }
  }

  /// Debug: Mostrar todas las completaciones del usuario
  Future<void> debugCompletions() async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        print('DEBUG COMPLETIONS: No hay usuario logueado');
        return;
      }

      print('=== DEBUG COMPLETACIONES ===');
      print('Usuario ID: $userId');

      // Consulta simple sin orderBy para evitar índices
      final snapshot = await _completionsCollection
          .where('userId', isEqualTo: userId)
          .get();

      print('Total completaciones encontradas: ${snapshot.docs.length}');

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        print('---');
        print('ID: ${doc.id}');
        print('Recordatorio ID: ${data['reminderId']}');
        print('Fecha: ${data['dateKey']}');
        print('Completado el: ${data['completedAt']}');
      }
      print('=== FIN DEBUG COMPLETACIONES ===');
    } catch (e) {
      print('Error en debug completaciones: $e');
    }
  }

  /// Helpers privados
  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  DateTime _getStartOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}