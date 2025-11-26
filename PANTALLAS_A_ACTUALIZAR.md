# Análisis de Pantallas que Usan Recordatorios

## 📊 Resumen Ejecutivo

**Total de pantallas identificadas: 15**
- **Críticas (uso intensivo)**: 8 pantallas
- **Secundarias (uso moderado)**: 5 pantallas  
- **Menor impacto**: 2 pantallas

---

## 🔴 **PANTALLAS CRÍTICAS** (Actualización Obligatoria)

### 1. **`welcome.dart`** - Dashboard Principal del Paciente
**Líneas relevantes**: 6, 9, 41, 48, 110, 127-200

**Uso actual**:
- Muestra recordatorios de HOY con lógica compleja
- Filtra por completados/pendientes usando `CalendarService`
- Calcula "minutos hasta" para notificaciones
- Usa `reminder.dateTime` (single) y `reminder.frequency`

**Impacto de cambio**:
- ❌ **ROMPE**: Lógica de filtrado por día/hora
- ❌ **ROMPE**: Cálculo de recordatorios pendientes
- ❌ **ROMPE**: Sistema de completaciones diarias

**Acción requerida**:
```dart
// ANTES:
final reminderDate = DateTime(reminder.dateTime.year, ...)
final minutesUntil = reminder.dateTime.difference(now).inMinutes;

// DESPUÉS:
// Necesita calcular la próxima ocurrencia del recordatorio HOY
final todayOccurrences = reminder.calculateOccurrencesForDay(today);
final nextOccurrence = todayOccurrences.firstWhere((dt) => dt.isAfter(now));
```

---

### 2. **`calendario.dart`** - Vista de Calendario
**Líneas relevantes**: 4, 5, 20, 90-148

**Uso actual**:
- Función `_getRemindersForDay(DateTime day)` con lógica de frecuencia
- Switch case manual para 'diario', 'semanal', 'mensual', 'cada 8 horas'
- Compara `reminder.dateTime` con cada día del calendario
- Calcula repeticiones basado en strings de frecuencia

**Impacto de cambio**:
- ❌ **ROMPE**: Todo el cálculo de cuándo mostrar recordatorios
- ❌ **ROMPE**: Marcadores en el calendario

**Acción requerida**:
```dart
// ANTES:
switch (reminder.frequency.toLowerCase()) {
  case 'diario': return !checkDay.isBefore(reminderDate);
  case 'cada 8 horas': // lógica manual
}

// DESPUÉS:
final occurrences = reminder.calculateAllScheduledTimes();
return occurrences.any((dt) => isSameDay(dt, day));
```

**Complejidad**: 🔴 ALTA - Requiere reescritura completa de lógica

---

### 3. **`historial.dart`** - Historial de Recordatorios
**Líneas relevantes**: 2, 3, 22, 24-46

**Uso actual**:
- Filtra por tipo: `r.type == 'Medicación'`
- Filtra por estado: `r.isCompleted`
- Filtra por fecha específica usando `reminder.dateTime`
- Ordena por fecha descendente

**Impacto de cambio**:
- ⚠️ **PARCIAL**: Los filtros funcionan igual
- ❌ **ROMPE**: Filtro por fecha (necesita buscar en todas las ocurrencias)

**Acción requerida**:
```dart
// ANTES:
filtered = filtered.where((r) => 
  r.dateTime.year == _selectedDate!.year && ...
).toList();

// DESPUÉS:
// Necesita buscar en las confirmaciones de esa fecha
filtered = filtered.where((r) {
  final occurrences = r.calculateAllScheduledTimes();
  return occurrences.any((dt) => isSameDay(dt, _selectedDate));
}).toList();
```

---

### 4. **`detalle_recordatorio.dart`** - Detalle Individual
**Líneas relevantes**: 3, 4, 17, 198

**Uso actual**:
- Muestra `reminder.dateTime` como hora única
- Muestra `reminder.frequency` como string
- Botón "Marcar como completado" → `markAsCompleted()`

**Impacto de cambio**:
- ❌ **ROMPE**: Ya no hay una sola fecha/hora
- ⚠️ **CAMBIA**: Necesita mostrar rango + horarios diarios
- ❌ **ROMPE**: Marcar completado (ahora son confirmaciones individuales)

**Acción requerida**:
- Rediseñar UI para mostrar:
  - Rango de fechas (inicio → fin)
  - Lista de horarios diarios
  - Intervalo legible (ej: "Cada 8 horas")
  - Historial de confirmaciones por día
- Botón "Completar" debe abrir selector de horario si hay múltiples

---

### 5. **`cuidador_dashboard.dart`** - Dashboard del Cuidador
**Líneas relevantes**: 4, 9, 17, 36, 855-1183

**Uso actual**:
- Lista recordatorios de TODOS los pacientes
- Agrupa por paciente
- Muestra próximos recordatorios
- Accede a `reminder.dateTime` y `reminder.userId`

**Impacto de cambio**:
- ❌ **ROMPE**: Lógica de "próximos recordatorios"
- ⚠️ **AJUSTAR**: Agrupación funciona igual

**Acción requerida**:
- Calcular próxima ocurrencia de cada recordatorio
- Ordenar por próxima ocurrencia en lugar de `dateTime`

---

### 6. **`cuidador_recordatorios_screen.dart`** - Lista de Recordatorios
**Líneas relevantes**: 4, 7, 72-1213

**Uso actual**:
- Lista completa de recordatorios por paciente
- Filtros por tipo y estado
- Editar/eliminar recordatorios
- Acceso a `reminder.dateTime`, `reminder.frequency`

**Impacto de cambio**:
- ❌ **ROMPE**: Visualización de horarios
- ✅ **FUNCIONA**: Filtros por tipo
- ⚠️ **AJUSTAR**: UI de lista

**Acción requerida**:
- Mostrar rango en lugar de fecha única
- Mostrar intervalo legible
- Actualizar cards de recordatorios

---

### 7. **`cuidador_recordatorios_paciente_detalle.dart`** - Detalle por Paciente
**Líneas relevantes**: 4, 7

**Uso actual**:
- Similar a `cuidador_recordatorios_screen.dart`
- Vista filtrada por un paciente específico

**Impacto de cambio**: Igual que #6

---

### 8. **`cuidador_reminder_detail_screen.dart`** - Detalle desde Cuidador
**Líneas relevantes**: 3, 226-318

**Uso actual**:
- Vista detallada de UN recordatorio
- Similar a `detalle_recordatorio.dart` pero desde cuidador

**Impacto de cambio**: Igual que #4

---

## 🟡 **PANTALLAS SECUNDARIAS** (Actualización Recomendada)

### 9. **`cuidador_reportes_screen.dart`** - Reportes y Estadísticas
**Líneas relevantes**: 6

**Uso actual**:
- Importa modelo para estadísticas
- Probablemente cuenta recordatorios completados vs pendientes

**Impacto de cambio**:
- ⚠️ **AJUSTAR**: Estadísticas ahora basadas en confirmaciones

**Acción requerida**:
- Cambiar de `reminder.isCompleted` a contar confirmaciones
- Agregar métricas de adherencia (% confirmados)

---

### 10. **`notificaciones.dart`** - Centro de Notificaciones
**Líneas relevantes**: 6, 9, 24

**Uso actual**:
- Importa modelo para mostrar recordatorios en notificaciones

**Impacto de cambio**:
- ⚠️ **AJUSTAR**: Formato de notificación

**Acción requerida**:
- Actualizar formato de mensaje de notificación
- Incluir horario específico del día

---

### 11. **`cuidador_pacientes_recordatorios.dart`**
**Uso menor**, principalmente navegación

---

### 12. **`agregar_recordatorio.dart`** (VIEJA)
**Ya reemplazada por** `agregar_recordatorio_new.dart` ✅

---

### 13. **`cuidador_crear_recordatorio.dart`** (VIEJA)
**Ya reemplazada por** `cuidador_crear_recordatorio_new.dart` ✅

---

## 🟢 **PANTALLAS DE MENOR IMPACTO**

### 14. **`cuidador_dashboard_backup.dart`**
- Archivo de respaldo, no se usa activamente

### 15. **`ajustes.dart`**, **`asignar_cuidador.dart`**, etc.
- Uso indirecto o mínimo

---

## 📋 **PLAN DE MIGRACIÓN PROPUESTO**

### **Fase 1: Preparación** (1-2 días)
```
✅ Crear ReminderServiceNew con CRUD completo
✅ Crear métodos helper en ReminderNew:
   - calculateOccurrencesForDay(DateTime day)
   - getNextOccurrence()
   - getOccurrencesInRange(start, end)
✅ Testing unitario de nuevos métodos
```

### **Fase 2: Pantallas Core** (3-5 días)
```
1️⃣ welcome.dart (Dashboard paciente)
   - Reescribir _loadTodayReminders()
   - Usar confirmaciones en lugar de isCompleted
   - Calcular próximos horarios del día
   
2️⃣ calendario.dart
   - Reescribir _getRemindersForDay()
   - Usar calculateAllScheduledTimes()
   - Actualizar marcadores visuales

3️⃣ detalle_recordatorio.dart
   - Rediseñar UI completa
   - Mostrar rango y horarios
   - Lista de confirmaciones históricas
   - Selector de horario para confirmar
```

### **Fase 3: Pantallas Cuidador** (2-3 días)
```
4️⃣ cuidador_dashboard.dart
   - Calcular próximos recordatorios
   - Actualizar UI de cards
   
5️⃣ cuidador_recordatorios_screen.dart
   - Actualizar lista de recordatorios
   - Mostrar rango en lugar de fecha única
   
6️⃣ cuidador_reminder_detail_screen.dart
   - Similar a detalle_recordatorio.dart
   - Agregar vista de adherencia del paciente
```

### **Fase 4: Secundarias y Pulido** (1-2 días)
```
7️⃣ historial.dart
   - Ajustar filtros por fecha
   - Usar confirmaciones
   
8️⃣ cuidador_reportes_screen.dart
   - Nuevas métricas de adherencia
   - Gráficos basados en confirmaciones
   
9️⃣ notificaciones.dart
   - Actualizar formato de notifs
```

### **Fase 5: Coexistencia y Deprecación** (ongoing)
```
- Mantener pantallas viejas funcionales
- Banner "Migra tus recordatorios"
- Script de migración opcional
- Eliminar código antiguo cuando 100% migrado
```

---

## 🛠️ **MÉTODOS HELPER NECESARIOS EN ReminderNew**

```dart
/// Calcular todas las ocurrencias para un día específico
List<DateTime> calculateOccurrencesForDay(DateTime day) {
  final dayStart = DateTime(day.year, day.month, day.day);
  final dayEnd = dayStart.add(Duration(days: 1));
  
  return calculateAllScheduledTimes()
    .where((dt) => dt.isAfter(dayStart) && dt.isBefore(dayEnd))
    .toList();
}

/// Obtener la próxima ocurrencia desde ahora
DateTime? getNextOccurrence() {
  final now = DateTime.now();
  final allTimes = calculateAllScheduledTimes();
  
  return allTimes.firstWhereOrNull((dt) => dt.isAfter(now));
}

/// Verificar si tiene ocurrencias en un día
bool hasOccurrencesOn(DateTime day) {
  return calculateOccurrencesForDay(day).isNotEmpty;
}

/// Obtener ocurrencias en rango
List<DateTime> getOccurrencesInRange(DateTime start, DateTime end) {
  return calculateAllScheduledTimes()
    .where((dt) => dt.isAfter(start) && dt.isBefore(end))
    .toList();
}

/// Texto legible del intervalo
String get intervalDisplayText {
  if (intervalType == IntervalType.HOURS) {
    return 'Cada $intervalValue ${intervalValue == 1 ? 'hora' : 'horas'}';
  } else {
    return 'Cada $intervalValue ${intervalValue == 1 ? 'día' : 'días'}';
  }
}
```

---

## ⚠️ **CONSIDERACIONES IMPORTANTES**

### **Compatibilidad con Modelo Antiguo**
- Las pantallas existentes NO funcionarán con `ReminderNew`
- Se necesita migración gradual o completa de una vez
- Opción: Crear adaptadores temporales

### **Sistema de Confirmaciones**
- TODAS las pantallas que usan `reminder.isCompleted` deben cambiar
- Nuevo flujo: verificar confirmación para horario específico
- Dashboard debe mostrar próximo horario, no estado general

### **Performance**
- `calculateAllScheduledTimes()` puede ser costoso
- Cache de cálculos recomendado
- Índices en Firestore para `startDate` y `endDate`

### **UX/UI**
- Usuarios deben entender nuevo concepto de "horarios diarios"
- Onboarding o tutorial recomendado
- Mantener simplicidad visual

---

## 🎯 **PRIORIZACIÓN RECOMENDADA**

```
🔴 URGENTE (Semana 1):
   1. welcome.dart (dashboard principal)
   2. detalle_recordatorio.dart (confirmar recordatorios)
   3. ReminderServiceNew completo

🟡 IMPORTANTE (Semana 2):
   4. calendario.dart (visualización)
   5. cuidador_dashboard.dart (vista cuidador)
   6. cuidador_recordatorios_screen.dart

🟢 SECUNDARIO (Semana 3+):
   7. historial.dart
   8. reportes y estadísticas
   9. notificaciones
```

---

**Última actualización**: 29 Octubre 2024  
**Total estimado**: 2-3 semanas de desarrollo
