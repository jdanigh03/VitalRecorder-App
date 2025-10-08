import 'package:cloud_firestore/cloud_firestore.dart';

class NotificacionesCuidador {
  final bool recordatoriosMedicamentos;
  final bool recordatoriosOmitidos;
  final bool resumenDiario;
  final bool emergencias;

  NotificacionesCuidador({
    this.recordatoriosMedicamentos = true,
    this.recordatoriosOmitidos = true,
    this.resumenDiario = false,
    this.emergencias = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'recordatorios_medicamentos': recordatoriosMedicamentos,
      'recordatorios_omitidos': recordatoriosOmitidos,
      'resumen_diario': resumenDiario,
      'emergencias': emergencias,
    };
  }

  factory NotificacionesCuidador.fromMap(Map<String, dynamic> map) {
    return NotificacionesCuidador(
      recordatoriosMedicamentos: map['recordatorios_medicamentos'] ?? true,
      recordatoriosOmitidos: map['recordatorios_omitidos'] ?? true,
      resumenDiario: map['resumen_diario'] ?? false,
      emergencias: map['emergencias'] ?? true,
    );
  }

  NotificacionesCuidador copyWith({
    bool? recordatoriosMedicamentos,
    bool? recordatoriosOmitidos,
    bool? resumenDiario,
    bool? emergencias,
  }) {
    return NotificacionesCuidador(
      recordatoriosMedicamentos: recordatoriosMedicamentos ?? this.recordatoriosMedicamentos,
      recordatoriosOmitidos: recordatoriosOmitidos ?? this.recordatoriosOmitidos,
      resumenDiario: resumenDiario ?? this.resumenDiario,
      emergencias: emergencias ?? this.emergencias,
    );
  }
}

class Cuidador {
  final String id;
  final String nombre;
  final String email;
  final String telefono;
  final String relacion;
  final bool activo;
  final NotificacionesCuidador notificaciones;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;

  Cuidador({
    required this.id,
    required this.nombre,
    required this.email,
    required this.telefono,
    required this.relacion,
    this.activo = true,
    required this.notificaciones,
    required this.fechaCreacion,
    this.fechaActualizacion,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'email': email,
      'telefono': telefono,
      'relacion': relacion,
      'activo': activo,
      'notificaciones': notificaciones.toMap(),
      'fecha_creacion': Timestamp.fromDate(fechaCreacion),
      'fecha_actualizacion': fechaActualizacion != null 
          ? Timestamp.fromDate(fechaActualizacion!) 
          : null,
    };
  }

  factory Cuidador.fromMap(Map<String, dynamic> map, String documentId) {
    return Cuidador(
      id: map['id'] ?? documentId,
      nombre: map['nombre'] ?? '',
      email: map['email'] ?? '',
      telefono: map['telefono'] ?? '',
      relacion: map['relacion'] ?? 'Familiar',
      activo: map['activo'] ?? true,
      notificaciones: NotificacionesCuidador.fromMap(map['notificaciones'] ?? {}),
      fechaCreacion: map['fecha_creacion'] != null 
          ? (map['fecha_creacion'] as Timestamp).toDate() 
          : DateTime.now(),
      fechaActualizacion: map['fecha_actualizacion'] != null 
          ? (map['fecha_actualizacion'] as Timestamp).toDate() 
          : null,
    );
  }

  factory Cuidador.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Cuidador.fromMap(data, doc.id);
  }

  Cuidador copyWith({
    String? id,
    String? nombre,
    String? email,
    String? telefono,
    String? relacion,
    bool? activo,
    NotificacionesCuidador? notificaciones,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
  }) {
    return Cuidador(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
      relacion: relacion ?? this.relacion,
      activo: activo ?? this.activo,
      notificaciones: notificaciones ?? this.notificaciones,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
    );
  }

  // Método para convertir desde el formato anterior (Map<String, String>)
  factory Cuidador.fromLegacyMap(Map<String, String> map) {
    return Cuidador(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // ID temporal
      nombre: map['nombre'] ?? '',
      email: map['email'] ?? '',
      telefono: map['telefono'] ?? '',
      relacion: map['relacion'] ?? 'Familiar',
      notificaciones: NotificacionesCuidador(),
      fechaCreacion: DateTime.now(),
    );
  }

  // Método para obtener color por relación
  static const Map<String, int> _coloresPorRelacion = {
    'Familiar': 0xFF2196F3, // Blue
    'Hijo/a': 0xFF2196F3,
    'Padre/Madre': 0xFF2196F3,
    'Esposo/a': 0xFF2196F3,
    'Cuidador profesional': 0xFF009688, // Teal
    'Enfermero/a': 0xFF009688,
    'Médico': 0xFF009688,
    'Amigo/a': 0xFF9C27B0, // Purple
  };

  int get colorPorRelacion {
    return _coloresPorRelacion[relacion] ?? 0xFFFF9800; // Orange por defecto
  }

  // Método para validar email
  bool get tieneEmailValido {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  // Método para validar teléfono
  bool get tieneTelefonoValido {
    return telefono.length >= 8;
  }

  // Método para obtener iniciales
  String get iniciales {
    List<String> palabras = nombre.trim().split(' ');
    if (palabras.length >= 2) {
      return '${palabras[0][0]}${palabras[1][0]}'.toUpperCase();
    } else if (palabras.isNotEmpty) {
      return palabras[0][0].toUpperCase();
    }
    return 'C';
  }
}
