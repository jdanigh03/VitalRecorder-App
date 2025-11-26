import 'package:flutter/material.dart';

/// Modelo rediseñado de Recordatorio con soporte para:
/// - Rangos de fechas (inicio/fin)
/// - Intervalos personalizables
/// - Horarios diarios personalizables
/// - Preparado para confirmaciones del paciente
class ReminderNew {
  final String id;
  final String title;
  final String description;
  
  // Checklist de requerimientos (opcional)
  final List<String>? checklist;
  
  // Tipo: 'medication' o 'activity'
  final String type;
  
  // Rango de fechas
  final DateTime startDate; // No puede ser fecha pasada al crear
  final DateTime endDate;   // Debe ser mayor que startDate
  
  // Intervalo entre recordatorios
  final IntervalType intervalType; // HOURS, DAYS, SPECIFIC_DAYS
  final int intervalValue; // Ej: 8 para "cada 8 horas"
  
  // Días específicos (solo si intervalType == SPECIFIC_DAYS)
  // Lista de días de la semana: 1=Lunes, 2=Martes, ... 7=Domingo
  final List<int>? specificDays;
  
  // Horarios calculados para un día (personalizables)
  // Ej: Si intervalValue=8 y startDate tiene hora 08:00, 
  // se calculan [08:00, 16:00, 00:00] pero el usuario puede ajustarlos
  final List<TimeOfDay> dailyScheduleTimes;
  
  // Datos de usuario
  final String? userId; // ID del paciente
  final String? createdBy; // ID del cuidador que lo creó
  
  // Estado
  final bool isActive; // Para borrado lógico
  final bool isPaused; // Para pausar la planificación
  
  // Metadatos
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ReminderNew({
    required this.id,
    required this.title,
    required this.description,
    this.checklist,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.intervalType,
    required this.intervalValue,
    required this.dailyScheduleTimes,
    this.specificDays,
    this.userId,
    this.createdBy,
    this.isActive = true,
    this.isPaused = false,
    this.createdAt,
    this.updatedAt,
    bool skipDateValidation = false,
  }) {
    // Validaciones
    _validate(skipDateValidation: skipDateValidation);
  }

  void _validate({bool skipDateValidation = false}) {
    // No permitir fechas de inicio en el pasado (solo al crear nuevos)
    if (!skipDateValidation) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final startDay = DateTime(startDate.year, startDate.month, startDate.day);
      
      if (startDay.isBefore(today)) {
        throw ArgumentError('La fecha de inicio no puede ser anterior al día actual');
      }
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
    List<String>? checklist,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    IntervalType? intervalType,
    int? intervalValue,
    List<TimeOfDay>? dailyScheduleTimes,
    List<int>? specificDays,
    String? userId,
    String? createdBy,
    bool? isActive,
    bool? isPaused,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool skipDateValidation = false,
  }) {
    return ReminderNew(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      checklist: checklist ?? this.checklist,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      intervalType: intervalType ?? this.intervalType,
      intervalValue: intervalValue ?? this.intervalValue,
      dailyScheduleTimes: dailyScheduleTimes ?? this.dailyScheduleTimes,
      specificDays: specificDays ?? this.specificDays,
      userId: userId ?? this.userId,
      createdBy: createdBy ?? this.createdBy,
      isActive: isActive ?? this.isActive,
      isPaused: isPaused ?? this.isPaused,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      skipDateValidation: skipDateValidation,
    );
  }

  /// Convierte el recordatorio a un Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      if (checklist != null) 'checklist': checklist,
      'type': type,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'intervalType': intervalType.toString().split('.').last,
      'intervalValue': intervalValue,
      'dailyScheduleTimes': dailyScheduleTimes.map((t) => {
        'hour': t.hour,
        'minute': t.minute,
      }).toList(),
      if (specificDays != null) 'specificDays': specificDays,
      'userId': userId,
      'createdBy': createdBy,
      'isActive': isActive,
      'isPaused': isPaused,
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
      checklist: map['checklist'] != null ? List<String>.from(map['checklist']) : null,
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
      specificDays: map['specificDays'] != null ? List<int>.from(map['specificDays']) : null,
      userId: map['userId'],
      createdBy: map['createdBy'],
      isActive: map['isActive'] ?? true,
      isPaused: map['isPaused'] ?? false,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
      skipDateValidation: true, // Permitir fechas pasadas al leer de DB
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
    
    final startDay = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    
    // Iterar día por día
    while (currentDate.isBefore(endDay) || currentDate.isAtSameMomentAs(endDay)) {
      bool shouldAddThisDay = true;
      
      if (intervalType == IntervalType.SPECIFIC_DAYS && specificDays != null) {
        // weekday: 1=Monday, 2=Tuesday, ... 7=Sunday
        final currentWeekday = currentDate.weekday;
        shouldAddThisDay = specificDays!.contains(currentWeekday);
      } else if (intervalType == IntervalType.DAYS) {
        // Verificar intervalo de días
        final diffDays = currentDate.difference(startDay).inDays;
        shouldAddThisDay = (diffDays % intervalValue) == 0;
      }
      
      if (shouldAddThisDay) {
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
      }
      
      currentDate = currentDate.add(Duration(days: 1));
    }
    
    return scheduledTimes;
  }

  /// Calcula todas las ocurrencias para un día específico (Optimizado)
  List<DateTime> calculateOccurrencesForDay(DateTime day) {
    // 1. Validar rango de fechas
    final dayStart = DateTime(day.year, day.month, day.day);
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);
    
    if (dayStart.isBefore(startDay) || dayStart.isAfter(endDay)) {
      return [];
    }

    // 2. Verificar reglas de intervalo
    bool shouldAddThisDay = true;
    if (intervalType == IntervalType.SPECIFIC_DAYS && specificDays != null) {
      shouldAddThisDay = specificDays!.contains(dayStart.weekday);
    } else if (intervalType == IntervalType.DAYS) {
       // Días transcurridos desde el inicio
       final diffDays = dayStart.difference(startDay).inDays;
       shouldAddThisDay = (diffDays % intervalValue) == 0;
    }
    
    if (!shouldAddThisDay) return [];

    // 3. Generar horarios
    List<DateTime> occurrences = [];
    for (final time in dailyScheduleTimes) {
      final scheduled = DateTime(
        dayStart.year,
        dayStart.month,
        dayStart.day,
        time.hour,
        time.minute,
      );
      
      // Validar que el horario específico esté dentro del rango exacto
      if ((scheduled.isAfter(startDate) || scheduled.isAtSameMomentAs(startDate)) &&
          (scheduled.isBefore(endDate) || scheduled.isAtSameMomentAs(endDate))) {
        occurrences.add(scheduled);
      }
    }
    
    return occurrences;
  }

  /// Obtiene la próxima ocurrencia desde ahora
  DateTime? getNextOccurrence() {
    final now = DateTime.now();
    final allTimes = calculateAllScheduledTimes();
    
    try {
      return allTimes.firstWhere((dt) => dt.isAfter(now));
    } catch (e) {
      return null; // No hay próximas ocurrencias
    }
  }

  /// Obtiene la próxima ocurrencia desde una fecha específica
  DateTime? getNextOccurrenceFrom(DateTime from) {
    final allTimes = calculateAllScheduledTimes();
    
    try {
      return allTimes.firstWhere((dt) => dt.isAfter(from));
    } catch (e) {
      return null;
    }
  }

  /// Verifica si tiene ocurrencias en un día específico
  bool hasOccurrencesOn(DateTime day) {
    return calculateOccurrencesForDay(day).isNotEmpty;
  }

  /// Alias para compatibilidad - verifica si tiene ocurrencias en un día
  bool hasOccurrencesOnDay(DateTime day) {
    return hasOccurrencesOn(day);
  }

  /// Obtiene ocurrencias en un rango de fechas
  List<DateTime> getOccurrencesInRange(DateTime start, DateTime end) {
    return calculateAllScheduledTimes()
        .where((dt) => !dt.isBefore(start) && !dt.isAfter(end))
        .toList();
  }

  /// Obtiene ocurrencias pendientes (futuras) desde ahora
  List<DateTime> getPendingOccurrences() {
    final now = DateTime.now();
    return calculateAllScheduledTimes()
        .where((dt) => dt.isAfter(now))
        .toList();
  }

  /// Obtiene ocurrencias pasadas desde ahora
  List<DateTime> getPastOccurrences() {
    final now = DateTime.now();
    return calculateAllScheduledTimes()
        .where((dt) => dt.isBefore(now))
        .toList();
  }

  /// Calcula el total de ocurrencias en el rango completo
  int get totalOccurrences {
    return calculateAllScheduledTimes().length;
  }

  /// Texto legible del intervalo
  String get intervalDisplayText {
    if (intervalType == IntervalType.HOURS) {
      return 'Cada $intervalValue ${intervalValue == 1 ? 'hora' : 'horas'}';
    } else if (intervalType == IntervalType.DAYS) {
      return 'Cada $intervalValue ${intervalValue == 1 ? 'día' : 'días'}';
    } else if (intervalType == IntervalType.SPECIFIC_DAYS) {
      if (specificDays == null || specificDays!.isEmpty) {
        return 'Días específicos';
      }
      final dayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      final selectedDayNames = specificDays!.map((d) => dayNames[d - 1]).join(', ');
      return 'Los $selectedDayNames';
    }
    return 'Intervalo no definido';
  }

  /// Duración total en días
  int get durationInDays {
    return endDate.difference(startDate).inDays + 1;
  }

  /// Texto legible del rango de fechas
  String get dateRangeText {
    final startStr = '${startDate.day}/${startDate.month}/${startDate.year}';
    final endStr = '${endDate.day}/${endDate.month}/${endDate.year}';
    return '$startStr - $endStr';
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
  SPECIFIC_DAYS,  // Días específicos de la semana
}

/// Extensión para obtener texto amigable del intervalo
extension IntervalTypeExtension on IntervalType {
  String get displayName {
    switch (this) {
      case IntervalType.HOURS:
        return 'Horas';
      case IntervalType.DAYS:
        return 'Días';
      case IntervalType.SPECIFIC_DAYS:
        return 'Días en específico';
    }
  }
}


/// Opciones predefinidas de duración
enum DurationPreset {
  FIVE_DAYS,
  ONE_WEEK,
  ONE_MONTH,
  ONE_YEAR,
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
      case DurationPreset.ONE_YEAR:
        return '1 año';
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
      case DurationPreset.ONE_YEAR:
        return DateTime(
          startDate.year + 1,
          startDate.month,
          startDate.day,
        );
      case DurationPreset.CUSTOM:
        return startDate; // El usuario debe establecerlo
    }
  }
}
