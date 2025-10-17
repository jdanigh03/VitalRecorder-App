class Reminder {
  final String id;
  final String title;
  final String description;
  final DateTime dateTime;
  final String frequency;
  final bool isCompleted;
  final String type;
  final String? userId; // ID del usuario/paciente al que pertenece
  final bool isActive; // Para borrado lógico

  Reminder({
    required this.id,
    required this.title,
    required this.description,
    required this.dateTime,
    required this.frequency,
    this.isCompleted = false,
    this.type = 'medication',
    this.userId,
    this.isActive = true, // Por defecto, los recordatorios están activos
  });

  Reminder copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dateTime,
    String? frequency,
    bool? isCompleted,
    String? type,
    String? userId,
    bool? isActive,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      frequency: frequency ?? this.frequency,
      isCompleted: isCompleted ?? this.isCompleted,
      type: type ?? this.type,
      userId: userId ?? this.userId,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dateTime': dateTime.toIso8601String(),
      'frequency': frequency,
      'isCompleted': isCompleted,
      'type': type,
      'userId': userId,
      'isActive': isActive,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      dateTime: DateTime.parse(map['dateTime']),
      frequency: map['frequency'] ?? 'Una vez',
      isCompleted: map['isCompleted'] ?? false,
      type: map['type'] ?? 'medication',
      userId: map['userId'],
      isActive: map['isActive'] ?? true,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Reminder && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}