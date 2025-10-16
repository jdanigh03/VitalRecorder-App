import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/invitacion_cuidador.dart';
import '../models/cuidador.dart';
import '../models/user.dart';
import '../models/paciente.dart';
import '../services/user_service.dart';
import '../services/paciente_service.dart';
import 'notification_service.dart';

class InvitacionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  final PacienteService _pacienteService = PacienteService();
  final NotificationService _notificationService = NotificationService();

  User? get currentUser => _auth.currentUser;

  // Colección global de invitaciones
  CollectionReference get _invitacionesCollection =>
      _firestore.collection('invitaciones_cuidador');

  // ========== MÉTODOS PARA PACIENTES ==========

  // Enviar invitación a un cuidador
  Future<String?> enviarInvitacion({
    required String cuidadorEmail,
    required String cuidadorNombre,
    required String relacion,
    String? telefono,
    String? mensaje,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // Verificar que el email del cuidador existe como usuario registrado con rol 'cuidador'
      final cuidadorExists = await _verificarCuidadorExiste(cuidadorEmail);
      if (!cuidadorExists) {
        throw Exception('No existe un cuidador registrado con este email');
      }

      // Verificar que no existe una invitación pendiente o aceptada
      final invitacionExistente = await _verificarInvitacionExistente(
          user.uid, cuidadorEmail);
      if (invitacionExistente != null) {
        if (invitacionExistente.esPendiente) {
          throw Exception('Ya tienes una invitación pendiente con este cuidador');
        } else if (invitacionExistente.esAceptada) {
          throw Exception('Este cuidador ya es tu cuidador asignado');
        }
      }

      // Obtener información del paciente
      final pacienteData = await _userService.getCurrentUserData();
      final pacienteNombre = pacienteData?.persona.nombres ?? user.displayName ?? 'Usuario';

      // Crear la invitación
      final docRef = _invitacionesCollection.doc();
      final invitacion = InvitacionCuidador(
        id: docRef.id,
        pacienteId: user.uid,
        pacienteEmail: user.email!,
        pacienteNombre: pacienteNombre,
        cuidadorEmail: cuidadorEmail.trim().toLowerCase(),
        cuidadorNombre: cuidadorNombre.trim(),
        relacion: relacion,
        telefono: telefono?.trim(),
        estado: EstadoInvitacion.pendiente,
        fechaCreacion: DateTime.now(),
        mensaje: mensaje?.trim(),
      );

      await docRef.set(invitacion.toMap());

      print('=== INVITACIÓN ENVIADA ===');
      print('ID: ${invitacion.id}');
      print('Paciente: ${invitacion.pacienteNombre}');
      print('Cuidador: ${invitacion.cuidadorEmail}');
      print('Estado: ${invitacion.estadoTexto}');

      return docRef.id;
    } catch (e) {
      print('Error enviando invitación: $e');
      rethrow;
    }
  }

  // Obtener invitaciones enviadas por el paciente
  Future<List<InvitacionCuidador>> getInvitacionesEnviadas() async {
    try {
      final user = currentUser;
      if (user == null) return [];

      final querySnapshot = await _invitacionesCollection
          .where('paciente_id', isEqualTo: user.uid)
          .orderBy('fecha_creacion', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => InvitacionCuidador.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error obteniendo invitaciones enviadas: $e');
      return [];
    }
  }

  // Cancelar invitación pendiente
  Future<bool> cancelarInvitacion(String invitacionId) async {
    try {
      await _invitacionesCollection.doc(invitacionId).update({
        'estado': 'cancelada',
        'fecha_respuesta': Timestamp.fromDate(DateTime.now()),
      });

      print('=== INVITACIÓN CANCELADA ===');
      print('ID: $invitacionId');
      return true;
    } catch (e) {
      print('Error cancelando invitación: $e');
      return false;
    }
  }

  // ========== MÉTODOS PARA CUIDADORES ==========

  // Obtener invitaciones recibidas por el cuidador
  Future<List<InvitacionCuidador>> getInvitacionesRecibidas() async {
    try {
      final user = currentUser;
      if (user == null) {
        print('=== ERROR: Usuario no autenticado ===');
        return [];
      }

      final cuidadorEmail = user.email!.toLowerCase();
      print('=== BUSCANDO INVITACIONES PARA CUIDADOR ===');
      print('Email del cuidador: $cuidadorEmail');

      // Usar consulta simple sin orderBy para evitar índice compuesto
      final querySnapshot = await _invitacionesCollection
          .where('cuidador_email', isEqualTo: cuidadorEmail)
          .get();

      print('Documentos encontrados: ${querySnapshot.docs.length}');
      
      if (querySnapshot.docs.isNotEmpty) {
        print('=== DOCUMENTOS ENCONTRADOS ===');
        for (final doc in querySnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          print('ID: ${doc.id}');
          print('Email cuidador: ${data['cuidador_email']}');
          print('Estado: ${data['estado']}');
          print('Paciente: ${data['paciente_nombre']}');
          print('---');
        }
      } else {
        print('=== NO SE ENCONTRARON DOCUMENTOS ===');
        print('Verificando si hay documentos en la colección...');
        
        // Consulta para ver todos los documentos
        final allDocs = await _invitacionesCollection.limit(10).get();
        print('Total documentos en colección: ${allDocs.docs.length}');
        
        if (allDocs.docs.isNotEmpty) {
          print('=== PRIMEROS DOCUMENTOS EN COLECCIÓN ===');
          for (final doc in allDocs.docs.take(3)) {
            final data = doc.data() as Map<String, dynamic>;
            print('ID: ${doc.id}');
            print('Email cuidador: ${data['cuidador_email']}');
            print('Email paciente: ${data['paciente_email']}');
            print('Estado: ${data['estado']}');
            print('---');
          }
        }
      }

      final invitaciones = querySnapshot.docs
          .map((doc) => InvitacionCuidador.fromFirestore(doc))
          .toList();
      
      // Ordenar en el cliente por fecha de creación (más recientes primero)
      invitaciones.sort((a, b) => b.fechaEnvio.compareTo(a.fechaEnvio));
      
      print('=== RESULTADO FINAL ===');
      print('Invitaciones obtenidas: ${invitaciones.length}');
      print('Invitaciones pendientes: ${invitaciones.where((i) => i.esPendiente).length}');
      
      return invitaciones;
    } catch (e) {
      print('Error obteniendo invitaciones recibidas: $e');
      return [];
    }
  }

  // Stream de invitaciones recibidas
  Stream<List<InvitacionCuidador>> getInvitacionesRecibidasStream() {
    final user = currentUser;
    if (user == null) return Stream.value([]);

    return _invitacionesCollection
        .where('cuidador_email', isEqualTo: user.email!.toLowerCase())
        .snapshots()
        .map((snapshot) {
          final invitaciones = snapshot.docs
              .map((doc) => InvitacionCuidador.fromFirestore(doc))
              .toList();
          
          // Ordenar en el cliente por fecha de creación (más recientes primero)
          invitaciones.sort((a, b) => b.fechaEnvio.compareTo(a.fechaEnvio));
          
          return invitaciones;
        });
  }

  // Aceptar invitación
  Future<bool> aceptarInvitacion(String invitacionId) async {
    try {
      // Obtener la invitación
      final invitacionDoc = await _invitacionesCollection.doc(invitacionId).get();
      if (!invitacionDoc.exists) {
        throw Exception('La invitación no existe');
      }

      final invitacion = InvitacionCuidador.fromFirestore(invitacionDoc);
      if (!invitacion.esPendiente) {
        throw Exception('Esta invitación ya fue procesada');
      }

      // Actualizar estado de la invitación
      await _invitacionesCollection.doc(invitacionId).update({
        'estado': 'aceptada',
        'fecha_respuesta': Timestamp.fromDate(DateTime.now()),
      });

      // Crear la vinculación en la subcolección del paciente
      await _crearVinculacionCuidador(invitacion);

      print('=== INVITACIÓN ACEPTADA ===');
      print('ID: $invitacionId');
      print('Vinculación creada entre ${invitacion.pacienteNombre} y ${invitacion.cuidadorNombre}');

      // Enviar notificación al paciente (NO al cuidador)
      await _notificationService.enviarNotificacionPushAUsuario(
        destinatarioUserId: invitacion.pacienteId,
        titulo: '¡Invitación Aceptada!',
        mensaje: '${invitacion.cuidadorNombre} ha aceptado tu invitación para ser tu cuidador.',
        data: {
          'tipo': 'invitacion_aceptada',
          'cuidador_nombre': invitacion.cuidadorNombre,
          'relacion': invitacion.relacion,
        },
      );

      return true;
    } catch (e) {
      print('Error aceptando invitación: $e');
      rethrow;
    }
  }

  // Rechazar invitación
  Future<bool> rechazarInvitacion(String invitacionId, {String? motivo}) async {
    try {
      await _invitacionesCollection.doc(invitacionId).update({
        'estado': 'rechazada',
        'fecha_respuesta': Timestamp.fromDate(DateTime.now()),
        if (motivo != null) 'motivo_rechazo': motivo,
      });

      print('=== INVITACIÓN RECHAZADA ===');
      print('ID: $invitacionId');
      return true;
    } catch (e) {
      print('Error rechazando invitación: $e');
      return false;
    }
  }

  // ========== MÉTODOS AUXILIARES ==========

  // Verificar si un cuidador existe como usuario registrado
  Future<bool> _verificarCuidadorExiste(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .where('role', isEqualTo: 'cuidador')
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error verificando cuidador: $e');
      return false;
    }
  }

  // Verificar si existe invitación entre paciente y cuidador
  Future<InvitacionCuidador?> _verificarInvitacionExistente(
      String pacienteId, String cuidadorEmail) async {
    try {
      final querySnapshot = await _invitacionesCollection
          .where('paciente_id', isEqualTo: pacienteId)
          .where('cuidador_email', isEqualTo: cuidadorEmail.trim().toLowerCase())
          .where('estado', whereIn: ['pendiente', 'aceptada'])
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return InvitacionCuidador.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('Error verificando invitación existente: $e');
      return null;
    }
  }

  // Crear vinculación en la subcolección del paciente y sincronizar con el nuevo sistema
  Future<void> _crearVinculacionCuidador(InvitacionCuidador invitacion) async {
    try {
      // Obtener el ID del cuidador desde la colección users
      final cuidadorUserDoc = await _firestore
          .collection('users')
          .where('email', isEqualTo: invitacion.cuidadorEmail)
          .where('role', isEqualTo: 'cuidador')
          .limit(1)
          .get();

      if (cuidadorUserDoc.docs.isEmpty) {
        throw Exception('No se encontró el usuario cuidador');
      }

      final cuidadorUserId = cuidadorUserDoc.docs.first.id;

      // 1. Crear documento en la subcolección del paciente (sistema original)
      final cuidadorData = Cuidador(
        id: '', // Se asignará automáticamente
        nombre: invitacion.cuidadorNombre,
        email: invitacion.cuidadorEmail,
        telefono: invitacion.telefono ?? '',
        relacion: invitacion.relacion,
        notificaciones: NotificacionesCuidador(),
        fechaCreacion: DateTime.now(),
      );

      final docRef = _firestore
          .collection('users')
          .doc(invitacion.pacienteId)
          .collection('cuidadores')
          .doc();

      final cuidadorConId = cuidadorData.copyWith(id: docRef.id);
      await docRef.set(cuidadorConId.toMap());

      // 2. Sincronizar con el nuevo sistema de pacientes
      await _sincronizarConNuevoSistemaPacientes(invitacion, cuidadorUserId);

      print('=== VINCULACIÓN CREADA Y SINCRONIZADA ===');
      print('Paciente ID: ${invitacion.pacienteId}');
      print('Cuidador: ${invitacion.cuidadorNombre}');
      print('Cuidador User ID: $cuidadorUserId');
      print('Relación: ${invitacion.relacion}');
    } catch (e) {
      print('Error creando vinculación: $e');
      rethrow;
    }
  }

  // Sincronizar la vinculación con el nuevo sistema de PacienteService
  Future<void> _sincronizarConNuevoSistemaPacientes(InvitacionCuidador invitacion, String cuidadorUserId) async {
    try {
      // Verificar si ya existe un perfil de paciente en la nueva colección
      final pacienteExistente = await _pacienteService.getPacienteByEmail(invitacion.pacienteEmail);
      
      if (pacienteExistente == null) {
        // Crear nuevo perfil de paciente
        final userData = await _userService.getUserData(invitacion.pacienteId);
        if (userData != null) {
          final nuevoPaciente = Paciente(
            id: '', // Se asignará automáticamente por Firestore
            nombre: invitacion.pacienteNombre,
            email: invitacion.pacienteEmail,
            telefono: userData.settings.telefono,
            cuidadoresIds: [cuidadorUserId],
            informacionMedica: {},
            fechaRegistro: DateTime.now(),
          );
          
          final pacienteId = await _pacienteService.crearPaciente(nuevoPaciente);
          print('=== PERFIL DE PACIENTE CREADO ===');
          print('Paciente ID en nueva colección: $pacienteId');
        }
      } else {
        // Actualizar paciente existente agregando el cuidador
        final exito = await _pacienteService.asignarCuidador(pacienteExistente.id, cuidadorUserId);
        if (exito) {
          print('=== CUIDADOR ASIGNADO A PACIENTE EXISTENTE ===');
          print('Paciente ID: ${pacienteExistente.id}');
          print('Cuidador agregado: $cuidadorUserId');
        }
      }
      
    } catch (e) {
      print('Error sincronizando con nuevo sistema: $e');
      // No lanzar la excepción para no afectar el flujo principal
      // El sistema original seguirá funcionando
    }
  }

  // Obtener estadísticas de invitaciones
  Future<Map<String, int>> getEstadisticasInvitaciones() async {
    try {
      final user = currentUser;
      if (user == null) return {};

      // Para pacientes: contar invitaciones enviadas
      final enviadas = await _invitacionesCollection
          .where('paciente_id', isEqualTo: user.uid)
          .get();

      // Para cuidadores: contar invitaciones recibidas
      final recibidas = await _invitacionesCollection
          .where('cuidador_email', isEqualTo: user.email!.toLowerCase())
          .get();

      final enviadasPendientes = enviadas.docs
          .where((doc) => (doc.data() as Map<String, dynamic>)['estado'] == 'pendiente')
          .length;

      final recibidasPendientes = recibidas.docs
          .where((doc) => (doc.data() as Map<String, dynamic>)['estado'] == 'pendiente')
          .length;

      return {
        'invitaciones_enviadas': enviadas.docs.length,
        'invitaciones_enviadas_pendientes': enviadasPendientes,
        'invitaciones_recibidas': recibidas.docs.length,
        'invitaciones_recibidas_pendientes': recibidasPendientes,
      };
    } catch (e) {
      print('Error obteniendo estadísticas: $e');
      return {};
    }
  }

  // Limpiar invitaciones antiguas (más de 30 días)
  Future<void> limpiarInvitacionesAntiguas() async {
    try {
      final fechaLimite = DateTime.now().subtract(const Duration(days: 30));
      
      final querySnapshot = await _invitacionesCollection
          .where('fecha_creacion', isLessThan: Timestamp.fromDate(fechaLimite))
          .where('estado', whereIn: ['rechazada', 'cancelada'])
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('=== INVITACIONES ANTIGUAS LIMPIADAS ===');
      print('Eliminadas: ${querySnapshot.docs.length}');
    } catch (e) {
      print('Error limpiando invitaciones antiguas: $e');
    }
  }
}
