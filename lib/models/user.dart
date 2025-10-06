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
  final String? familiarEmail;
  final int intensidadVibracion;
  final bool modoSilencio;
  final bool notificarAFamiliar;
  final String telefono;

  UserSettings({
    this.familiarEmail,
    this.intensidadVibracion = 2,
    this.modoSilencio = false,
    this.notificarAFamiliar = false,
    required this.telefono,
  });

  Map<String, dynamic> toMap() {
    return {
      'familiar_email': familiarEmail,
      'intensidad_vibracion': intensidadVibracion,
      'modo_silencio': modoSilencio,
      'notificar_a_familiar': notificarAFamiliar,
      'telefono': telefono,
    };
  }

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      familiarEmail: map['familiar_email'],
      intensidadVibracion: map['intensidad_vibracion'] ?? 2,
      modoSilencio: map['modo_silencio'] ?? false,
      notificarAFamiliar: map['notificar_a_familiar'] ?? false,
      telefono: map['telefono'] ?? '',
    );
  }

  UserSettings copyWith({
    String? familiarEmail,
    int? intensidadVibracion,
    bool? modoSilencio,
    bool? notificarAFamiliar,
    String? telefono,
  }) {
    return UserSettings(
      familiarEmail: familiarEmail ?? this.familiarEmail,
      intensidadVibracion: intensidadVibracion ?? this.intensidadVibracion,
      modoSilencio: modoSilencio ?? this.modoSilencio,
      notificarAFamiliar: notificarAFamiliar ?? this.notificarAFamiliar,
      telefono: telefono ?? this.telefono,
    );
  }
}

class UserModel {
  final String email;
  final UserPersona persona;
  final String role;
  final UserSettings settings;
  final DateTime createdAt;

  UserModel({
    required this.email,
    required this.persona,
    this.role = 'user',
    required this.settings,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'persona': persona.toMap(),
      'role': role,
      'settings': settings.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
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
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap(data);
  }

  UserModel copyWith({
    String? email,
    UserPersona? persona,
    String? role,
    UserSettings? settings,
    DateTime? createdAt,
  }) {
    return UserModel(
      email: email ?? this.email,
      persona: persona ?? this.persona,
      role: role ?? this.role,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get nombreCompleto => '${persona.nombres} ${persona.apellidos}'.trim();
}
