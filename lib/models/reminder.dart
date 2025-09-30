class Reminder {
  final String id;
  final String title;
  final String description;
  final DateTime dateTime;
  final String frequency;
  final bool isCompleted;
  final String type;

  Reminder({
    required this.id,
    required this.title,
    required this.description,
    required this.dateTime,
    required this.frequency,
    this.isCompleted = false,
    this.type = 'medication',
  });

  Reminder copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dateTime,
    String? frequency,
    bool? isCompleted,
    String? type,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      frequency: frequency ?? this.frequency,
      isCompleted: isCompleted ?? this.isCompleted,
      type: type ?? this.type,
    );
  }
}