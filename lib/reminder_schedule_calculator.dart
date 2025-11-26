import 'package:flutter/material.dart';

/// Utilidad para calcular horarios de recordatorios
class ReminderScheduleCalculator {
  /// Calcula los horarios diarios basado en un intervalo de horas
  /// 
  /// Ejemplo: Si startTime es 08:00 y interval es 8 horas
  /// Resultado: [08:00, 16:00, 00:00]
  static List<TimeOfDay> calculateDailySchedule({
    required TimeOfDay startTime,
    required int intervalHours,
  }) {
    if (intervalHours <= 0 || intervalHours >= 24) {
      throw ArgumentError('El intervalo debe ser entre 1 y 23 horas');
    }

    List<TimeOfDay> schedule = [];
    int currentMinutes = startTime.hour * 60 + startTime.minute;
    const minutesInDay = 24 * 60;

    while (currentMinutes <= minutesInDay) {
      if (currentMinutes == minutesInDay) {
        // Si llegamos exactamente a las 24:00 (fin del día)
        // Verificamos si ya tenemos las 00:00 (inicio del día)
        bool hasMidnight = schedule.any((t) => t.hour == 0 && t.minute == 0);
        
        // Si no empezamos a las 00:00, agregamos 23:59 para cerrar el día
        // Esto cubre el caso de empezar a las 08:00 con intervalo de 8h:
        // 08:00, 16:00, y agregamos 23:59 (en lugar de perder la de las 24:00)
        if (!hasMidnight) {
          schedule.add(TimeOfDay(hour: 23, minute: 59));
        }
        break;
      }

      int hour = (currentMinutes ~/ 60) % 24;
      int minute = currentMinutes % 60;
      schedule.add(TimeOfDay(hour: hour, minute: minute));
      currentMinutes += intervalHours * 60;
    }

    return schedule;
  }

  /// Calcula el número de recordatorios por día según el intervalo
  static int calculateRemindersPerDay(int intervalHours) {
    if (intervalHours <= 0) return 0;
    return 24 ~/ intervalHours;
  }

  /// Valida que una lista de horarios esté ordenada correctamente
  static bool validateScheduleOrder(List<TimeOfDay> times) {
    if (times.isEmpty) return true;

    for (int i = 0; i < times.length - 1; i++) {
      int current = times[i].hour * 60 + times[i].minute;
      int next = times[i + 1].hour * 60 + times[i + 1].minute;

      if (current >= next) {
        return false;
      }
    }

    return true;
  }

  /// Ordena una lista de horarios
  static List<TimeOfDay> sortSchedule(List<TimeOfDay> times) {
    List<TimeOfDay> sorted = List.from(times);
    sorted.sort((a, b) {
      int aMinutes = a.hour * 60 + a.minute;
      int bMinutes = b.hour * 60 + b.minute;
      return aMinutes.compareTo(bMinutes);
    });
    return sorted;
  }

  /// Formatea un TimeOfDay a String legible
  static String formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Convierte minutos desde medianoche a TimeOfDay
  static TimeOfDay minutesToTimeOfDay(int minutes) {
    int hour = (minutes ~/ 60) % 24;
    int minute = minutes % 60;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Convierte TimeOfDay a minutos desde medianoche
  static int timeOfDayToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  /// Calcula la diferencia en minutos entre dos horarios
  static int getDifferenceInMinutes(TimeOfDay start, TimeOfDay end) {
    int startMinutes = timeOfDayToMinutes(start);
    int endMinutes = timeOfDayToMinutes(end);
    
    if (endMinutes < startMinutes) {
      // El horario cruza medianoche
      endMinutes += 24 * 60;
    }
    
    return endMinutes - startMinutes;
  }

  /// Genera opciones de intervalo comunes (en horas)
  static List<int> getCommonIntervalOptions() {
    return [4, 6, 8, 12];
  }

  /// Obtiene el nombre amigable del intervalo
  static String getIntervalDisplayName(int hours) {
    if (hours == 24) {
      return 'Una vez al día';
    } else if (hours == 12) {
      return 'Cada 12 horas';
    } else if (hours == 8) {
      return 'Cada 8 horas';
    } else if (hours == 6) {
      return 'Cada 6 horas';
    } else if (hours == 4) {
      return 'Cada 4 horas';
    } else {
      return 'Cada $hours horas';
    }
  }

  /// Valida que no haya horarios duplicados
  static bool hasDuplicateTimes(List<TimeOfDay> times) {
    Set<String> seen = {};
    for (final time in times) {
      String key = '${time.hour}:${time.minute}';
      if (seen.contains(key)) {
        return true;
      }
      seen.add(key);
    }
    return false;
  }

  /// Calcula el total de recordatorios reales (filtrando los pasados)
  static int calculateTotalReminders({
    required DateTime startDate,
    required DateTime endDate,
    required List<TimeOfDay> dailyTimes,
  }) {
    int count = 0;
    final now = DateTime.now();
    // Tolerancia de 15 min para coincidir con el backend
    final tolerance = now.subtract(Duration(minutes: 15));
    
    // Normalizar fechas a medianoche
    DateTime current = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    
    while (!current.isAfter(end)) {
      for (final time in dailyTimes) {
        final scheduledTime = DateTime(
          current.year,
          current.month,
          current.day,
          time.hour,
          time.minute,
        );
        
        // Solo contar si es futuro (o dentro de la tolerancia)
        // Y también verificar que esté dentro del rango de fechas original (por si acaso)
        if (scheduledTime.isAfter(tolerance)) {
           // Verificar también que no sea antes del startDate original con hora (si fuera el caso)
           // pero aquí asumimos que startDate/endDate definen los días inclusivos.
           count++;
        }
      }
      current = current.add(Duration(days: 1));
    }
    
    return count;
  }

  /// Genera resumen textual del recordatorio
  static String generateReminderSummary({
    required DateTime startDate,
    required DateTime endDate,
    required List<TimeOfDay> dailyTimes,
    required String type,
  }) {
    final days = endDate.difference(startDate).inDays + 1;
    final totalReminders = days * dailyTimes.length;
    final typeText = type == 'medication' ? 'medicamento' : 'actividad';
    
    return 'Recordatorio de $typeText:\n'
           '• $totalReminders recordatorios en $days días\n'
           '• ${dailyTimes.length} veces al día\n'
           '• Horarios: ${dailyTimes.map((t) => formatTimeOfDay(t)).join(', ')}';
  }
}

/// Extensión para facilitar comparaciones de TimeOfDay
extension TimeOfDayComparison on TimeOfDay {
  bool isBefore(TimeOfDay other) {
    final thisMinutes = hour * 60 + minute;
    final otherMinutes = other.hour * 60 + other.minute;
    return thisMinutes < otherMinutes;
  }

  bool isAfter(TimeOfDay other) {
    final thisMinutes = hour * 60 + minute;
    final otherMinutes = other.hour * 60 + other.minute;
    return thisMinutes > otherMinutes;
  }

  bool isSameTime(TimeOfDay other) {
    return hour == other.hour && minute == other.minute;
  }
}
