import 'package:cloud_firestore/cloud_firestore.dart';

enum EstadoInvitacion {
  pendiente,
  aceptada,
  rechazada,
  cancelada
}

// Extension para agregar métodos útiles al enum
extension EstadoInvitacionExtension on EstadoInvitacion {
  String toLowerCase() {
    return toString().split('.').last.toLowerCase();
  }
  
  String toUpperCase() {
    return toString().split('.').last.toUpperCase();
  }
  
  String get name {
    return toString().split('.').last;
  }
}

class InvitacionCuidador {
  final String id;
  final String pacienteId;
  final String pacienteEmail;
  final String pacienteNombre;
  final String cuidadorEmail;
  final String cuidadorNombre;
  final String relacion;
  final String? telefono;
  final EstadoInvitacion estado;
  final DateTime fechaCreacion;
  final DateTime? fechaRespuesta;
  final String? mensaje;

  const InvitacionCuidador({
    required this.id,
    required this.pacienteId,
    required this.pacienteEmail,
    required this.pacienteNombre,
    required this.cuidadorEmail,
    required this.cuidadorNombre,
    required this.relacion,
    this.telefono,
    this.estado = EstadoInvitacion.pendiente,
    required this.fechaCreacion,
    this.fechaRespuesta,
    this.mensaje,
  });

  // Convertir a Map para Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'paciente_id': pacienteId,
      'paciente_email': pacienteEmail,
      'paciente_nombre': pacienteNombre,
      'cuidador_email': cuidadorEmail,
      'cuidador_nombre': cuidadorNombre,
      'relacion': relacion,
      'telefono': telefono,
      'estado': estado.toString().split('.').last,
      'fecha_creacion': Timestamp.fromDate(fechaCreacion),
      'fecha_respuesta': fechaRespuesta != null 
          ? Timestamp.fromDate(fechaRespuesta!)
          : null,
      'mensaje': mensaje,
    };
  }

  // Crear desde Map de Firebase
  factory InvitacionCuidador.fromMap(Map<String, dynamic> map) {
    return InvitacionCuidador(
      id: map['id'] ?? '',
      pacienteId: map['paciente_id'] ?? '',
      pacienteEmail: map['paciente_email'] ?? '',
      pacienteNombre: map['paciente_nombre'] ?? '',
      cuidadorEmail: map['cuidador_email'] ?? '',
      cuidadorNombre: map['cuidador_nombre'] ?? '',
      relacion: map['relacion'] ?? '',
      telefono: map['telefono'],
      estado: _estadoFromString(map['estado']),
      fechaCreacion: map['fecha_creacion'] is Timestamp 
          ? (map['fecha_creacion'] as Timestamp).toDate()
          : DateTime.now(),
      fechaRespuesta: map['fecha_respuesta'] is Timestamp 
          ? (map['fecha_respuesta'] as Timestamp).toDate()
          : null,
      mensaje: map['mensaje'],
    );
  }

  // Crear desde DocumentSnapshot de Firebase
  factory InvitacionCuidador.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InvitacionCuidador.fromMap({
      ...data,
      'id': doc.id,
    });
  }

  // Helper para convertir string a EstadoInvitacion
  static EstadoInvitacion _estadoFromString(String? estado) {
    switch (estado) {
      case 'aceptada':
        return EstadoInvitacion.aceptada;
      case 'rechazada':
        return EstadoInvitacion.rechazada;
      case 'cancelada':
        return EstadoInvitacion.cancelada;
      default:
        return EstadoInvitacion.pendiente;
    }
  }

  // Copiar con cambios
  InvitacionCuidador copyWith({
    String? id,
    String? pacienteId,
    String? pacienteEmail,
    String? pacienteNombre,
    String? cuidadorEmail,
    String? cuidadorNombre,
    String? relacion,
    String? telefono,
    EstadoInvitacion? estado,
    DateTime? fechaCreacion,
    DateTime? fechaRespuesta,
    String? mensaje,
  }) {
    return InvitacionCuidador(
      id: id ?? this.id,
      pacienteId: pacienteId ?? this.pacienteId,
      pacienteEmail: pacienteEmail ?? this.pacienteEmail,
      pacienteNombre: pacienteNombre ?? this.pacienteNombre,
      cuidadorEmail: cuidadorEmail ?? this.cuidadorEmail,
      cuidadorNombre: cuidadorNombre ?? this.cuidadorNombre,
      relacion: relacion ?? this.relacion,
      telefono: telefono ?? this.telefono,
      estado: estado ?? this.estado,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaRespuesta: fechaRespuesta ?? this.fechaRespuesta,
      mensaje: mensaje ?? this.mensaje,
    );
  }

  // Getters útiles
  bool get esPendiente => estado == EstadoInvitacion.pendiente;
  bool get esAceptada => estado == EstadoInvitacion.aceptada;
  bool get esRechazada => estado == EstadoInvitacion.rechazada;
  bool get esCancelada => estado == EstadoInvitacion.cancelada;

  String get estadoTexto {
    switch (estado) {
      case EstadoInvitacion.pendiente:
        return 'Pendiente';
      case EstadoInvitacion.aceptada:
        return 'Aceptada';
      case EstadoInvitacion.rechazada:
        return 'Rechazada';
      case EstadoInvitacion.cancelada:
        return 'Cancelada';
    }
  }

  String get descripcion => 
      '$pacienteNombre te invita a ser su cuidador como "$relacion"';

  // Alias para compatibilidad con código existente
  DateTime get fechaEnvio => fechaCreacion;

  @override
  String toString() {
    return 'InvitacionCuidador(id: $id, paciente: $pacienteNombre, estado: $estadoTexto)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InvitacionCuidador && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
