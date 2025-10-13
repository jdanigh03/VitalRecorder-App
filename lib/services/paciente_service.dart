import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/paciente.dart';

/// Servicio para gestionar operaciones relacionadas con pacientes
/// Incluye operaciones CRUD y gestión de relaciones cuidador-paciente
class PacienteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Nombre de la colección en Firestore
  static const String _collection = 'pacientes';

  /// Obtiene todos los pacientes asignados a un cuidador específico
  /// 
  /// [cuidadorId] ID del cuidador
  /// Retorna una lista de pacientes o lista vacía si no hay pacientes
  Future<List<Paciente>> getPacientesByCuidador(String cuidadorId) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('cuidadoresIds', arrayContains: cuidadorId)
          .where('activo', isEqualTo: true)
          .orderBy('nombre')
          .get();

      return query.docs
          .map((doc) => Paciente.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error al obtener pacientes del cuidador: $e');
      return [];
    }
  }

  /// Obtiene un paciente específico por su ID
  /// 
  /// [pacienteId] ID del paciente
  /// Retorna el paciente o null si no existe
  Future<Paciente?> getPacienteById(String pacienteId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(pacienteId).get();
      
      if (doc.exists) {
        return Paciente.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error al obtener paciente por ID: $e');
      return null;
    }
  }

  /// Obtiene un paciente por su email
  /// 
  /// [email] Email del paciente
  /// Retorna el paciente o null si no existe
  Future<Paciente?> getPacienteByEmail(String email) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('email', isEqualTo: email.toLowerCase().trim())
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return Paciente.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      print('Error al obtener paciente por email: $e');
      return null;
    }
  }

  /// Asigna un cuidador a un paciente
  /// 
  /// [pacienteId] ID del paciente
  /// [cuidadorId] ID del cuidador a asignar
  /// Retorna true si la operación fue exitosa
  Future<bool> asignarCuidador(String pacienteId, String cuidadorId) async {
    try {
      final pacienteRef = _firestore.collection(_collection).doc(pacienteId);
      
      await _firestore.runTransaction((transaction) async {
        final pacienteDoc = await transaction.get(pacienteRef);
        
        if (!pacienteDoc.exists) {
          throw Exception('El paciente no existe');
        }

        final paciente = Paciente.fromFirestore(pacienteDoc);
        
        // Verificar si el cuidador ya está asignado
        if (paciente.tieneCuidador(cuidadorId)) {
          print('El cuidador ya está asignado a este paciente');
          return;
        }

        // Agregar el cuidador a la lista
        final nuevaListaCuidadores = List<String>.from(paciente.cuidadoresIds);
        nuevaListaCuidadores.add(cuidadorId);

        transaction.update(pacienteRef, {
          'cuidadoresIds': nuevaListaCuidadores,
        });
      });

      return true;
    } catch (e) {
      print('Error al asignar cuidador: $e');
      return false;
    }
  }

  /// Remueve un cuidador de un paciente
  /// 
  /// [pacienteId] ID del paciente
  /// [cuidadorId] ID del cuidador a remover
  /// Retorna true si la operación fue exitosa
  Future<bool> removerCuidador(String pacienteId, String cuidadorId) async {
    try {
      final pacienteRef = _firestore.collection(_collection).doc(pacienteId);
      
      await _firestore.runTransaction((transaction) async {
        final pacienteDoc = await transaction.get(pacienteRef);
        
        if (!pacienteDoc.exists) {
          throw Exception('El paciente no existe');
        }

        final paciente = Paciente.fromFirestore(pacienteDoc);
        
        // Verificar si el cuidador está asignado
        if (!paciente.tieneCuidador(cuidadorId)) {
          print('El cuidador no está asignado a este paciente');
          return;
        }

        // Remover el cuidador de la lista
        final nuevaListaCuidadores = List<String>.from(paciente.cuidadoresIds);
        nuevaListaCuidadores.remove(cuidadorId);

        transaction.update(pacienteRef, {
          'cuidadoresIds': nuevaListaCuidadores,
        });
      });

      return true;
    } catch (e) {
      print('Error al remover cuidador: $e');
      return false;
    }
  }

  /// Crea un nuevo paciente en la base de datos
  /// 
  /// [paciente] Datos del paciente a crear
  /// Retorna el ID del paciente creado o null si hubo error
  Future<String?> crearPaciente(Paciente paciente) async {
    try {
      final docRef = await _firestore.collection(_collection).add(paciente.toMap());
      return docRef.id;
    } catch (e) {
      print('Error al crear paciente: $e');
      return null;
    }
  }

  /// Actualiza los datos de un paciente existente
  /// 
  /// [paciente] Datos actualizados del paciente
  /// Retorna true si la operación fue exitosa
  Future<bool> actualizarPaciente(Paciente paciente) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(paciente.id)
          .update(paciente.toMap());
      return true;
    } catch (e) {
      print('Error al actualizar paciente: $e');
      return false;
    }
  }

  /// Desactiva un paciente (soft delete)
  /// 
  /// [pacienteId] ID del paciente a desactivar
  /// Retorna true si la operación fue exitosa
  Future<bool> desactivarPaciente(String pacienteId) async {
    try {
      await _firestore.collection(_collection).doc(pacienteId).update({
        'activo': false,
      });
      return true;
    } catch (e) {
      print('Error al desactivar paciente: $e');
      return false;
    }
  }

  /// Reactiva un paciente previamente desactivado
  /// 
  /// [pacienteId] ID del paciente a reactivar
  /// Retorna true si la operación fue exitosa
  Future<bool> reactivarPaciente(String pacienteId) async {
    try {
      await _firestore.collection(_collection).doc(pacienteId).update({
        'activo': true,
      });
      return true;
    } catch (e) {
      print('Error al reactivar paciente: $e');
      return false;
    }
  }

  /// Busca pacientes por nombre (para funcionalidades de búsqueda)
  /// 
  /// [termino] Término de búsqueda
  /// [cuidadorId] ID del cuidador (opcional, para filtrar solo sus pacientes)
  /// Retorna lista de pacientes que coinciden con la búsqueda
  Future<List<Paciente>> buscarPacientes(String termino, {String? cuidadorId}) async {
    try {
      Query query = _firestore
          .collection(_collection)
          .where('activo', isEqualTo: true);

      // Si se especifica un cuidador, filtrar solo sus pacientes
      if (cuidadorId != null) {
        query = query.where('cuidadoresIds', arrayContains: cuidadorId);
      }

      final snapshot = await query.get();
      
      final todosPacientes = snapshot.docs
          .map((doc) => Paciente.fromFirestore(doc))
          .toList();

      // Filtrar por término de búsqueda (búsqueda local por rendimiento)
      final terminoBusqueda = termino.toLowerCase().trim();
      return todosPacientes.where((paciente) {
        return paciente.nombre.toLowerCase().contains(terminoBusqueda) ||
               paciente.email.toLowerCase().contains(terminoBusqueda);
      }).toList();
    } catch (e) {
      print('Error al buscar pacientes: $e');
      return [];
    }
  }

  /// Obtiene estadísticas de pacientes para un cuidador
  /// 
  /// [cuidadorId] ID del cuidador
  /// Retorna un mapa con estadísticas relevantes
  Future<Map<String, dynamic>> getEstadisticasPacientes(String cuidadorId) async {
    try {
      final pacientes = await getPacientesByCuidador(cuidadorId);
      
      return {
        'totalPacientes': pacientes.length,
        'pacientesActivos': pacientes.where((p) => p.activo).length,
        'pacientesInactivos': pacientes.where((p) => !p.activo).length,
        'pacientesConInformacionMedica': pacientes.where((p) => p.informacionMedica.isNotEmpty).length,
      };
    } catch (e) {
      print('Error al obtener estadísticas: $e');
      return {
        'totalPacientes': 0,
        'pacientesActivos': 0,
        'pacientesInactivos': 0,
        'pacientesConInformacionMedica': 0,
      };
    }
  }

  /// Obtiene un stream de pacientes para un cuidador (para actualizaciones en tiempo real)
  /// 
  /// [cuidadorId] ID del cuidador
  /// Retorna un stream de lista de pacientes
  Stream<List<Paciente>> getPacientesStreamByCuidador(String cuidadorId) {
    return _firestore
        .collection(_collection)
        .where('cuidadoresIds', arrayContains: cuidadorId)
        .where('activo', isEqualTo: true)
        .orderBy('nombre')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Paciente.fromFirestore(doc))
            .toList());
  }

  /// Verifica si un paciente específico pertenece a un cuidador
  /// 
  /// [pacienteId] ID del paciente
  /// [cuidadorId] ID del cuidador
  /// Retorna true si el paciente pertenece al cuidador
  Future<bool> pacientePerteneceACuidador(String pacienteId, String cuidadorId) async {
    try {
      final paciente = await getPacienteById(pacienteId);
      return paciente?.tieneCuidador(cuidadorId) ?? false;
    } catch (e) {
      print('Error al verificar relación paciente-cuidador: $e');
      return false;
    }
  }

  /// Actualiza solo la información médica de un paciente
  /// 
  /// [pacienteId] ID del paciente
  /// [informacionMedica] Nueva información médica
  /// Retorna true si la operación fue exitosa
  Future<bool> actualizarInformacionMedica(String pacienteId, Map<String, dynamic> informacionMedica) async {
    try {
      await _firestore.collection(_collection).doc(pacienteId).update({
        'informacionMedica': informacionMedica,
      });
      return true;
    } catch (e) {
      print('Error al actualizar información médica: $e');
      return false;
    }
  }
}
