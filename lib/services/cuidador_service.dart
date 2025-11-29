import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/reminder_new.dart';
import '../models/user.dart';
import '../models/cuidador.dart';
import '../reminder_service_new.dart';
import 'bracelet_service.dart';

class CuidadorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ReminderServiceNew _reminderService = ReminderServiceNew();
  final BraceletService _braceletService = BraceletService();

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

  Future<List<ReminderNew>> getAllRemindersFromPatients() async {
    try {
      final pacientesAsignados = await getPacientes();
      if (pacientesAsignados.isEmpty) return [];
      
      List<ReminderNew> allReminders = [];
      
      for (final paciente in pacientesAsignados) {
        final reminders = await _reminderService.getRemindersByPatient(paciente.userId!);
        allReminders.addAll(reminders);
      }
      
      allReminders.sort((a, b) => b.startDate.compareTo(a.startDate));
      return allReminders;
    } catch (e) {
      print('Error obteniendo recordatorios de pacientes asignados: $e');
      return [];
    }
  }

  Future<List<ReminderNew>> getTodayRemindersFromAllPatients() async {
    try {
      final allReminders = await getAllRemindersFromPatients();
      final today = DateTime.now();
      
      print('=== DEBUG FILTRO DE RECORDATORIOS (CUIDADOR) ===');
      print('Fecha actual: $today');
      print('Total recordatorios obtenidos: ${allReminders.length}');
      
      final todayReminders = allReminders.where((r) => r.hasOccurrencesOnDay(today)).toList();
      
      print('Recordatorios con ocurrencias hoy: ${todayReminders.length}');
      print('=== FIN DEBUG FILTRO (CUIDADOR) ===');
      
      return todayReminders;
    } catch (e) {
      print('Error obteniendo recordatorios de hoy de pacientes: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getCuidadorStats() async {
    try {
      final pacientes = await getPacientes();
      final allReminders = await getAllRemindersFromPatients();
      final todayReminders = await getTodayRemindersFromAllPatients();
      
      // Calcular confirmaciones pendientes para hoy
      int pendingToday = 0;
      int completedToday = 0;
      
      for (final reminder in todayReminders) {
        // Excluir recordatorios pausados de las estadísticas de hoy
        if (reminder.isPaused) continue;
        final occurrences = reminder.calculateOccurrencesForDay(DateTime.now());
        for (final occurrence in occurrences) {
          final confirmations = await _reminderService.getConfirmations(reminder.id);
          final hasConfirmation = confirmations.any((c) => 
            c.scheduledTime.year == occurrence.year &&
            c.scheduledTime.month == occurrence.month &&
            c.scheduledTime.day == occurrence.day &&
            c.scheduledTime.hour == occurrence.hour &&
            c.scheduledTime.minute == occurrence.minute
          );
          
          if (hasConfirmation) {
            completedToday++;
          } else {
            pendingToday++;
          }
        }
      }
      
      // Contar solo recordatorios activos (no pausados)
      final activeReminders = allReminders.where((r) => !r.isPaused).length;
      
      // Calcular adherencia promedio (excluyendo pausados)
      double totalAdherence = 0;
      int remindersWithStats = 0;
      for (final reminder in allReminders) {
        // Excluir recordatorios pausados del cálculo de adherencia
        if (reminder.isPaused) continue;
        final stats = await _reminderService.getReminderStats(reminder.id);
        if (stats['total'] > 0) {
          totalAdherence += stats['adherenceRate'];
          remindersWithStats++;
        }
      }
      final adherenceRate = remindersWithStats > 0 ? (totalAdherence / remindersWithStats).round() : 0;
      
      // Contar por tipo, excluyendo pausados
      final activeRemindersOnly = allReminders.where((r) => !r.isPaused).toList();
      final medicacionCount = activeRemindersOnly.where((r) => r.type == 'Medicación' || r.type == 'medication').length;
      final tareasCount = activeRemindersOnly.where((r) => r.type == 'Tarea' || r.type == 'activity').length;
      final citasCount = activeRemindersOnly.where((r) => r.type == 'Cita' || r.type == 'appointment').length;
      
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

  Future<bool> crearRecordatorioParaPaciente(String pacienteId, ReminderNew reminder) async {
    try {
      final currentUserId = currentUser?.uid;
      final currentEmail = currentUser?.email;
      if (currentUserId == null || currentEmail == null) throw Exception('Cuidador no autenticado');
      final isAssigned = await _isCuidadorAsignadoAPaciente(pacienteId, currentEmail);
      if (!isAssigned) throw Exception('No tienes permisos para crear recordatorios para este usuario');
      final pacienteDoc = await _firestore.collection('users').doc(pacienteId).get();
      if (!pacienteDoc.exists) throw Exception('Usuario no encontrado');
      final pacienteData = pacienteDoc.data() as Map<String, dynamic>;
      final pacienteEmail = pacienteData['email'] ?? '';
      // Crear recordatorio con nuevo sistema
      final reminderWithId = reminder.copyWith(
        id: _firestore.collection('reminders_new').doc().id,
        userId: pacienteId,
      );
      
      final success = await _reminderService.createReminderWithConfirmations(reminderWithId);
      
      if (success) {
        print('Recordatorio creado por cuidador para usuario $pacienteId');
        print('El recordatorio se sincronizará automáticamente cuando el usuario abra su app');
      }
      
      return success;
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

  Future<List<ReminderNew>> getRecordatoriosPaciente(String pacienteId) async {
    try {
      final currentEmail = currentUser?.email;
      if (currentEmail == null) return [];
      final isAssigned = await _isCuidadorAsignadoAPaciente(pacienteId, currentEmail);
      if (!isAssigned) return [];
      
      return await _reminderService.getRemindersByPatient(pacienteId);
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
      if (!isAssigned) throw Exception('No tienes permisos para modificar recordatorios de este usuario');
      
      await _reminderService.deactivateReminder(recordatorioId);
      return true;
    } catch (e) {
      print('Error desactivando recordatorio: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getEstadisticasPaciente(String pacienteId) async {
    try {
      final recordatorios = await getRecordatoriosPaciente(pacienteId);
      
      int totalConfirmations = 0;
      int completedConfirmations = 0;
      double totalAdherence = 0;
      
      for (final reminder in recordatorios) {
        if (reminder.isPaused) continue;
        final stats = await _reminderService.getReminderStats(reminder.id);
        totalConfirmations += stats['total'] as int;
        completedConfirmations += stats['confirmed'] as int;
        if (stats['total'] > 0) {
          // adherenceRate viene como String, convertir a double
          final adherenceRate = double.tryParse(stats['adherenceRate'] as String) ?? 0.0;
          totalAdherence += adherenceRate;
        }
      }
      
      final adherencia = recordatorios.isNotEmpty ? (totalAdherence / recordatorios.length).round() : 0;
      final pendientes = totalConfirmations - completedConfirmations;
      
      return {
        'totalRecordatorios': recordatorios.length,
        'completados': completedConfirmations,
        'pendientes': pendientes,
        'vencidos': 0, // Calculado a través de confirmaciones missed
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
}
