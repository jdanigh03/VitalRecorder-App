/// Modelo rediseñado de Recordatorio con soporte para:
/// - Rangos de fechas (inicio/fin)
/// - Intervalos personalizables
/// - Horarios diarios personalizables
/// - Preparado para confirmaciones del paciente
class ReminderNew {
  final String id;
  final String title;
  final String description;
  
  // Tipo: 'medication' o 'activity'
  final String type;
  
  // Rango de fechas
  final DateTime startDate; // No puede ser fecha pasada al crear
  final DateTime endDate;   // Debe ser mayor que startDate
  
  // Intervalo entre recordatorios
  final IntervalType intervalType; // HOURS, DAYS
  final int intervalValue; // Ej: 8 para "cada 8 horas"
  
  // Horarios calculados para un día (personalizables)
  // Ej: Si intervalValue=8 y startDate tiene hora 08:00, 
  // se calculan [08:00, 16:00, 00:00] pero el usuario puede ajustarlos
  final List<TimeOfDay> dailyScheduleTimes;
  
  // Datos de usuario
  final String? userId; // ID del paciente
  final String? createdBy; // ID del cuidador que lo creó
  
  // Estado
  final bool isActive; // Para borrado lógico
  
  // Metadatos
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ReminderNew({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.intervalType,
    required this.intervalValue,
    required this.dailyScheduleTimes,
    this.userId,
    this.createdBy,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  }) {
    // Validaciones
    _validate();
  }

  void _validate() {
    // No permitir fechas de inicio en el pasado
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    
    if (startDay.isBefore(today)) {
      throw ArgumentError('La fecha de inicio no puede ser anterior al día actual');
    }
    
    // Fecha fin debe ser posterior a fecha inicio
    if (endDate.isBefore(startDate)) {
      throw ArgumentError('La fecha de fin debe ser posterior a la fecha de inicio');
    }
    
    // Validar tipo
    if (type != 'medication' && type != 'activity') {
      throw ArgumentError('El tipo debe ser "medication" o "activity"');
    }
    
    // Validar intervalValue
    if (intervalValue <= 0) {
      throw ArgumentError('El intervalo debe ser mayor que 0');
    }
    
    // Validar horarios diarios
    if (dailyScheduleTimes.isEmpty) {
      throw ArgumentError('Debe haber al menos un horario en el día');
    }
  }

  /// Copia el recordatorio con cambios
  ReminderNew copyWith({
    String? id,
    String? title,
    String? description,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    IntervalType? intervalType,
    int? intervalValue,
    List<TimeOfDay>? dailyScheduleTimes,
    String? userId,
    String? createdBy,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReminderNew(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      intervalType: intervalType ?? this.intervalType,
      intervalValue: intervalValue ?? this.intervalValue,
      dailyScheduleTimes: dailyScheduleTimes ?? this.dailyScheduleTimes,
      userId: userId ?? this.userId,
      createdBy: createdBy ?? this.createdBy,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convierte el recordatorio a un Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'intervalType': intervalType.toString().split('.').last,
      'intervalValue': intervalValue,
      'dailyScheduleTimes': dailyScheduleTimes.map((t) => {
        'hour': t.hour,
        'minute': t.minute,
      }).toList(),
      'userId': userId,
      'createdBy': createdBy,
      'isActive': isActive,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  /// Crea un recordatorio desde un Map de Firestore
  factory ReminderNew.fromMap(Map<String, dynamic> map) {
    return ReminderNew(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: map['type'] ?? 'medication',
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      intervalType: IntervalType.values.firstWhere(
        (e) => e.toString().split('.').last == map['intervalType'],
        orElse: () => IntervalType.HOURS,
      ),
      intervalValue: map['intervalValue'] ?? 0,
      dailyScheduleTimes: (map['dailyScheduleTimes'] as List<dynamic>?)
          ?.map((t) => TimeOfDay(hour: t['hour'], minute: t['minute']))
          .toList() ?? [],
      userId: map['userId'],
      createdBy: map['createdBy'],
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
    );
  }

  /// Calcula todos los horarios de recordatorio en el rango de fechas
  List<DateTime> calculateAllScheduledTimes() {
    List<DateTime> scheduledTimes = [];
    
    DateTime currentDate = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    
    final endDay = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    );
    
    // Iterar día por día
    while (currentDate.isBefore(endDay) || currentDate.isAtSameMomentAs(endDay)) {
      // Agregar todos los horarios del día
      for (final time in dailyScheduleTimes) {
        final scheduled = DateTime(
          currentDate.year,
          currentDate.month,
          currentDate.day,
          time.hour,
          time.minute,
        );
        
        // Solo agregar si está dentro del rango (considerando la hora también)
        if ((scheduled.isAfter(startDate) || scheduled.isAtSameMomentAs(startDate)) &&
            (scheduled.isBefore(endDate) || scheduled.isAtSameMomentAs(endDate))) {
          scheduledTimes.add(scheduled);
        }
      }
      
      currentDate = currentDate.add(Duration(days: 1));
    }
    
    return scheduledTimes;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReminderNew && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Enumeración para tipos de intervalo
enum IntervalType {
  HOURS,  // Por horas (ej: cada 8 horas)
  DAYS,   // Por días (ej: cada 2 días)
}

/// Extensión para obtener texto amigable del intervalo
extension IntervalTypeExtension on IntervalType {
  String get displayName {
    switch (this) {
      case IntervalType.HOURS:
        return 'Horas';
      case IntervalType.DAYS:
        return 'Días';
    }
  }
}

/// Clase auxiliar para TimeOfDay (Flutter)
/// Si no está importado de material.dart, definir aquí
class TimeOfDay {
  final int hour;
  final int minute;

  const TimeOfDay({required this.hour, required this.minute});

  @override
  String toString() {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimeOfDay && other.hour == hour && other.minute == minute;
  }

  @override
  int get hashCode => hour.hashCode ^ minute.hashCode;
}

/// Opciones predefinidas de duración
enum DurationPreset {
  FIVE_DAYS,
  ONE_WEEK,
  ONE_MONTH,
  CUSTOM,
}

extension DurationPresetExtension on DurationPreset {
  String get displayName {
    switch (this) {
      case DurationPreset.FIVE_DAYS:
        return '5 días';
      case DurationPreset.ONE_WEEK:
        return '1 semana';
      case DurationPreset.ONE_MONTH:
        return '1 mes';
      case DurationPreset.CUSTOM:
        return 'Personalizado';
    }
  }

  /// Calcula la fecha de fin basado en la fecha de inicio y el preset
  DateTime calculateEndDate(DateTime startDate) {
    switch (this) {
      case DurationPreset.FIVE_DAYS:
        return startDate.add(Duration(days: 5));
      case DurationPreset.ONE_WEEK:
        return startDate.add(Duration(days: 7));
      case DurationPreset.ONE_MONTH:
        return DateTime(
          startDate.year,
          startDate.month + 1,
          startDate.day,
        );
      case DurationPreset.CUSTOM:
        return startDate; // El usuario debe establecerlo
    }
  }
}
