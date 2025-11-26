import 'package:cloud_firestore/cloud_firestore.dart';

class UserPersona {
  final String nombres;
  final String apellidos;
  final DateTime? fechaNac;
  final String? sexo;

  UserPersona({
    required this.nombres,
    required this.apellidos,
    this.fechaNac,
    this.sexo,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombres': nombres,
      'apellidos': apellidos,
      'fecha_nac': fechaNac != null ? Timestamp.fromDate(fechaNac!) : null,
      'sexo': sexo,
    };
  }

  factory UserPersona.fromMap(Map<String, dynamic> map) {
    return UserPersona(
      nombres: map['nombres'] ?? '',
      apellidos: map['apellidos'] ?? '',
      fechaNac: map['fecha_nac'] != null 
          ? (map['fecha_nac'] as Timestamp).toDate() 
          : null,
      sexo: map['sexo'],
    );
  }

  UserPersona copyWith({
    String? nombres,
    String? apellidos,
    DateTime? fechaNac,
    String? sexo,
  }) {
    return UserPersona(
      nombres: nombres ?? this.nombres,
      apellidos: apellidos ?? this.apellidos,
      fechaNac: fechaNac ?? this.fechaNac,
      sexo: sexo ?? this.sexo,
    );
  }
}

class UserSettings {
  final List<String> familiarEmails;
  final int intensidadVibracion;
  final bool modoSilencio;
  final bool notificarAFamiliar;
  final String telefono;

  UserSettings({
    this.familiarEmails = const [],
    this.intensidadVibracion = 2,
    this.modoSilencio = false,
    this.notificarAFamiliar = false,
    required this.telefono,
  });

  Map<String, dynamic> toMap() {
    return {
      'familiar_emails': familiarEmails,
      'intensidad_vibracion': intensidadVibracion,
      'modo_silencio': modoSilencio,
      'notificar_a_familiar': notificarAFamiliar,
      'telefono': telefono,
    };
  }

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      familiarEmails: List<String>.from(map['familiar_emails'] ?? []),
      intensidadVibracion: map['intensidad_vibracion'] ?? 2,
      modoSilencio: map['modo_silencio'] ?? false,
      notificarAFamiliar: map['notificar_a_familiar'] ?? false,
      telefono: map['telefono'] ?? '',
    );
  }

  UserSettings copyWith({
    List<String>? familiarEmails,
    int? intensidadVibracion,
    bool? modoSilencio,
    bool? notificarAFamiliar,
    String? telefono,
  }) {
    return UserSettings(
      familiarEmails: familiarEmails ?? this.familiarEmails,
      intensidadVibracion: intensidadVibracion ?? this.intensidadVibracion,
      modoSilencio: modoSilencio ?? this.modoSilencio,
      notificarAFamiliar: notificarAFamiliar ?? this.notificarAFamiliar,
      telefono: telefono ?? this.telefono,
    );
  }
}

class UserModel {
  final String? id; // ID del documento de Firestore
  final String email;
  final UserPersona persona;
  final String role;
  final UserSettings settings;
  final DateTime createdAt;
  // Campos para relaciones cuidador-paciente
  final List<String> pacientesIds; // IDs de pacientes (para cuidadores)
  final List<String> cuidadoresIds; // IDs de cuidadores (para pacientes)
  final String? pacienteId; // ID del perfil de paciente (si el usuario es paciente)
  final DateTime? lastNotificationReadDate; // Fecha de última lectura de notificaciones

  UserModel({
    this.id,
    required this.email,
    required this.persona,
    this.role = 'user',
    required this.settings,
    required this.createdAt,
    this.pacientesIds = const [],
    this.cuidadoresIds = const [],
    this.pacienteId,
    this.lastNotificationReadDate,
  });

  // Getter para mantener compatibilidad con código que usa userId
  String? get userId => id;

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'persona': persona.toMap(),
      'role': role,
      'settings': settings.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'pacientesIds': pacientesIds,
      'cuidadoresIds': cuidadoresIds,
      'pacienteId': pacienteId,
      'lastNotificationReadDate': lastNotificationReadDate != null 
          ? Timestamp.fromDate(lastNotificationReadDate!) 
          : null,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      email: map['email'] ?? '',
      persona: UserPersona.fromMap(map['persona'] ?? {}),
      role: map['role'] ?? 'user',
      settings: UserSettings.fromMap(map['settings'] ?? {}),
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      pacientesIds: List<String>.from(map['pacientesIds'] ?? []),
      cuidadoresIds: List<String>.from(map['cuidadoresIds'] ?? []),
      pacienteId: map['pacienteId'],
      lastNotificationReadDate: map['lastNotificationReadDate'] != null 
          ? (map['lastNotificationReadDate'] as Timestamp).toDate() 
          : null,
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id, // Asignar el ID del documento
      email: data['email'] ?? '',
      persona: UserPersona.fromMap(data['persona'] ?? {}),
      role: data['role'] ?? 'user',
      settings: UserSettings.fromMap(data['settings'] ?? {}),
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      pacientesIds: List<String>.from(data['pacientesIds'] ?? []),
      cuidadoresIds: List<String>.from(data['cuidadoresIds'] ?? []),
      pacienteId: data['pacienteId'],
      lastNotificationReadDate: data['lastNotificationReadDate'] != null 
          ? (data['lastNotificationReadDate'] as Timestamp).toDate() 
          : null,
    );
  }

  UserModel copyWith({
    String? id,
    String? email,
    UserPersona? persona,
    String? role,
    UserSettings? settings,
    DateTime? createdAt,
    List<String>? pacientesIds,
    List<String>? cuidadoresIds,
    String? pacienteId,
    DateTime? lastNotificationReadDate,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      persona: persona ?? this.persona,
      role: role ?? this.role,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
      pacientesIds: pacientesIds ?? this.pacientesIds,
      cuidadoresIds: cuidadoresIds ?? this.cuidadoresIds,
      pacienteId: pacienteId ?? this.pacienteId,
      lastNotificationReadDate: lastNotificationReadDate ?? this.lastNotificationReadDate,
    );
  }

  String get nombreCompleto => '${persona.nombres} ${persona.apellidos}'.trim();
}
