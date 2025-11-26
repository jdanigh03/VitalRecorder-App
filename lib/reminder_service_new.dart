import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/reminder_new.dart';
import 'models/reminder_confirmation.dart';
import 'services/bracelet_service.dart';
import 'services/notification_service.dart';
import 'services/user_service.dart';

class ReminderServiceNew {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();
  final UserService _userService = UserService();

  // Colecciones
  CollectionReference get _remindersCollection =>
      _firestore.collection('reminders_new');
  
  CollectionReference get _confirmationsCollection =>
      _firestore.collection('reminder_confirmations');

  String? get _currentUserId => _auth.currentUser?.uid;

  // ========================================
  // CRUD DE RECORDATORIOS
  // ========================================

  /// Crea un recordatorio Y genera todas las confirmaciones automáticamente
  Future<bool> createReminderWithConfirmations(ReminderNew reminder) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return false;

      // Generar ID si no existe
      final docId = reminder.id.isEmpty 
          ? _remindersCollection.doc().id 
          : reminder.id;

      // Crear recordatorio con metadatos
      final newReminder = reminder.copyWith(
        id: docId,
        userId: userId,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Convertir a Map para Firestore
      final reminderData = newReminder.toMap();
      reminderData['userId'] = userId;
      reminderData['startDate'] = Timestamp.fromDate(newReminder.startDate);
      reminderData['endDate'] = Timestamp.fromDate(newReminder.endDate);
      reminderData['createdAt'] = FieldValue.serverTimestamp();
      reminderData['updatedAt'] = FieldValue.serverTimestamp();

      // Guardar recordatorio
      await _remindersCollection.doc(docId).set(reminderData);

      // Generar confirmaciones para todas las ocurrencias
      int generatedCount = await _generateConfirmations(newReminder);

      print('✅ Recordatorio creado: $docId con $generatedCount confirmaciones');
      
      // Sincronizar automáticamente con la manilla si está conectada
      _syncWithBraceletSafely();
      
      // Notificar a los cuidadores sobre el nuevo recordatorio
      await _notificarEvento(newReminder, accion: 'created');
      
      return true;
    } catch (e) {
      print('❌ Error creando recordatorio: $e');
      return false;
    }
  }

  /// Genera todas las confirmaciones para un recordatorio
  Future<int> _generateConfirmations(ReminderNew reminder) async {
    try {
      final allOccurrences = reminder.calculateAllScheduledTimes();
      
      final now = DateTime.now();
      // Margen de tolerancia de 15 minutos para permitir marcar algo que acaba de pasar
      final tolerance = now.subtract(Duration(minutes: 15));

      // Filtrar ocurrencias válidas antes de procesar
      final validOccurrences = allOccurrences.where((t) => !t.isBefore(tolerance)).toList();

      print('Generando ${validOccurrences.length} confirmaciones...');

      // Batch write para mejor performance
      WriteBatch batch = _firestore.batch();
      int batchCount = 0;
      int totalGenerated = 0;

      for (final scheduledTime in validOccurrences) {
        final confirmationId = _confirmationsCollection.doc().id;
        
        final confirmation = ReminderConfirmation(
          id: confirmationId,
          reminderId: reminder.id,
          userId: reminder.userId ?? '',
          scheduledTime: scheduledTime,
          status: ConfirmationStatus.PENDING,
          createdAt: DateTime.now(),
        );

        final confirmationData = confirmation.toMap();
        confirmationData['scheduledTime'] = Timestamp.fromDate(scheduledTime);
        confirmationData['createdAt'] = FieldValue.serverTimestamp();

        batch.set(
          _confirmationsCollection.doc(confirmationId),
          confirmationData,
        );

        batchCount++;
        totalGenerated++;

        // Firestore tiene límite de 500 operaciones por batch
        if (batchCount >= 500) {
          await batch.commit();
          batch = _firestore.batch();
          batchCount = 0;
        }
      }

      // Commit final
      if (batchCount > 0) {
        await batch.commit();
      }

      print('✅ Confirmaciones generadas exitosamente');
      return totalGenerated;
    } catch (e) {
      print('❌ Error generando confirmaciones: $e');
      rethrow;
    }
  }

  /// Actualiza un recordatorio existente
  Future<bool> updateReminder(ReminderNew reminder) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return false;

      // Leer recordatorio actual para comparar
      final currentDoc = await _remindersCollection.doc(reminder.id).get();
      if (!currentDoc.exists) return false;

      final currentReminder = _convertToReminderNew(
        currentDoc.data() as Map<String, dynamic>,
      );

      // Verificar si cambiaron fechas u horarios (requiere regenerar confirmaciones)
      final needsRegenerateConfirmations = 
          currentReminder.startDate != reminder.startDate ||
          currentReminder.endDate != reminder.endDate ||
          currentReminder.intervalType != reminder.intervalType ||
          currentReminder.intervalValue != reminder.intervalValue ||
          _dailyTimesChanged(currentReminder, reminder);

      // Actualizar recordatorio
      final updatedReminder = reminder.copyWith(
        userId: userId,
        updatedAt: DateTime.now(),
        skipDateValidation: true, // Permitir fechas pasadas al actualizar
      );

      final reminderData = updatedReminder.toMap();
      reminderData['userId'] = userId;
      reminderData['startDate'] = Timestamp.fromDate(updatedReminder.startDate);
      reminderData['endDate'] = Timestamp.fromDate(updatedReminder.endDate);
      reminderData['updatedAt'] = FieldValue.serverTimestamp();

      await _remindersCollection.doc(reminder.id).update(reminderData);

      // Si cambió el schedule, eliminar confirmaciones viejas y generar nuevas
      if (needsRegenerateConfirmations) {
        print('⚠️ Regenerando confirmaciones...');
        await _deleteConfirmations(reminder.id);
        await _generateConfirmations(updatedReminder);
      }

      print('✅ Recordatorio actualizado: ${reminder.id}');
      
      // Sincronizar automáticamente con la manilla si está conectada
      _syncWithBraceletSafely();
      
      // Notificar a los cuidadores sobre la edición
      await _notificarEvento(updatedReminder, accion: 'updated');
      
      return true;
    } catch (e) {
      print('❌ Error actualizando recordatorio: $e');
      return false;
    }
  }

  bool _dailyTimesChanged(ReminderNew old, ReminderNew updated) {
    if (old.dailyScheduleTimes.length != updated.dailyScheduleTimes.length) {
      return true;
    }
    for (int i = 0; i < old.dailyScheduleTimes.length; i++) {
      if (old.dailyScheduleTimes[i] != updated.dailyScheduleTimes[i]) {
        return true;
      }
    }
    return false;
  }

  /// Notifica a los cuidadores sobre eventos del recordatorio
  Future<void> _notificarEvento(ReminderNew reminder, {
    required String accion,
    String? detalle
  }) async {
    try {
      print('🔔 Iniciando notificación de evento "$accion" para recordatorio "${reminder.title}"');
      // Obtener nombre del paciente
      final userData = await _userService.getUserData(reminder.userId ?? '');
      final pacienteNombre = userData?.persona.nombres ?? 'Un paciente';
      print('👤 Paciente identificado: $pacienteNombre (${reminder.userId})');

      // Enviar notificación
      await _notificationService.notificarEventoRecordatorio(
        pacienteId: reminder.userId ?? '',
        pacienteNombre: pacienteNombre,
        recordatorioTitulo: reminder.title,
        accion: accion,
        detalle: detalle,
      );
      print('✅ Notificación enviada al servicio');
    } catch (e) {
      print('⚠️ Error al notificar cuidadores: $e');
      // No lanzar error para no afectar la creación/edición del recordatorio
    }
  }

  /// Helper para notificar cuando solo tenemos el ID
  Future<void> _notificarEventoPorId(String reminderId, String accion, {String? detalle}) async {
    try {
      final reminder = await getReminderById(reminderId);
      if (reminder != null) {
        await _notificarEvento(reminder, accion: accion, detalle: detalle);
      }
    } catch (e) {
      print('⚠️ Error al notificar por ID: $e');
    }
  }

  /// Pausa un recordatorio
  Future<bool> pauseReminder(String reminderId) async {
    try {
      final now = DateTime.now();
      
      // Actualizar el recordatorio
      await _remindersCollection.doc(reminderId).update({
        'isPaused': true,
        'pausedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Marcar todas las confirmaciones pendientes futuras como PAUSED
      final confirmations = await _confirmationsCollection
          .where('reminderId', isEqualTo: reminderId)
          .where('status', isEqualTo: 'PENDING')
          .get();

      WriteBatch batch = _firestore.batch();
      int count = 0;

      for (final doc in confirmations.docs) {
        final confirmation = ReminderConfirmation.fromMap(doc.data() as Map<String, dynamic>);
        
        // Solo pausar confirmaciones futuras o muy recientes (menos de 15 minutos atrás)
        if (confirmation.scheduledTime.isAfter(now.subtract(Duration(minutes: 15)))) {
          batch.update(doc.reference, {'status': 'PAUSED'});
          count++;
          
          if (count >= 500) {
            await batch.commit();
            batch = _firestore.batch();
            count = 0;
          }
        }
      }

      if (count > 0) {
        await batch.commit();
      }

      print('✅ Recordatorio pausado: $reminderId ($count confirmaciones marcadas como pausadas)');
      
      // Sincronizar automáticamente con la manilla si está conectada
      _syncWithBraceletSafely();

      // Notificar evento
      await _notificarEventoPorId(reminderId, 'paused');
      
      return true;
    } catch (e) {
      print('❌ Error pausando recordatorio: $e');
      return false;
    }
  }

  /// Reanuda un recordatorio pausado
  Future<bool> resumeReminder(String reminderId) async {
    try {
      final now = DateTime.now();
      
      // Actualizar el recordatorio
      await _remindersCollection.doc(reminderId).update({
        'isPaused': false,
        'resumedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Cambiar confirmaciones PAUSED futuras de vuelta a PENDING
      final confirmations = await _confirmationsCollection
          .where('reminderId', isEqualTo: reminderId)
          .where('status', isEqualTo: 'PAUSED')
          .get();

      WriteBatch batch = _firestore.batch();
      int count = 0;

      for (final doc in confirmations.docs) {
        final confirmation = ReminderConfirmation.fromMap(doc.data() as Map<String, dynamic>);
        
        // Solo reactivar confirmaciones futuras
        if (confirmation.scheduledTime.isAfter(now)) {
          batch.update(doc.reference, {'status': 'PENDING'});
          count++;
          
          if (count >= 500) {
            await batch.commit();
            batch = _firestore.batch();
            count = 0;
          }
        }
        // Las confirmaciones pausadas del pasado se quedan como PAUSED (no cuentan)
      }

      if (count > 0) {
        await batch.commit();
      }

      print('✅ Recordatorio reanudado: $reminderId ($count confirmaciones reactivadas)');
      
      // Sincronizar automáticamente con la manilla si está conectada
      _syncWithBraceletSafely();

      // Notificar evento
      await _notificarEventoPorId(reminderId, 'resumed');
      
      return true;
    } catch (e) {
      print('❌ Error reanudando recordatorio: $e');
      return false;
    }
  }

  /// Desactiva un recordatorio (borrado lógico)
  Future<bool> deactivateReminder(String reminderId) async {
    try {
      await _remindersCollection.doc(reminderId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Recordatorio desactivado: $reminderId');
      
      // Sincronizar automáticamente con la manilla si está conectada
      _syncWithBraceletSafely();

      // Notificar evento
      await _notificarEventoPorId(reminderId, 'archived');
      
      return true;
    } catch (e) {
      print('❌ Error desactivando recordatorio: $e');
      return false;
    }
  }

  /// Elimina permanentemente un recordatorio y sus confirmaciones
  Future<bool> deleteReminderPermanently(String reminderId) async {
    try {
      // Eliminar recordatorio
      await _remindersCollection.doc(reminderId).delete();
      
      // Eliminar todas sus confirmaciones
      await _deleteConfirmations(reminderId);

      print('✅ Recordatorio eliminado permanentemente: $reminderId');
      return true;
    } catch (e) {
      print('❌ Error eliminando recordatorio: $e');
      return false;
    }
  }

  /// Elimina todas las confirmaciones de un recordatorio
  Future<void> _deleteConfirmations(String reminderId) async {
    try {
      final confirmations = await _confirmationsCollection
          .where('reminderId', isEqualTo: reminderId)
          .get();

      WriteBatch batch = _firestore.batch();
      int count = 0;

      for (final doc in confirmations.docs) {
        batch.delete(doc.reference);
        count++;

        if (count >= 500) {
          await batch.commit();
          batch = _firestore.batch();
          count = 0;
        }
      }

      if (count > 0) {
        await batch.commit();
      }

      print('✅ Confirmaciones eliminadas para recordatorio: $reminderId');
    } catch (e) {
      print('❌ Error eliminando confirmaciones: $e');
      rethrow;
    }
  }

  // ========================================
  // CONSULTAS DE RECORDATORIOS
  // ========================================

  /// Obtiene un recordatorio por ID
  Future<ReminderNew?> getReminderById(String reminderId) async {
    try {
      final doc = await _remindersCollection.doc(reminderId).get();
      if (!doc.exists) return null;

      return _convertToReminderNew(doc.data() as Map<String, dynamic>);
    } catch (e) {
      print('❌ Error obteniendo recordatorio: $e');
      return null;
    }
  }

  /// Obtiene todos los recordatorios activos del usuario actual
  Future<List<ReminderNew>> getActiveReminders() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return [];

      final snapshot = await _remindersCollection
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => _convertToReminderNew(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo recordatorios activos: $e');
      return [];
    }
  }

  /// Obtiene recordatorios activos de un paciente específico (para cuidador)
  Future<List<ReminderNew>> getRemindersByPatient(String patientId) async {
    try {
      final snapshot = await _remindersCollection
          .where('userId', isEqualTo: patientId)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => _convertToReminderNew(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo recordatorios del paciente: $e');
      return [];
    }
  }

  /// Stream de recordatorios activos en tiempo real
  Stream<List<ReminderNew>> getRemindersStream() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);

    return _remindersCollection
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _convertToReminderNew(doc.data() as Map<String, dynamic>))
            .toList());
  }

  /// Obtiene todos los recordatorios activos del usuario (alias de getActiveReminders para compatibilidad)
  Future<List<ReminderNew>> getAllReminders() async {
    return await getActiveReminders();
  }

  // ========================================
  // CONFIRMACIONES
  // ========================================

  /// Confirma un recordatorio en un horario específico
  Future<bool> confirmReminder({
    required String reminderId,
    required DateTime scheduledTime,
    String? notes,
  }) async {
    try {
      // Buscar la confirmación correspondiente
      final snapshot = await _confirmationsCollection
          .where('reminderId', isEqualTo: reminderId)
          .where('scheduledTime', isEqualTo: Timestamp.fromDate(scheduledTime))
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        print('❌ No se encontró confirmación para: $reminderId @ $scheduledTime');
        return false;
      }

      final confirmationDoc = snapshot.docs.first;
      await confirmationDoc.reference.update({
        'status': 'CONFIRMED',
        'confirmedAt': FieldValue.serverTimestamp(),
        if (notes != null) 'notes': notes,
      });

      print('✅ Recordatorio confirmado: $reminderId @ $scheduledTime');

      // Calcular si fue tarde y notificar
      final now = DateTime.now();
      // scheduledTime viene sin info de zona horaria a veces, asegurar comparación correcta
      final diff = now.difference(scheduledTime);
      
      String accion = 'confirmed';
      String? detalle;
      
      // Si la diferencia es mayor a 30 minutos, considerar tarde
      if (diff.inMinutes > 30) {
        accion = 'confirmed_late';
        final hours = diff.inHours;
        final mins = diff.inMinutes % 60;
        if (hours > 0) {
          detalle = '$hours h $mins min tarde';
        } else {
          detalle = '$mins min tarde';
        }
      }
      
      _notificarEventoPorId(reminderId, accion, detalle: detalle);

      return true;
    } catch (e) {
      print('❌ Error confirmando recordatorio: $e');
      return false;
    }
  }

  /// Marca una confirmación como omitida
  Future<bool> markAsMissed({
    required String reminderId,
    required DateTime scheduledTime,
  }) async {
    try {
      final snapshot = await _confirmationsCollection
          .where('reminderId', isEqualTo: reminderId)
          .where('scheduledTime', isEqualTo: Timestamp.fromDate(scheduledTime))
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return false;

      final confirmationDoc = snapshot.docs.first;
      await confirmationDoc.reference.update({
        'status': 'MISSED',
      });

      print('⚠️ Recordatorio marcado como omitido: $reminderId @ $scheduledTime');
      
      // Notificar evento
      _notificarEventoPorId(reminderId, 'missed');

      return true;
    } catch (e) {
      print('❌ Error marcando como omitido: $e');
      return false;
    }
  }

  /// Obtiene todas las confirmaciones de un recordatorio
  Future<List<ReminderConfirmation>> getConfirmationsByReminder(
    String reminderId,
  ) async {
    try {
      final snapshot = await _confirmationsCollection
          .where('reminderId', isEqualTo: reminderId)
          .orderBy('scheduledTime', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => _convertToConfirmation(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo confirmaciones: $e');
      return [];
    }
  }

  /// Alias para compatibilidad - obtiene confirmaciones de un recordatorio
  Future<List<ReminderConfirmation>> getConfirmations(String reminderId) async {
    return await getConfirmationsByReminder(reminderId);
  }

  /// Obtiene confirmaciones pendientes del usuario para HOY
  Future<List<ReminderConfirmation>> getPendingConfirmationsToday() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return [];

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(Duration(days: 1));

      final snapshot = await _confirmationsCollection
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'PENDING')
          .where('scheduledTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('scheduledTime', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('scheduledTime', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => _convertToConfirmation(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo confirmaciones pendientes: $e');
      return [];
    }
  }

  /// Obtiene estadísticas de adherencia de un recordatorio
  Future<Map<String, dynamic>> getReminderStats(String reminderId) async {
    try {
      final allConfirmations = await getConfirmationsByReminder(reminderId);
      
      // IMPORTANTE: Excluir confirmaciones pausadas de las estadísticas
      final confirmations = allConfirmations.where((c) => 
        c.status != ConfirmationStatus.PAUSED
      ).toList();
      
      final paused = allConfirmations.where((c) => 
        c.status == ConfirmationStatus.PAUSED
      ).length;
      
      final total = confirmations.length;
      final confirmed = confirmations.where((c) => 
        c.status == ConfirmationStatus.CONFIRMED
      ).length;
      final missed = confirmations.where((c) => 
        c.status == ConfirmationStatus.MISSED
      ).length;
      final pending = confirmations.where((c) => 
        c.status == ConfirmationStatus.PENDING
      ).length;

      final adherenceRate = total > 0 ? (confirmed / total * 100).toStringAsFixed(1) : '0.0';

      return {
        'total': total,
        'confirmed': confirmed,
        'missed': missed,
        'pending': pending,
        'paused': paused, // Incluir pausadas para referencia
        'adherenceRate': adherenceRate,
      };
    } catch (e) {
      print('❌ Error obteniendo estadísticas: $e');
      return {
        'total': 0,
        'confirmed': 0,
        'missed': 0,
        'pending': 0,
        'paused': 0,
        'adherenceRate': '0.0',
      };
    }
  }

  // ========================================
  // UTILIDADES
  // ========================================

  /// Convierte Timestamp de Firestore a ReminderNew
  ReminderNew _convertToReminderNew(Map<String, dynamic> data) {
    if (data['startDate'] is Timestamp) {
      data['startDate'] = (data['startDate'] as Timestamp).toDate().toIso8601String();
    }
    if (data['endDate'] is Timestamp) {
      data['endDate'] = (data['endDate'] as Timestamp).toDate().toIso8601String();
    }
    if (data['createdAt'] is Timestamp) {
      data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
    }
    if (data['updatedAt'] is Timestamp) {
      data['updatedAt'] = (data['updatedAt'] as Timestamp).toDate().toIso8601String();
    }
    return ReminderNew.fromMap(data);
  }

  /// Convierte Timestamp de Firestore a ReminderConfirmation
  ReminderConfirmation _convertToConfirmation(Map<String, dynamic> data) {
    if (data['scheduledTime'] is Timestamp) {
      data['scheduledTime'] = (data['scheduledTime'] as Timestamp).toDate().toIso8601String();
    }
    if (data['confirmedAt'] is Timestamp) {
      data['confirmedAt'] = (data['confirmedAt'] as Timestamp).toDate().toIso8601String();
    }
    if (data['createdAt'] is Timestamp) {
      data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
    }
    return ReminderConfirmation.fromMap(data);
  }

  /// Verifica si hay recordatorios pasados que no se confirmaron y los marca como omitidos
  Future<void> checkMissedReminders() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      final now = DateTime.now();
      // Consideramos omitido si pasaron más de 60 minutos
      final threshold = now.subtract(Duration(minutes: 60));

      // Buscar confirmaciones pendientes anteriores al umbral
      final snapshot = await _confirmationsCollection
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'PENDING')
          .where('scheduledTime', isLessThan: Timestamp.fromDate(threshold))
          .get();

      if (snapshot.docs.isEmpty) return;

      print('🔍 Verificando omitidos: ${snapshot.docs.length} candidatos');

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final reminderId = data['reminderId'];
        final scheduledTime = (data['scheduledTime'] as Timestamp).toDate();
        
        // Marcar como omitido (esto disparará la notificación al cuidador)
        await markAsMissed(
          reminderId: reminderId,
          scheduledTime: scheduledTime,
        );
      }
    } catch (e) {
      print('❌ Error verificando recordatorios omitidos: $e');
    }
  }

  /// Sincroniza con la manilla de forma segura (sin bloquear la operación principal)
  void _syncWithBraceletSafely() {
    // Ejecutar en el próximo ciclo del event loop para no bloquear
    Future.delayed(Duration.zero, () async {
      try {
        final braceletService = BraceletService();
        
        // Solo sincronizar si hay una manilla conectada
        if (braceletService.isConnected) {
          print('🔄 Sincronizando recordatorios con la manilla...');
          await braceletService.syncRemindersToBracelet();
          print('✅ Manilla sincronizada automáticamente');
        } else {
          print('ℹ️ Manilla no conectada - sincronización omitida');
        }
      } catch (e) {
        // No propagar el error para no afectar la operación principal
        print('⚠️ Error sincronizando con manilla (no crítico): $e');
      }
    });
  }
}
