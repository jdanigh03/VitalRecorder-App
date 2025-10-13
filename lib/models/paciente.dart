import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de datos para representar un paciente en el sistema
/// Incluye información personal, médica y relaciones con cuidadores
class Paciente {
  final String id;
  final String nombre;
  final String email;
  final String telefono;
  final List<String> cuidadoresIds;
  final Map<String, dynamic> informacionMedica;
  final DateTime fechaRegistro;
  final String? fotoUrl;
  final bool activo;
  final Map<String, dynamic>? configuracionNotificaciones;

  const Paciente({
    required this.id,
    required this.nombre,
    required this.email,
    required this.telefono,
    this.cuidadoresIds = const [],
    this.informacionMedica = const {},
    required this.fechaRegistro,
    this.fotoUrl,
    this.activo = true,
    this.configuracionNotificaciones,
  });

  /// Factory constructor para crear un Paciente desde un documento de Firestore
  factory Paciente.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Paciente(
      id: doc.id,
      nombre: data['nombre'] ?? '',
      email: data['email'] ?? '',
      telefono: data['telefono'] ?? '',
      cuidadoresIds: List<String>.from(data['cuidadoresIds'] ?? []),
      informacionMedica: Map<String, dynamic>.from(data['informacionMedica'] ?? {}),
      fechaRegistro: (data['fechaRegistro'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fotoUrl: data['fotoUrl'],
      activo: data['activo'] ?? true,
      configuracionNotificaciones: data['configuracionNotificaciones'] != null
          ? Map<String, dynamic>.from(data['configuracionNotificaciones'])
          : null,
    );
  }

  /// Factory constructor para crear un Paciente desde un Map
  factory Paciente.fromMap(Map<String, dynamic> data, String id) {
    return Paciente(
      id: id,
      nombre: data['nombre'] ?? '',
      email: data['email'] ?? '',
      telefono: data['telefono'] ?? '',
      cuidadoresIds: List<String>.from(data['cuidadoresIds'] ?? []),
      informacionMedica: Map<String, dynamic>.from(data['informacionMedica'] ?? {}),
      fechaRegistro: (data['fechaRegistro'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fotoUrl: data['fotoUrl'],
      activo: data['activo'] ?? true,
      configuracionNotificaciones: data['configuracionNotificaciones'] != null
          ? Map<String, dynamic>.from(data['configuracionNotificaciones'])
          : null,
    );
  }

  /// Convierte el Paciente a un Map para guardarlo en Firestore
  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'email': email,
      'telefono': telefono,
      'cuidadoresIds': cuidadoresIds,
      'informacionMedica': informacionMedica,
      'fechaRegistro': Timestamp.fromDate(fechaRegistro),
      'fotoUrl': fotoUrl,
      'activo': activo,
      'configuracionNotificaciones': configuracionNotificaciones,
    };
  }

  /// Crea una copia del Paciente con algunos campos modificados
  Paciente copyWith({
    String? id,
    String? nombre,
    String? email,
    String? telefono,
    List<String>? cuidadoresIds,
    Map<String, dynamic>? informacionMedica,
    DateTime? fechaRegistro,
    String? fotoUrl,
    bool? activo,
    Map<String, dynamic>? configuracionNotificaciones,
  }) {
    return Paciente(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
      cuidadoresIds: cuidadoresIds ?? this.cuidadoresIds,
      informacionMedica: informacionMedica ?? this.informacionMedica,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      activo: activo ?? this.activo,
      configuracionNotificaciones: configuracionNotificaciones ?? this.configuracionNotificaciones,
    );
  }

  /// Verifica si el paciente tiene un cuidador específico
  bool tieneCuidador(String cuidadorId) {
    return cuidadoresIds.contains(cuidadorId);
  }

  /// Obtiene información médica específica por clave
  dynamic getInformacionMedica(String clave) {
    return informacionMedica[clave];
  }

  /// Obtiene las iniciales del paciente para mostrar en avatares
  String get iniciales {
    List<String> nombres = nombre.split(' ');
    if (nombres.length >= 2) {
      return '${nombres[0][0]}${nombres[1][0]}'.toUpperCase();
    } else if (nombres.isNotEmpty) {
      return nombres[0][0].toUpperCase();
    }
    return 'P';
  }

  /// Obtiene el primer nombre del paciente
  String get primerNombre {
    return nombre.split(' ').first;
  }

  @override
  String toString() {
    return 'Paciente(id: $id, nombre: $nombre, email: $email, cuidadores: ${cuidadoresIds.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Paciente && other.id == id;
  }

  @override
  int get hashCode {
    return id.hashCode;
  }
}

/// Información médica común que puede tener un paciente
class InformacionMedicaKeys {
  static const String alergias = 'alergias';
  static const String condicionesMedicas = 'condicionesMedicas';
  static const String medicamentosActuales = 'medicamentosActuales';
  static const String contactoEmergencia = 'contactoEmergencia';
  static const String medicoTratante = 'medicoTratante';
  static const String grupoSanguineo = 'grupoSanguineo';
  static const String peso = 'peso';
  static const String altura = 'altura';
  static const String fechaNacimiento = 'fechaNacimiento';
  static const String notas = 'notas';
}
