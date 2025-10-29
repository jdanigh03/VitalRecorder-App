# Nueva Estructura de Recordatorios - Especificación Completa

## 📋 Resumen

Este documento describe la redefinición completa del sistema de recordatorios de VitalRecorderApp, con soporte para:
- Rangos de fechas (inicio/fin)
- Períodos configurables entre recordatorios
- Horarios diarios personalizables
- Sistema de confirmaciones del paciente

---

## 🏗️ Arquitectura

### 1. Modelos de Datos

#### **ReminderNew** (`lib/models/reminder_new.dart`)
Modelo principal del recordatorio con:
- **Fechas**: `startDate`, `endDate` (rango completo del recordatorio)
- **Tipo**: `medication` o `activity`
- **Intervalo**: `intervalType` (HOURS/DAYS) + `intervalValue` (número)
- **Horarios**: `dailyScheduleTimes` (lista de TimeOfDay personalizable)
- **Validaciones**: No permite fechas pasadas, endDate > startDate

```dart
ReminderNew(
  id: '123',
  title: 'Amoxicilina 500mg',
  type: 'medication',
  startDate: DateTime(2024, 10, 29, 8, 0),  // Hoy a las 8:00
  endDate: DateTime(2024, 11, 5, 8, 0),      // 7 días después
  intervalType: IntervalType.HOURS,
  intervalValue: 8,                          // Cada 8 horas
  dailyScheduleTimes: [                      // Calculado y personalizable
    TimeOfDay(hour: 8, minute: 0),           // 08:00
    TimeOfDay(hour: 16, minute: 0),          // 16:00
    TimeOfDay(hour: 23, minute: 0),          // 23:00 (ajustado de 00:00)
  ],
  ...
)
```

#### **ReminderConfirmation** (`lib/models/reminder_confirmation.dart`)
Confirmaciones individuales por cada recordatorio programado:
- **Estados**: `PENDING`, `CONFIRMED`, `MISSED`
- **Colección separada en Firestore**: `reminder_confirmations`
- Un documento por cada recordatorio programado

```dart
ReminderConfirmation(
  id: 'conf_456',
  reminderId: '123',
  userId: 'patient_789',
  scheduledTime: DateTime(2024, 10, 29, 8, 0),
  status: ConfirmationStatus.CONFIRMED,
  confirmedAt: DateTime(2024, 10, 29, 8, 5),
  notes: 'Tomado con desayuno',
)
```

---

## 🎨 Flujo de Creación de Recordatorio

### Paso 1: Tipo de Recordatorio
- ✅ **Medicamento** o **Actividad** (mantener categorías actuales)
- Cards seleccionables con iconos

### Paso 2: Rango de Fechas

#### A. Fecha de Inicio
- Por defecto: Día actual
- Puede modificarse pero NO permite fechas pasadas
- Incluye selector de hora inicial

#### B. Duración/Fecha Fin
Opciones predefinidas:
- **5 días**
- **1 semana**
- **1 mes**
- **Personalizado** (selector de fecha manual)

```dart
enum DurationPreset {
  FIVE_DAYS,    // startDate + 5 días
  ONE_WEEK,     // startDate + 7 días
  ONE_MONTH,    // startDate + 1 mes
  CUSTOM,       // Usuario selecciona endDate
}
```

### Paso 3: Período entre Recordatorios

#### Opciones Predefinidas:
- **Cada 4 horas** → 6 recordatorios/día
- **Cada 6 horas** → 4 recordatorios/día
- **Cada 8 horas** → 3 recordatorios/día
- **Cada 12 horas** → 2 recordatorios/día
- **Personalizado** → Input manual

#### Tipo de Intervalo:
- **Horas**: Para medicamentos frecuentes (1-23 horas)
- **Días**: Para medicamentos/actividades espaciadas (1-30 días)

### Paso 4: Personalización de Horarios Diarios

Sistema automático + ajuste manual:

1. **Cálculo Automático**: 
   - Basado en hora inicial y período
   - Ejemplo: 08:00 + cada 8h = [08:00, 16:00, 00:00]

2. **Ajuste Manual**:
   - Lista editable de horarios
   - Agregar/eliminar horarios
   - Modificar horas individuales
   - Ejemplo: Cambiar 00:00 → 23:00 si persona duerme temprano

```dart
// Cálculo automático
final times = ReminderScheduleCalculator.calculateDailySchedule(
  startTime: TimeOfDay(hour: 8, minute: 0),
  intervalHours: 8,
);
// Resultado: [08:00, 16:00, 00:00]

// Usuario puede modificar:
// [08:00, 16:00, 23:00] ← Ajustado para dormir antes
```

### Paso 5: Resumen y Confirmación

Vista previa antes de guardar:
```
Recordatorio de Medicamento: Amoxicilina 500mg
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📅 Duración: 7 días (29 Oct - 5 Nov)
⏰ Frecuencia: Cada 8 horas
🔔 Horarios diarios:
   • 08:00 AM
   • 04:00 PM
   • 11:00 PM
📊 Total: 21 recordatorios
```

---

## 💾 Estructura en Firestore

### Colección: `reminders`
```json
{
  "id": "rem_123",
  "title": "Amoxicilina 500mg",
  "description": "Tomar con alimentos",
  "type": "medication",
  "startDate": "2024-10-29T08:00:00Z",
  "endDate": "2024-11-05T08:00:00Z",
  "intervalType": "HOURS",
  "intervalValue": 8,
  "dailyScheduleTimes": [
    {"hour": 8, "minute": 0},
    {"hour": 16, "minute": 0},
    {"hour": 23, "minute": 0}
  ],
  "userId": "patient_789",
  "createdBy": "caregiver_456",
  "isActive": true,
  "createdAt": "2024-10-29T07:30:00Z",
  "updatedAt": null
}
```

### Colección: `reminder_confirmations`
```json
{
  "id": "conf_001",
  "reminderId": "rem_123",
  "userId": "patient_789",
  "scheduledTime": "2024-10-29T08:00:00Z",
  "status": "CONFIRMED",
  "confirmedAt": "2024-10-29T08:05:23Z",
  "notes": "Tomado con desayuno",
  "createdAt": "2024-10-29T00:00:00Z"
}
```

---

## 🔄 Generación de Confirmaciones

Al crear un recordatorio, se generan automáticamente documentos de confirmación:

```dart
// Ejemplo: Recordatorio de 7 días, cada 8 horas (3 veces/día)
// Total confirmaciones: 7 días × 3 = 21 documentos

for (DateTime scheduled in reminder.calculateAllScheduledTimes()) {
  final confirmation = ReminderConfirmation(
    id: generateId(),
    reminderId: reminder.id,
    userId: reminder.userId,
    scheduledTime: scheduled,
    status: ConfirmationStatus.PENDING,
    createdAt: DateTime.now(),
  );
  
  await saveConfirmation(confirmation);
}
```

---

## ✅ Validaciones

### Al Crear/Editar:
1. ❌ **No permitir fechas de inicio en el pasado**
   ```dart
   if (startDate.isBefore(DateTime.now())) {
     throw 'La fecha de inicio no puede estar en el pasado';
   }
   ```

2. ❌ **Fecha fin debe ser posterior a fecha inicio**
   ```dart
   if (endDate.isBefore(startDate)) {
     throw 'La fecha de fin debe ser posterior a la de inicio';
   }
   ```

3. ❌ **Intervalo válido**
   - Horas: 1-23
   - Días: 1-30

4. ❌ **Horarios sin duplicados**
   ```dart
   if (ReminderScheduleCalculator.hasDuplicateTimes(times)) {
     throw 'No puede haber horarios duplicados';
   }
   ```

5. ❌ **Al menos un horario diario**

---

## 📱 Componentes UI (Próxima Implementación)

### 1. **DateRangeSelector** (Widget)
- Botones de presets (5d, 1s, 1m, custom)
- Date pickers para inicio/fin
- Validación en tiempo real

### 2. **IntervalSelector** (Widget)
- Chips para opciones comunes
- Toggle: Horas vs Días
- Input personalizado

### 3. **DailyScheduleEditor** (Widget)
- Lista de horarios editables
- Botón "+" para agregar
- Time pickers inline
- Preview del patrón

### 4. **ReminderSummaryCard** (Widget)
- Resumen visual completo
- Indicador de total de recordatorios
- Confirmación final

---

## 🔄 Migración desde Estructura Anterior

La estructura antigua (`reminder.dart`) se mantiene para compatibilidad:

```dart
// Viejo: Un solo DateTime + frecuencia string
Reminder(
  dateTime: DateTime(2024, 10, 29, 8, 0),
  frequency: 'Cada 8 horas',
)

// Nuevo: Rango + horarios estructurados
ReminderNew(
  startDate: DateTime(2024, 10, 29, 8, 0),
  endDate: DateTime(2024, 11, 5, 8, 0),
  intervalType: IntervalType.HOURS,
  intervalValue: 8,
  dailyScheduleTimes: [...],
)
```

**Plan de Migración**:
- Fase 1: Coexistencia (nueva pantalla, ambos modelos)
- Fase 2: Migración de datos (script automático)
- Fase 3: Deprecación del modelo antiguo

---

## 🎯 Próximos Pasos

### Prioridad Alta:
1. ✅ Modelos creados (`reminder_new.dart`, `reminder_confirmation.dart`)
2. ✅ Helper calculator (`reminder_schedule_calculator.dart`)
3. ⏳ **Actualizar UI de creación** (`cuidador_crear_recordatorio.dart`)
4. ⏳ **Service methods** (CRUD con confirmaciones)

### Prioridad Media:
5. ⏳ Vista de confirmaciones para paciente
6. ⏳ Dashboard con estadísticas de adherencia
7. ⏳ Notificaciones push por horario

### Prioridad Baja:
8. ⏳ Exportar reportes de adherencia
9. ⏳ Gráficas de cumplimiento
10. ⏳ Integración con manilla BLE

---

## 📝 Notas Técnicas

### Performance:
- Índices compuestos en Firestore: `userId + scheduledTime`
- Paginación en listados de confirmaciones
- Cache local de recordatorios activos

### Seguridad:
- Rules de Firestore: Solo paciente puede confirmar sus recordatorios
- Cuidador puede crear/editar pero no confirmar
- Timestamps del servidor para auditoría

### Testing:
- Unit tests: Cálculo de horarios
- Widget tests: Selectores de fecha/hora
- Integration tests: Flujo completo de creación

---

**Última actualización**: 29 Octubre 2024  
**Versión**: 1.0  
**Estado**: 🟡 En desarrollo - Fase 1
