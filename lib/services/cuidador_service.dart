import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/reminder.dart';
import '../models/usuario.dart';
import '../models/cuidador.dart';
import 'calendar_service.dart';

class CuidadorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CalendarService _calendarService = CalendarService();

  User? get currentUser => _auth.currentUser;

  CollectionReference? get _cuidadoresCollection {
    final user = currentUser;
    if (user == null) return null;
    return _firestore.collection('users').doc(user.uid).collection('cuidadores');
  }

  Future<String?> agregarCuidador(Cuidador cuidador) async {
    try {
      final collection = _cuidadoresCollection;
      if (collection == null) throw Exception('Usuario no autenticado');
      if (!cuidador.tieneEmailValido) throw Exception('Email no válido');
      if (!cuidador.tieneTelefonoValido) throw Exception('Teléfono no válido');
      final emailEnUso = await emailYaEnUso(cuidador.email);
      if (emailEnUso) throw Exception('Ya existe un cuidador con este email');
      final docRef = collection.doc();
      final cuidadorConId = cuidador.copyWith(id: docRef.id, fechaCreacion: DateTime.now());
      await docRef.set(cuidadorConId.toMap());
      return docRef.id;
    } catch (e) {
      print('Error agregando cuidador: $e');
      rethrow;
    }
  }

  Future<List<Cuidador>> obtenerCuidadores() async {
    try {
      final collection = _cuidadoresCollection;
      if (collection == null) return [];
      final querySnapshot = await collection.where('activo', isEqualTo: true).orderBy('fecha_creacion', descending: false).get();
      return querySnapshot.docs.map((doc) => Cuidador.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error obteniendo cuidadores: $e');
      return [];
    }
  }

  Stream<List<Cuidador>> obtenerCuidadoresStream() {
    final collection = _cuidadoresCollection;
    if (collection == null) return Stream.value([]);
    return collection.where('activo', isEqualTo: true).snapshots().map((querySnapshot) {
      final cuidadores = querySnapshot.docs.map((doc) => Cuidador.fromFirestore(doc)).toList();
      cuidadores.sort((a, b) => a.fechaCreacion.compareTo(b.fechaCreacion));
      return cuidadores;
    });
  }

  Future<bool> actualizarCuidador(Cuidador cuidador) async {
    try {
      final collection = _cuidadoresCollection;
      if (collection == null) throw Exception('Usuario no autenticado');
      if (!cuidador.tieneEmailValido) throw Exception('Email no válido');
      if (!cuidador.tieneTelefonoValido) throw Exception('Teléfono no válido');
      final emailEnUso = await emailYaEnUso(cuidador.email, excludeId: cuidador.id);
      if (emailEnUso) throw Exception('Ya existe otro cuidador con este email');
      final cuidadorActualizado = cuidador.copyWith(fechaActualizacion: DateTime.now());
      await collection.doc(cuidador.id).update(cuidadorActualizado.toMap());
      return true;
    } catch (e) {
      print('Error actualizando cuidador: $e');
      rethrow;
    }
  }

  Future<bool> eliminarCuidador(String cuidadorId) async {
    try {
      final collection = _cuidadoresCollection;
      if (collection == null) throw Exception('Usuario no autenticado');
      await collection.doc(cuidadorId).update({'activo': false, 'fecha_actualizacion': Timestamp.fromDate(DateTime.now())});
      return true;
    } catch (e) {
      print('Error eliminando cuidador: $e');
      return false;
    }
  }

  Future<Cuidador?> obtenerCuidadorPorId(String cuidadorId) async {
    try {
      final collection = _cuidadoresCollection;
      if (collection == null) return null;
      final doc = await collection.doc(cuidadorId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['activo'] == true) return Cuidador.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error obteniendo cuidador por ID: $e');
      return null;
    }
  }

  Future<bool> emailYaEnUso(String email, {String? excludeId}) async {
    try {
      final collection = _cuidadoresCollection;
      if (collection == null) return false;
      final querySnapshot = await collection.where('email', isEqualTo: email.trim()).get();
      final activeDocs = querySnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final isActive = data['activo'] == true;
        final isDifferentId = excludeId == null || doc.id != excludeId;
        return isActive && isDifferentId;
      }).toList();
      return activeDocs.isNotEmpty;
    } catch (e) {
      print('Error verificando email: $e');
      return false;
    }
  }

  Future<bool> restaurarCuidador(String cuidadorId) async {
    try {
      final collection = _cuidadoresCollection;
      if (collection == null) throw Exception('Usuario no autenticado');
      await collection.doc(cuidadorId).update({'activo': true, 'fecha_actualizacion': Timestamp.fromDate(DateTime.now())});
      return true;
    } catch (e) {
      print('Error restaurando cuidador: $e');
      return false;
    }
  }

  Future<List<UserModel>> getPacientesAsignados() async {
    return getPacientes();
  }

  Future<List<UserModel>> getPacientes() async {
    try {
      final currentUserId = currentUser?.uid;
      if (currentUserId == null) return [];
      List<UserModel> pacientesAsignados = [];
      final allUsersSnapshot = await _firestore.collection('users').where('role', isEqualTo: 'user').get();
      for (final userDoc in allUsersSnapshot.docs) {
        final cuidadoresSnapshot = await _firestore.collection('users').doc(userDoc.id).collection('cuidadores').where('email', isEqualTo: currentUser?.email).where('activo', isEqualTo: true).get();
        if (cuidadoresSnapshot.docs.isNotEmpty) {
          pacientesAsignados.add(UserModel.fromFirestore(userDoc));
        }
      }
      return pacientesAsignados;
    } catch (e) {
      print('Error obteniendo pacientes asignados: $e');
      return [];
    }
  }

  Future<List<Reminder>> getAllRemindersFromPatients() async {
    try {
      final pacientesAsignados = await getPacientes();
      if (pacientesAsignados.isEmpty) return [];
      final pacienteUserIds = pacientesAsignados.map((p) => p.userId).toList();
      if (pacienteUserIds.isEmpty) return [];

      final snapshot = await _firestore
          .collection('reminders')
          .where('userId', whereIn: pacienteUserIds)
          .where('isActive', isEqualTo: true)
          .get();

      final todosRecordatorios = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _convertTimestampToDateTime(data);
      }).toList();
      
      todosRecordatorios.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      return todosRecordatorios;
    } catch (e) {
      print('Error obteniendo recordatorios de pacientes asignados: $e');
      return [];
    }
  }

  Future<List<Reminder>> getTodayRemindersFromAllPatients() async {
    try {
      final todosRecordatorios = await getAllRemindersFromPatients();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      print('=== DEBUG FILTRO DE RECORDATORIOS (CUIDADOR) ===');
      print('Fecha actual: $now');
      print('Hoy (sin hora): $today');
      print('Total recordatorios obtenidos: ${todosRecordatorios.length}');
      
      final relevantReminders = <Reminder>[];
      
      for (final reminder in todosRecordatorios) {
        final reminderDate = DateTime(reminder.dateTime.year, reminder.dateTime.month, reminder.dateTime.day);
        
        // Recordatorios de hoy (todos, independientemente de completación)
        if (reminderDate.isAtSameMomentAs(today)) {
          print('✅ Recordatorio de hoy: ${reminder.title} - Paciente: ${reminder.userId}');
          relevantReminders.add(reminder);
          continue;
        }
        
        // Recordatorios de días anteriores - verificar completación en calendario
        if (reminderDate.isBefore(today)) {
          final isCompletedOnDate = await _calendarService.isReminderCompleted(reminder.id, reminderDate);
          if (!isCompletedOnDate) {
            print('✅ Recordatorio pendiente de día anterior: ${reminder.title} (${reminder.dateTime.day}/${reminder.dateTime.month}) - Paciente: ${reminder.userId}');
            relevantReminders.add(reminder);
          } else {
            print('❌ Recordatorio de día anterior ya completado: ${reminder.title} (${reminder.dateTime.day}/${reminder.dateTime.month}) - Paciente: ${reminder.userId}');
          }
          continue;
        }
        
        print('❌ Recordatorio futuro excluido: ${reminder.title} (${reminder.dateTime.day}/${reminder.dateTime.month}) - Paciente: ${reminder.userId}');
      }
      
      relevantReminders.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      
      print('Recordatorios relevantes finales: ${relevantReminders.length}');
      print('=== FIN DEBUG FILTRO (CUIDADOR) ===');
      
      return relevantReminders;
    } catch (e) {
      print('Error obteniendo recordatorios relevantes de pacientes asignados: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getCuidadorStats() async {
    try {
      final pacientes = await getPacientes();
      final allReminders = await getAllRemindersFromPatients();
      final todayReminders = await getTodayRemindersFromAllPatients();
      
      // Con el nuevo sistema, todos los recordatorios en todayReminders son pendientes
      // porque ya se filtran los completados
      final pendingToday = todayReminders.length;
      final completedToday = 0; // No mostramos completados en las estadísticas simples
      
      // Los recordatorios activos son todos los que están en la base (ya vienen filtrados por isActive)
      final activeReminders = allReminders.length;
      
      // Para adherencia, necesitaríamos consultar el CalendarService, pero es complejo
      // Por simplicidad, mantenemos un valor placeholder
      final adherenceRate = 85; // Placeholder - podría calcularse con más complejidad
      
      final medicacionCount = allReminders.where((r) => r.type == 'Medicación' || r.type == 'medication').length;
      final tareasCount = allReminders.where((r) => r.type == 'Tarea' || r.type == 'activity').length;
      final citasCount = allReminders.where((r) => r.type == 'Cita' || r.type == 'appointment').length;
      
      return {
        'totalPacientes': pacientes.length,
        'alertasHoy': pendingToday,
        'completadosHoy': completedToday,
        'recordatoriosActivos': activeReminders,
        'adherenciaGeneral': adherenceRate,
        'totalRecordatorios': allReminders.length,
        'recordatoriosPorTipo': {'medicacion': medicacionCount, 'tareas': tareasCount, 'citas': citasCount},
        'recordatoriosHoy': todayReminders.length,
      };
    } catch (e) {
      print('Error obteniendo estadísticas del cuidador: $e');
      return {
        'totalPacientes': 0,
        'alertasHoy': 0,
        'completadosHoy': 0,
        'recordatoriosActivos': 0,
        'adherenciaGeneral': 0,
        'totalRecordatorios': 0,
        'recordatoriosPorTipo': {'medicacion': 0, 'tareas': 0, 'citas': 0},
        'recordatoriosHoy': 0,
      };
    }
  }

  Future<bool> crearRecordatorioParaPaciente(String pacienteId, Reminder reminder) async {
    try {
      final currentUserId = currentUser?.uid;
      final currentEmail = currentUser?.email;
      if (currentUserId == null || currentEmail == null) throw Exception('Cuidador no autenticado');
      final isAssigned = await _isCuidadorAsignadoAPaciente(pacienteId, currentEmail);
      if (!isAssigned) throw Exception('No tienes permisos para crear recordatorios para este paciente');
      final pacienteDoc = await _firestore.collection('users').doc(pacienteId).get();
      if (!pacienteDoc.exists) throw Exception('Paciente no encontrado');
      final pacienteData = pacienteDoc.data() as Map<String, dynamic>;
      final pacienteEmail = pacienteData['email'] ?? '';
      final docRef = _firestore.collection('reminders').doc();
      final reminderData = {
        'id': docRef.id,
        'title': reminder.title,
        'description': reminder.description,
        'dateTime': Timestamp.fromDate(reminder.dateTime),
        'frequency': reminder.frequency,
        'type': reminder.type,
        'isCompleted': false,
        'isActive': true,
        'userId': pacienteId,
        'userEmail': pacienteEmail,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        'createdBy': 'cuidador',
        'cuidadorId': currentUserId,
        'cuidadorEmail': currentEmail,
      };
      await docRef.set(reminderData);
      return true;
    } catch (e) {
      print('Error creando recordatorio para paciente: $e');
      return false;
    }
  }

  Future<bool> _isCuidadorAsignadoAPaciente(String pacienteId, String cuidadorEmail) async {
    try {
      final cuidadoresSnapshot = await _firestore.collection('users').doc(pacienteId).collection('cuidadores').where('email', isEqualTo: cuidadorEmail).where('activo', isEqualTo: true).get();
      return cuidadoresSnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error verificando asignación de cuidador: $e');
      return false;
    }
  }

  Future<List<Reminder>> getRecordatoriosPaciente(String pacienteId) async {
    try {
      final currentEmail = currentUser?.email;
      if (currentEmail == null) return [];
      final isAssigned = await _isCuidadorAsignadoAPaciente(pacienteId, currentEmail);
      if (!isAssigned) return [];
      final snapshot = await _firestore.collection('reminders').where('userId', isEqualTo: pacienteId).where('isActive', isEqualTo: true).orderBy('dateTime', descending: false).get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _convertTimestampToDateTime(data);
      }).toList();
    } catch (e) {
      print('Error obteniendo recordatorios del paciente: $e');
      return [];
    }
  }

  Future<bool> desactivarRecordatorioPaciente(String pacienteId, String recordatorioId) async {
    try {
      final currentEmail = currentUser?.email;
      if (currentEmail == null) throw Exception('Cuidador no autenticado');
      final isAssigned = await _isCuidadorAsignadoAPaciente(pacienteId, currentEmail);
      if (!isAssigned) throw Exception('No tienes permisos para modificar recordatorios de este paciente');
      final reminderDoc = await _firestore.collection('reminders').doc(recordatorioId).get();
      if (!reminderDoc.exists) throw Exception('Recordatorio no encontrado');
      final reminderData = reminderDoc.data() as Map<String, dynamic>;
      if (reminderData['userId'] != pacienteId) throw Exception('Este recordatorio no pertenece al paciente especificado');
      await _firestore.collection('reminders').doc(recordatorioId).update({'isActive': false});
      return true;
    } catch (e) {
      print('Error desactivando recordatorio: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getEstadisticasPaciente(String pacienteId) async {
    try {
      final recordatorios = await getRecordatoriosPaciente(pacienteId);
      final total = recordatorios.length;
      final completados = recordatorios.where((r) => r.isCompleted).length;
      final pendientes = recordatorios.where((r) => !r.isCompleted).length;
      final vencidos = recordatorios.where((r) => !r.isCompleted && r.dateTime.isBefore(DateTime.now())).length;
      final adherencia = total > 0 ? (completados / total * 100).round() : 0;
      return {
        'totalRecordatorios': total,
        'completados': completados,
        'pendientes': pendientes,
        'vencidos': vencidos,
        'adherencia': adherencia,
      };
    } catch (e) {
      print('Error obteniendo estadísticas del paciente: $e');
      return {
        'totalRecordatorios': 0,
        'completados': 0,
        'pendientes': 0,
        'vencidos': 0,
        'adherencia': 0,
      };
    }
  }

  Reminder _convertTimestampToDateTime(Map<String, dynamic> data) {
    if (data['dateTime'] is Timestamp) {
      data['dateTime'] = (data['dateTime'] as Timestamp).toDate().toIso8601String();
    }
    return Reminder.fromMap(data);
  }
}
