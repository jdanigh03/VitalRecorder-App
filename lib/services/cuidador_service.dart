import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/reminder.dart';
import '../models/user.dart';
import '../models/cuidador.dart';

class CuidadorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Obtener el usuario actual
  User? get currentUser => _auth.currentUser;

  // Obtener la colección de cuidadores del usuario actual
  CollectionReference? get _cuidadoresCollection {
    final user = currentUser;
    if (user == null) return null;
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('cuidadores');
  }

  // Agregar un nuevo cuidador
  Future<String?> agregarCuidador(Cuidador cuidador) async {
    try {
      final collection = _cuidadoresCollection;
      if (collection == null) {
        throw Exception('Usuario no autenticado');
      }

      // Validar datos antes de guardar
      if (!cuidador.tieneEmailValido) {
        throw Exception('Email no válido');
      }

      if (!cuidador.tieneTelefonoValido) {
        throw Exception('Teléfono no válido');
      }

      // Verificar que no exista otro cuidador con el mismo email
      // Usar verificación más simple para evitar índices compuestos
      final emailEnUso = await emailYaEnUso(cuidador.email);
      if (emailEnUso) {
        throw Exception('Ya existe un cuidador con este email');
      }

      // Crear cuidador con ID único
      final docRef = collection.doc();
      final cuidadorConId = cuidador.copyWith(
        id: docRef.id,
        fechaCreacion: DateTime.now(),
      );

      await docRef.set(cuidadorConId.toMap());

      print('=== CUIDADOR CREADO EN FIREBASE ===');
      print('ID: ${cuidadorConId.id}');
      print('Nombre: ${cuidadorConId.nombre}');
      print('Email: ${cuidadorConId.email}');
      print('Relación: ${cuidadorConId.relacion}');

      return docRef.id;
    } catch (e) {
      print('Error agregando cuidador: $e');
      rethrow;
    }
  }

  // Obtener todos los cuidadores del usuario actual
  Future<List<Cuidador>> obtenerCuidadores() async {
    try {
      final collection = _cuidadoresCollection;
      if (collection == null) {
        return [];
      }

      // Primero intentar con índice compuesto, si falla usar fallback
      try {
        final querySnapshot = await collection
            .where('activo', isEqualTo: true)
            .orderBy('fecha_creacion', descending: false)
            .get();

        return querySnapshot.docs
            .map((doc) => Cuidador.fromFirestore(doc))
            .toList();
      } catch (indexError) {
        print('Índice no disponible, usando consulta alternativa');
        
        // Fallback: obtener todos y filtrar/ordenar en cliente
        final querySnapshot = await collection
            .where('activo', isEqualTo: true)
            .get();

        final cuidadores = querySnapshot.docs
            .map((doc) => Cuidador.fromFirestore(doc))
            .toList();
        
        // Ordenar por fecha de creación en el cliente
        cuidadores.sort((a, b) => a.fechaCreacion.compareTo(b.fechaCreacion));
        
        return cuidadores;
      }
    } catch (e) {
      print('Error obteniendo cuidadores: $e');
      return [];
    }
  }

  // Obtener cuidadores en tiempo real (Stream)
  Stream<List<Cuidador>> obtenerCuidadoresStream() {
    final collection = _cuidadoresCollection;
    if (collection == null) {
      return Stream.value([]);
    }

    // Usar solo el filtro activo para evitar índice compuesto
    return collection
        .where('activo', isEqualTo: true)
        .snapshots()
        .map((querySnapshot) {
      final cuidadores = querySnapshot.docs
          .map((doc) => Cuidador.fromFirestore(doc))
          .toList();
      
      // Ordenar por fecha de creación en el cliente
      cuidadores.sort((a, b) => a.fechaCreacion.compareTo(b.fechaCreacion));
      
      return cuidadores;
    });
  }

  // Actualizar un cuidador existente
  Future<bool> actualizarCuidador(Cuidador cuidador) async {
    try {
      final collection = _cuidadoresCollection;
      if (collection == null) {
        throw Exception('Usuario no autenticado');
      }

      // Validar datos antes de actualizar
      if (!cuidador.tieneEmailValido) {
        throw Exception('Email no válido');
      }

      if (!cuidador.tieneTelefonoValido) {
        throw Exception('Teléfono no válido');
      }

      // Verificar que no exista otro cuidador con el mismo email (excluyendo el actual)
      final emailEnUso = await emailYaEnUso(cuidador.email, excludeId: cuidador.id);
      if (emailEnUso) {
        throw Exception('Ya existe otro cuidador con este email');
      }

      final cuidadorActualizado = cuidador.copyWith(
        fechaActualizacion: DateTime.now(),
      );

      await collection.doc(cuidador.id).update(cuidadorActualizado.toMap());

      print('=== CUIDADOR ACTUALIZADO EN FIREBASE ===');
      print('ID: ${cuidadorActualizado.id}');
      print('Nombre: ${cuidadorActualizado.nombre}');
      print('Email: ${cuidadorActualizado.email}');

      return true;
    } catch (e) {
      print('Error actualizando cuidador: $e');
      rethrow;
    }
  }

  // Eliminar un cuidador (marcarlo como inactivo)
  Future<bool> eliminarCuidador(String cuidadorId) async {
    try {
      final collection = _cuidadoresCollection;
      if (collection == null) {
        throw Exception('Usuario no autenticado');
      }

      await collection.doc(cuidadorId).update({
        'activo': false,
        'fecha_actualizacion': Timestamp.fromDate(DateTime.now()),
      });

      print('=== CUIDADOR ELIMINADO EN FIREBASE ===');
      print('ID: $cuidadorId');

      return true;
    } catch (e) {
      print('Error eliminando cuidador: $e');
      return false;
    }
  }

  // Obtener un cuidador específico por ID
  Future<Cuidador?> obtenerCuidadorPorId(String cuidadorId) async {
    try {
      final collection = _cuidadoresCollection;
      if (collection == null) {
        return null;
      }

      final doc = await collection.doc(cuidadorId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['activo'] == true) {
          return Cuidador.fromFirestore(doc);
        }
      }
      return null;
    } catch (e) {
      print('Error obteniendo cuidador por ID: $e');
      return null;
    }
  }

  // Actualizar configuración de notificaciones de un cuidador
  Future<bool> actualizarNotificaciones(String cuidadorId, NotificacionesCuidador notificaciones) async {
    try {
      final collection = _cuidadoresCollection;
      if (collection == null) {
        throw Exception('Usuario no autenticado');
      }

      await collection.doc(cuidadorId).update({
        'notificaciones': notificaciones.toMap(),
        'fecha_actualizacion': Timestamp.fromDate(DateTime.now()),
      });

      print('=== NOTIFICACIONES ACTUALIZADAS ===');
      print('Cuidador ID: $cuidadorId');

      return true;
    } catch (e) {
      print('Error actualizando notificaciones: $e');
      return false;
    }
  }

  // Contar cuidadores activos
  Future<int> contarCuidadoresActivos() async {
    try {
      final cuidadores = await obtenerCuidadores();
      return cuidadores.length;
    } catch (e) {
      print('Error contando cuidadores: $e');
      return 0;
    }
  }

  // Obtener cuidadores por relación
  Future<List<Cuidador>> obtenerCuidadoresPorRelacion(String relacion) async {
    try {
      final collection = _cuidadoresCollection;
      if (collection == null) {
        return [];
      }

      // Usar filtros sin orderBy para evitar índice compuesto
      final querySnapshot = await collection
          .where('activo', isEqualTo: true)
          .where('relacion', isEqualTo: relacion)
          .get();

      final cuidadores = querySnapshot.docs
          .map((doc) => Cuidador.fromFirestore(doc))
          .toList();
      
      // Ordenar por fecha de creación en el cliente
      cuidadores.sort((a, b) => a.fechaCreacion.compareTo(b.fechaCreacion));
      
      return cuidadores;
    } catch (e) {
      print('Error obteniendo cuidadores por relación: $e');
      return [];
    }
  }

  // Verificar si un email ya está en uso por otro cuidador
  Future<bool> emailYaEnUso(String email, {String? excludeId}) async {
    try {
      final collection = _cuidadoresCollection;
      if (collection == null) {
        return false;
      }

      // Usar solo filtro por email para evitar índice compuesto
      final querySnapshot = await collection
          .where('email', isEqualTo: email.trim())
          .get();

      // Filtrar por activo y excludeId en el cliente
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

  // Restaurar un cuidador eliminado (reactivarlo)
  Future<bool> restaurarCuidador(String cuidadorId) async {
    try {
      final collection = _cuidadoresCollection;
      if (collection == null) {
        throw Exception('Usuario no autenticado');
      }

      await collection.doc(cuidadorId).update({
        'activo': true,
        'fecha_actualizacion': Timestamp.fromDate(DateTime.now()),
      });

      print('=== CUIDADOR RESTAURADO ===');
      print('ID: $cuidadorId');

      return true;
    } catch (e) {
      print('Error restaurando cuidador: $e');
      return false;
    }
  }

  // Método para migrar datos existentes (si es necesario)
  Future<void> migrarDatos(List<Map<String, String>> cuidadoresLegacy) async {
    try {
      for (var cuidadorMap in cuidadoresLegacy) {
        final cuidador = Cuidador.fromLegacyMap(cuidadorMap);
        await agregarCuidador(cuidador);
      }
      print('=== MIGRACIÓN COMPLETADA ===');
    } catch (e) {
      print('Error en migración: $e');
    }
  }

  // ========== MÉTODOS PARA DASHBOARD DE CUIDADOR ==========

  // Obtener solo los pacientes asignados al cuidador actual
  Future<List<UserModel>> getPacientes() async {
    try {
      final currentUserId = currentUser?.uid;
      if (currentUserId == null) {
        print('Usuario no autenticado');
        return [];
      }

      // Buscar en la colección 'users' aquellos que tengan este cuidador asignado
      // Los pacientes tienen una subcolección 'cuidadores' donde están los cuidadores asignados
      List<UserModel> pacientesAsignados = [];
      
      // Obtener todos los usuarios que son pacientes
      final allUsersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'user')
          .get();
      
      // Verificar cuáles de estos pacientes tienen asignado al cuidador actual
      for (final userDoc in allUsersSnapshot.docs) {
        final cuidadoresSnapshot = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('cuidadores')
            .where('email', isEqualTo: currentUser?.email)
            .where('activo', isEqualTo: true)
            .get();
        
        if (cuidadoresSnapshot.docs.isNotEmpty) {
          pacientesAsignados.add(UserModel.fromFirestore(userDoc));
        }
      }
      
      print('=== PACIENTES ASIGNADOS AL CUIDADOR ===');
      print('Cuidador: ${currentUser?.email}');
      print('Pacientes encontrados: ${pacientesAsignados.length}');
      
      return pacientesAsignados;
    } catch (e) {
      print('Error obteniendo pacientes asignados: $e');
      return [];
    }
  }

  // Obtener total de recordatorios de todos los pacientes
  Future<List<Reminder>> getAllRemindersFromPatients() async {
    try {
      final snapshot = await _firestore.collection('reminders').get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        // Convertir Timestamp a DateTime si es necesario
        if (data['dateTime'] is Timestamp) {
          data['dateTime'] = (data['dateTime'] as Timestamp).toDate().toIso8601String();
        }
        return Reminder.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error obteniendo recordatorios de pacientes: $e');
      return [];
    }
  }

  // Obtener recordatorios de hoy de todos los pacientes
  Future<List<Reminder>> getTodayRemindersFromAllPatients() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final snapshot = await _firestore
          .collection('reminders')
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        if (data['dateTime'] is Timestamp) {
          data['dateTime'] = (data['dateTime'] as Timestamp).toDate().toIso8601String();
        }
        return Reminder.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error obteniendo recordatorios de hoy: $e');
      return [];
    }
  }

  // Obtener estadísticas para el dashboard del cuidador
  Future<Map<String, dynamic>> getCuidadorStats() async {
    try {
      // Obtener pacientes
      final pacientes = await getPacientes();
      
      // Obtener todos los recordatorios
      final allReminders = await getAllRemindersFromPatients();
      
      // Obtener recordatorios de hoy
      final todayReminders = await getTodayRemindersFromAllPatients();
      
      // Recordatorios pendientes de hoy
      final pendingToday = todayReminders.where((r) => !r.isCompleted).length;
      
      // Recordatorios completados de hoy
      final completedToday = todayReminders.where((r) => r.isCompleted).length;
      
      // Total de recordatorios activos (no completados)
      final activeReminders = allReminders.where((r) => !r.isCompleted).length;

      // Adherencia general (porcentaje de completados vs total)
      final totalCompleted = allReminders.where((r) => r.isCompleted).length;
      final adherenceRate = allReminders.isNotEmpty 
          ? (totalCompleted / allReminders.length * 100).round()
          : 0;

      // Contar por tipos de recordatorio
      final medicacionCount = allReminders.where((r) => r.type == 'Medicación').length;
      final tareasCount = allReminders.where((r) => r.type == 'Tarea').length;
      final citasCount = allReminders.where((r) => r.type == 'Cita').length;

      return {
        'totalPacientes': pacientes.length,
        'alertasHoy': pendingToday,
        'completadosHoy': completedToday,
        'recordatoriosActivos': activeReminders,
        'adherenciaGeneral': adherenceRate,
        'totalRecordatorios': allReminders.length,
        'recordatoriosPorTipo': {
          'medicacion': medicacionCount,
          'tareas': tareasCount,
          'citas': citasCount,
        },
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
        'recordatoriosPorTipo': {
          'medicacion': 0,
          'tareas': 0,
          'citas': 0,
        },
        'recordatoriosHoy': 0,
      };
    }
  }

  // Obtener recordatorios recientes (últimos 10)
  Future<List<Reminder>> getRecentReminders() async {
    try {
      final snapshot = await _firestore
          .collection('reminders')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        if (data['dateTime'] is Timestamp) {
          data['dateTime'] = (data['dateTime'] as Timestamp).toDate().toIso8601String();
        }
        return Reminder.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error obteniendo recordatorios recientes: $e');
      return [];
    }
  }

  // Obtener pacientes con baja adherencia (menos del 70%)
  Future<List<Map<String, dynamic>>> getPacientesConBajaAdherencia() async {
    try {
      final pacientes = await getPacientes();
      List<Map<String, dynamic>> pacientesBajaAdherencia = [];

      for (final paciente in pacientes) {
        // Obtener recordatorios del paciente usando el UID del documento
        final uid = paciente.email; // Temporal hasta tener el UID correcto
        final snapshot = await _firestore
            .collection('reminders')
            .where('userId', isEqualTo: uid)
            .get();

        final recordatorios = snapshot.docs.map((doc) {
          final data = doc.data();
          if (data['dateTime'] is Timestamp) {
            data['dateTime'] = (data['dateTime'] as Timestamp).toDate().toIso8601String();
          }
          return Reminder.fromMap(data);
        }).toList();

        if (recordatorios.isNotEmpty) {
          final completados = recordatorios.where((r) => r.isCompleted).length;
          final adherencia = (completados / recordatorios.length * 100).round();
          
          if (adherencia < 70) {
            pacientesBajaAdherencia.add({
              'paciente': paciente,
              'adherencia': adherencia,
              'totalRecordatorios': recordatorios.length,
              'completados': completados,
            });
          }
        }
      }

      return pacientesBajaAdherencia;
    } catch (e) {
      print('Error obteniendo pacientes con baja adherencia: $e');
      return [];
    }
  }

  // Obtener alertas críticas (recordatorios vencidos no completados)
  Future<List<Reminder>> getAlertasCriticas() async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('reminders')
          .where('isCompleted', isEqualTo: false)
          .where('dateTime', isLessThan: Timestamp.fromDate(now))
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        if (data['dateTime'] is Timestamp) {
          data['dateTime'] = (data['dateTime'] as Timestamp).toDate().toIso8601String();
        }
        return Reminder.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error obteniendo alertas críticas: $e');
      return [];
    }
  }

  // Obtener recordatorios próximos (en las próximas 2 horas)
  Future<List<Reminder>> getRecordatoriosProximos() async {
    try {
      final now = DateTime.now();
      final twoHoursLater = now.add(const Duration(hours: 2));
      
      final snapshot = await _firestore
          .collection('reminders')
          .where('isCompleted', isEqualTo: false)
          .where('dateTime', isGreaterThan: Timestamp.fromDate(now))
          .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(twoHoursLater))
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        if (data['dateTime'] is Timestamp) {
          data['dateTime'] = (data['dateTime'] as Timestamp).toDate().toIso8601String();
        }
        return Reminder.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error obteniendo recordatorios próximos: $e');
      return [];
    }
  }
}
