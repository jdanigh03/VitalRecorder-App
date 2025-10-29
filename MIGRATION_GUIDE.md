# 📋 Guía de Migración - Sistema de Recordatorios v2.0

## 🎯 Objetivo
Migrar de `Reminder` (antiguo) a `ReminderNew` (nuevo) con sistema de confirmaciones individuales.

---

## 📦 CAMBIOS PRINCIPALES

### Modelo Antiguo → Modelo Nuevo

| Antiguo | Nuevo | Cambio |
|---------|-------|--------|
| `Reminder` | `ReminderNew` | Clase principal |
| `reminder.dateTime` | `reminder.startDate` / `reminder.endDate` | Rango de fechas |
| `reminder.frequency` | `reminder.intervalType` + `reminder.intervalValue` | Intervalos precisos |
| Una fecha/hora | `reminder.dailyScheduleTimes` | Múltiples horarios/día |
| `reminder.isCompleted` | `ReminderConfirmation.status` | Confirmaciones individuales |
| `ReminderService` | `ReminderServiceNew` | Servicio actualizado |
| `CalendarService` | ❌ Integrado en `ReminderServiceNew` | Ya no se usa |

---

## 🔧 CAMBIOS DE CÓDIGO COMUNES

### 1. Imports
```dart
// ❌ ANTES
import '../models/reminder.dart';
import '../services/reminder_service.dart';
import '../services/calendar_service.dart';

// ✅ DESPUÉS
import '../models/reminder_new.dart';
import '../models/reminder_confirmation.dart';
import '../reminder_service_new.dart';
```

### 2. Servicios
```dart
// ❌ ANTES
final ReminderService _reminderService = ReminderService();
final CalendarService _calendarService = CalendarService();

// ✅ DESPUÉS
final ReminderServiceNew _reminderService = ReminderServiceNew();
```

### 3. Obtener Recordatorios
```dart
// ❌ ANTES
final reminders = await _reminderService.getAllReminders();
for (final reminder in reminders) {
  print('${reminder.title} a las ${reminder.dateTime}');
}

// ✅ DESPUÉS
final reminders = await _reminderService.getAllReminders();
for (final reminder in reminders) {
  print('${reminder.title}: ${reminder.dateRangeText}');
  print('Horarios: ${reminder.intervalDisplayText}');
  for (final time in reminder.dailyScheduleTimes) {
    print('  - ${time.hour}:${time.minute}');
  }
}
```

### 4. Filtrar por Día
```dart
// ❌ ANTES
final today = DateTime.now();
final todayReminders = reminders.where((r) {
  final rDate = DateTime(r.dateTime.year, r.dateTime.month, r.dateTime.day);
  return rDate.isAtSameMomentAs(today);
}).toList();

// ✅ DESPUÉS
final today = DateTime.now();
final todayReminders = reminders.where((r) {
  return r.hasOccurrencesOnDay(today);
}).toList();
```

### 5. Próxima Ocurrencia
```dart
// ❌ ANTES
// No existía este concepto

// ✅ DESPUÉS
final nextOccurrence = reminder.getNextOccurrence();
if (nextOccurrence != null) {
  print('Próxima vez: $nextOccurrence');
}
```

### 6. Marcar como Completado
```dart
// ❌ ANTES
await _reminderService.markAsCompleted(reminderId, true);
await _calendarService.markReminderCompleted(reminderId, date);

// ✅ DESPUÉS
await _reminderService.confirmReminder(
  reminderId: reminder.id,
  scheduledTime: scheduledDateTime,
  confirmedAt: DateTime.now(),
  notes: 'Nota opcional',
);
```

### 7. Obtener Estadísticas
```dart
// ❌ ANTES
// No existía

// ✅ DESPUÉS
final stats = await _reminderService.getReminderStats(reminderId);
print('Total: ${stats['total']}');
print('Confirmados: ${stats['confirmed']}');
print('Omitidos: ${stats['missed']}');
print('Adherencia: ${stats['adherenceRate']}%');
```

### 8. Obtener Confirmaciones
```dart
// ❌ ANTES
// No existía

// ✅ DESPUÉS
final confirmations = await _reminderService.getConfirmations(reminderId);
for (final conf in confirmations) {
  print('${conf.scheduledTime}: ${conf.status.displayName}');
  if (conf.notes != null) print('  Nota: ${conf.notes}');
}
```

### 9. Crear Recordatorio
```dart
// ❌ ANTES
final reminder = Reminder(
  id: '',
  title: 'Ibuprofeno',
  description: '400mg',
  dateTime: DateTime.now(),
  frequency: 'daily',
  type: 'medication',
);
await _reminderService.addReminder(reminder);

// ✅ DESPUÉS
final reminder = ReminderNew(
  id: '',
  title: 'Ibuprofeno',
  description: '400mg',
  type: 'medication',
  startDate: DateTime.now(),
  endDate: DateTime.now().add(Duration(days: 7)),
  intervalType: IntervalType.HOURS,
  intervalValue: 8,
  dailyScheduleTimes: [
    TimeOfDay(hour: 8, minute: 0),
    TimeOfDay(hour: 16, minute: 0),
    TimeOfDay(hour: 0, minute: 0),
  ],
);
await _reminderService.createReminderWithConfirmations(reminder);
```

---

## 📱 ACTUALIZACIÓN POR ARCHIVO

### 🔴 CRÍTICOS (Servicios)

#### `bracelet_service.dart`
```dart
// Cambiar sincronización
Future<void> syncRemindersToBracelet() async {
  final reminders = await _reminderService.getAllReminders();
  final today = DateTime.now();
  
  // Obtener todas las ocurrencias del día
  List<Map<String, dynamic>> todayOccurrences = [];
  
  for (final reminder in reminders) {
    if (reminder.hasOccurrencesOnDay(today)) {
      for (final time in reminder.dailyScheduleTimes) {
        todayOccurrences.add({
          'hour': time.hour,
          'minute': time.minute,
          'title': reminder.title,
          'reminderId': reminder.id,
        });
      }
    }
  }
  
  // Enviar a manilla...
  for (final occ in todayOccurrences) {
    await sendCommand(BraceletCommand.addReminder(
      occ['hour'], occ['minute'], occ['title']
    ));
  }
}
```

#### `cuidador_service.dart`
```dart
// Cambiar método de obtención
Future<List<ReminderNew>> getAllRemindersFromPatients() async {
  final pacientes = await getPacientes();
  List<ReminderNew> allReminders = [];
  
  for (final paciente in pacientes) {
    final reminders = await _reminderService.getRemindersByPatient(
      paciente.userId
    );
    allReminders.addAll(reminders);
  }
  
  return allReminders;
}

Future<List<ReminderNew>> getTodayRemindersFromAllPatients() async {
  final reminders = await getAllRemindersFromPatients();
  final today = DateTime.now();
  
  return reminders.where((r) => r.hasOccurrencesOnDay(today)).toList();
}
```

### 🟡 MEDIOS (Pantallas)

#### `notificaciones.dart`
- Cambiar imports
- Actualizar tipo de variables de `Reminder` a `ReminderNew`
- Usar `hasOccurrencesOnDay()` para filtrar

#### Pantallas de cuidador
- `cuidador_pacientes_recordatorios.dart` → Reescribir
- `cuidador_recordatorios_screen.dart` → Reescribir
- `cuidador_recordatorios_paciente_detalle.dart` → Usar `DetalleRecordatorioNewScreen`
- `cuidador_reminder_detail_screen.dart` → Usar `DetalleRecordatorioNewScreen`

### 🟢 MENORES (Widgets/Utils)

#### `export_utils.dart`
```dart
// Actualizar exportación CSV/PDF
String exportToCSV(List<ReminderNew> reminders) {
  final buffer = StringBuffer();
  buffer.writeln('Título,Tipo,Inicio,Fin,Intervalo');
  
  for (final r in reminders) {
    buffer.writeln('${r.title},${r.type},${r.dateRangeText},${r.intervalDisplayText}');
  }
  
  return buffer.toString();
}
```

#### `widgets/global_reminder_indicator.dart`
```dart
// Mostrar próximo recordatorio
Widget build(BuildContext context) {
  return StreamBuilder<List<ReminderNew>>(
    stream: _reminderService.getRemindersStream(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return SizedBox.shrink();
      
      final reminders = snapshot.data!;
      final nextReminder = reminders.firstWhere(
        (r) => r.getNextOccurrence() != null,
        orElse: () => null,
      );
      
      if (nextReminder == null) return SizedBox.shrink();
      
      final nextTime = nextReminder.getNextOccurrence();
      return _buildIndicator(nextReminder.title, nextTime);
    },
  );
}
```

---

## ✅ CHECKLIST DE MIGRACIÓN

### Fase 1: Preparación
- [ ] Backup del proyecto
- [ ] Revisar esta guía completa
- [ ] Identificar todos los archivos a actualizar

### Fase 2: Limpieza
- [ ] Eliminar `lib/models/reminder.dart`
- [ ] Eliminar `lib/services/reminder_service.dart`
- [ ] Eliminar `lib/services/calendar_service.dart`
- [ ] Eliminar pantallas antiguas (detalle, agregar, crear)
- [ ] Eliminar backups (dashboard_old, dashboard_backup)

### Fase 3: Servicios Core
- [ ] Actualizar `bracelet_service.dart`
- [ ] Actualizar `cuidador_service.dart`
- [ ] Actualizar `analytics_service.dart`
- [ ] Actualizar `reports_cache.dart`

### Fase 4: Pantallas
- [ ] Actualizar `notificaciones.dart`
- [ ] Actualizar/Reescribir pantallas de cuidador (5 pantallas)
- [ ] Actualizar `export_utils.dart`

### Fase 5: Widgets
- [ ] Actualizar `global_reminder_indicator.dart`
- [ ] Actualizar `dashboard_widgets.dart`
- [ ] Actualizar `bracelet_status_widget.dart`

### Fase 6: Testing
- [ ] `flutter clean && flutter pub get`
- [ ] `flutter analyze` (sin errores)
- [ ] Probar creación de recordatorios
- [ ] Probar confirmaciones
- [ ] Probar vista de adherencia
- [ ] Probar sincronización con manilla

---

## 🆘 PROBLEMAS COMUNES

### Error: "The getter 'dateTime' isn't defined"
```dart
// Usar startDate/endDate en lugar de dateTime
final date = reminder.startDate; // no reminder.dateTime
```

### Error: "The getter 'frequency' isn't defined"
```dart
// Usar intervalDisplayText
final freq = reminder.intervalDisplayText; // no reminder.frequency
```

### Error: "The getter 'isCompleted' isn't defined"
```dart
// Los recordatorios ya no tienen isCompleted
// Obtener confirmaciones en su lugar
final confirmations = await _reminderService.getConfirmations(reminder.id);
```

### Error: "CalendarService isn't defined"
```dart
// CalendarService fue eliminado
// Usar ReminderServiceNew para todo
```

---

## 📞 REFERENCIA RÁPIDA DE MÉTODOS

### ReminderServiceNew
```dart
// Obtener recordatorios
getAllReminders() → Future<List<ReminderNew>>
getRemindersByPatient(userId) → Future<List<ReminderNew>>

// CRUD
createReminderWithConfirmations(reminder) → Future<bool>
updateReminder(reminder) → Future<bool>
deactivateReminder(reminderId) → Future<bool>

// Confirmaciones
confirmReminder({reminderId, scheduledTime, confirmedAt, notes}) → Future<bool>
getConfirmations(reminderId) → Future<List<ReminderConfirmation>>
getPendingConfirmations(userId, date) → Future<List<PendingConfirmation>>

// Estadísticas
getReminderStats(reminderId) → Future<Map<String, dynamic>>
```

### ReminderNew (métodos helper)
```dart
hasOccurrencesOnDay(date) → bool
getNextOccurrence() → DateTime?
calculateOccurrencesForDay(date) → List<DateTime>
get intervalDisplayText → String
get dateRangeText → String
```

---

## 🎓 RECURSOS

- **Modelos nuevos**: `lib/models/reminder_new.dart`, `lib/models/reminder_confirmation.dart`
- **Servicio nuevo**: `lib/reminder_service_new.dart`
- **Pantallas ejemplo**: `lib/screens/*_new.dart`
- **Calculadora**: `lib/reminder_schedule_calculator.dart`

---

**Última actualización**: 2025-10-29
**Versión del sistema**: 2.0
