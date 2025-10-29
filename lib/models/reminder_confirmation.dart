/// Modelo para almacenar las confirmaciones del paciente
/// Se guarda en una colección separada en Firestore: 'reminder_confirmations'
class ReminderConfirmation {
  final String id;
  final String reminderId; // ID del recordatorio al que pertenece
  final String userId; // ID del paciente
  final DateTime scheduledTime; // Hora programada del recordatorio
  final DateTime? confirmedAt; // Hora en que se confirmó (null si no se confirmó)
  final ConfirmationStatus status; // CONFIRMED, MISSED, PENDING
  final String? notes; // Notas opcionales del paciente
  final DateTime createdAt;

  ReminderConfirmation({
    required this.id,
    required this.reminderId,
    required this.userId,
    required this.scheduledTime,
    this.confirmedAt,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  /// Copia la confirmación con cambios
  ReminderConfirmation copyWith({
    String? id,
    String? reminderId,
    String? userId,
    DateTime? scheduledTime,
    DateTime? confirmedAt,
    ConfirmationStatus? status,
    String? notes,
    DateTime? createdAt,
  }) {
    return ReminderConfirmation(
      id: id ?? this.id,
      reminderId: reminderId ?? this.reminderId,
      userId: userId ?? this.userId,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Convierte la confirmación a un Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reminderId': reminderId,
      'userId': userId,
      'scheduledTime': scheduledTime.toIso8601String(),
      'confirmedAt': confirmedAt?.toIso8601String(),
      'status': status.toString().split('.').last,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Crea una confirmación desde un Map de Firestore
  factory ReminderConfirmation.fromMap(Map<String, dynamic> map) {
    return ReminderConfirmation(
      id: map['id'] ?? '',
      reminderId: map['reminderId'] ?? '',
      userId: map['userId'] ?? '',
      scheduledTime: DateTime.parse(map['scheduledTime']),
      confirmedAt: map['confirmedAt'] != null ? DateTime.parse(map['confirmedAt']) : null,
      status: ConfirmationStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => ConfirmationStatus.PENDING,
      ),
      notes: map['notes'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  /// Marca la confirmación como confirmada
  ReminderConfirmation confirm({String? notes}) {
    return copyWith(
      status: ConfirmationStatus.CONFIRMED,
      confirmedAt: DateTime.now(),
      notes: notes ?? this.notes,
    );
  }

  /// Marca la confirmación como omitida
  ReminderConfirmation markAsMissed() {
    return copyWith(
      status: ConfirmationStatus.MISSED,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReminderConfirmation && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Estados de confirmación
enum ConfirmationStatus {
  PENDING,   // Pendiente de confirmar
  CONFIRMED, // Confirmado por el paciente
  MISSED,    // Omitido/No confirmado
}

extension ConfirmationStatusExtension on ConfirmationStatus {
  String get displayName {
    switch (this) {
      case ConfirmationStatus.PENDING:
        return 'Pendiente';
      case ConfirmationStatus.CONFIRMED:
        return 'Confirmado';
      case ConfirmationStatus.MISSED:
        return 'Omitido';
    }
  }

  /// Color asociado al estado
  String get colorHex {
    switch (this) {
      case ConfirmationStatus.PENDING:
        return '#FFA500'; // Naranja
      case ConfirmationStatus.CONFIRMED:
        return '#4CAF50'; // Verde
      case ConfirmationStatus.MISSED:
        return '#F44336'; // Rojo
    }
  }
}
