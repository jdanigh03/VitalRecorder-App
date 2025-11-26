# 🧪 Guía de Testing - Nuevo Sistema de Recordatorios

## ✅ **Estado Actual: LISTO PARA PROBAR**

Todas las pantallas han sido conectadas con `ReminderServiceNew`. El sistema está funcional y listo para testing.

---

## 📋 **Preparación**

### 1. **Firestore Rules** (IMPORTANTE)

Antes de probar, necesitas agregar reglas de seguridad en Firebase Console:

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Colección de recordatorios nuevos
    match /reminders_new/{reminderId} {
      // Permitir lectura si es el usuario o su cuidador
      allow read: if request.auth != null && (
        resource.data.userId == request.auth.uid ||
        resource.data.createdBy == request.auth.uid
      );
      
      // Permitir crear si está autenticado
      allow create: if request.auth != null &&
        request.resource.data.userId != null;
      
      // Permitir actualizar solo si es el creador o el paciente
      allow update: if request.auth != null && (
        resource.data.userId == request.auth.uid ||
        resource.data.createdBy == request.auth.uid
      );
      
      // Permitir eliminar solo si es el creador
      allow delete: if request.auth != null &&
        resource.data.createdBy == request.auth.uid;
    }
    
    // Colección de confirmaciones
    match /reminder_confirmations/{confirmationId} {
      // Permitir lectura si es el usuario del recordatorio
      allow read: if request.auth != null &&
        resource.data.userId == request.auth.uid;
      
      // Permitir crear solo desde servidor (vía service)
      allow create: if request.auth != null;
      
      // Permitir actualizar solo si es el paciente
      allow update: if request.auth != null &&
        resource.data.userId == request.auth.uid;
      
      // No permitir eliminar directamente
      allow delete: if false;
    }
  }
}
```

### 2. **Índices de Firestore** (Opcional pero recomendado)

Si recibes errores de "requires an index", crea estos índices en Firebase Console:

**Colección: `reminder_confirmations`**
- Campo: `userId` (Ascending) + `status` (Ascending) + `scheduledTime` (Ascending)
- Campo: `reminderId` (Ascending) + `scheduledTime` (Ascending)

---

## 🧪 **Plan de Testing**

### **Test 1: Crear Recordatorio Básico** ⭐

**Como:** Paciente  
**Objetivo:** Crear un recordatorio simple y verificar que se guarde

**Pasos:**
1. Abre la app como paciente
2. Navega a "Agregar Recordatorio" (nueva pantalla)
3. Completa el flujo:
   - **Paso 1:** Tipo = Medicamento, Nombre = "Prueba Test", Hora = 14:00
   - **Paso 2:** Duración = 5 días
   - **Paso 3:** Frecuencia = Cada 8 horas
   - **Paso 4:** Deja los horarios por defecto (14:00, 22:00, 06:00)
   - **Paso 5:** Revisa el resumen y crea

**Esperado:**
- ✅ Se muestra loading
- ✅ Mensaje: "Recordatorio creado exitosamente"
- ✅ Regresa a la pantalla anterior

**Verificar en Firestore:**
```
Colección: reminders_new
- Debe haber 1 documento con:
  - title: "Prueba Test"
  - type: "medication"
  - startDate: (fecha de hoy 14:00)
  - endDate: (5 días después)
  - dailyScheduleTimes: 3 horarios

Colección: reminder_confirmations
- Debe haber 15 documentos (5 días × 3 horarios/día)
- Todos con status: "PENDING"
- scheduledTime: diferentes fechas/horas
```

---

### **Test 2: Crear Recordatorio como Cuidador** ⭐

**Como:** Cuidador  
**Objetivo:** Crear recordatorio para un paciente

**Pasos:**
1. Abre la app como cuidador
2. Selecciona un paciente
3. "Crear Recordatorio" (nueva pantalla)
4. Completa el flujo similar al Test 1

**Esperado:**
- ✅ Se muestra info del paciente en el Paso 1
- ✅ Mensaje: "Recordatorio creado exitosamente para [Nombre Paciente]"

**Verificar en Firestore:**
```
reminders_new:
- userId: (ID del paciente)
- createdBy: (ID del cuidador)
```

---

### **Test 3: Editar Recordatorio**

**Pasos:**
1. Edita el recordatorio creado en Test 1
2. Cambia la duración de 5 días a 1 semana
3. Guarda

**Esperado:**
- ✅ Mensaje: "Recordatorio actualizado exitosamente"
- ✅ Se regeneran las confirmaciones

**Verificar en Firestore:**
```
reminder_confirmations:
- Ahora debe haber 21 documentos (7 días × 3 horarios/día)
- Las confirmaciones viejas fueron eliminadas
```

---

### **Test 4: Recordatorio con Intervalo de Días**

**Pasos:**
1. Crea nuevo recordatorio
2. En Paso 3, selecciona "Días" en lugar de "Horas"
3. Establece "Cada 2 días"

**Esperado:**
- ✅ Paso 4 debe mostrar solo 1 horario por día
- ✅ Total de recordatorios = días ÷ 2

---

### **Test 5: Personalizar Horarios**

**Pasos:**
1. Crea recordatorio con "Cada 8 horas" a las 08:00
2. En Paso 4:
   - Horarios calculados: 08:00, 16:00, 00:00
   - Cambia 00:00 → 23:00
   - Agrega un horario: 12:00
3. Guarda

**Esperado:**
- ✅ Se permiten las modificaciones
- ✅ Se guardan los 4 horarios personalizados

**Verificar en Firestore:**
```
reminders_new:
- dailyScheduleTimes: [
    {hour: 8, minute: 0},
    {hour: 12, minute: 0},
    {hour: 16, minute: 0},
    {hour: 23, minute: 0}
  ]
```

---

### **Test 6: Validaciones**

**Test 6.1: Fecha pasada**
- Intenta crear recordatorio con fecha de inicio en el pasado
- **Esperado:** ❌ Error de validación

**Test 6.2: Fecha fin antes de inicio**
- Intenta poner fecha fin antes que fecha inicio
- **Esperado:** ❌ No debe permitir seleccionar

**Test 6.3: Sin horarios**
- Elimina todos los horarios en Paso 4
- **Esperado:** ❌ Error: "Debe haber al menos un horario"

**Test 6.4: Nombre vacío**
- Deja el nombre en blanco en Paso 1
- **Esperado:** ❌ "Por favor ingresa un nombre"

---

## 🔍 **Verificación en Firebase Console**

### Abrir Firestore:
1. Ve a Firebase Console
2. Firestore Database
3. Busca las colecciones:
   - `reminders_new`
   - `reminder_confirmations`

### Estructura esperada de `reminders_new`:
```json
{
  "id": "abc123",
  "title": "Amoxicilina 500mg",
  "description": "Tomar con alimentos",
  "type": "medication",
  "startDate": Timestamp,
  "endDate": Timestamp,
  "intervalType": "HOURS",
  "intervalValue": 8,
  "dailyScheduleTimes": [
    {"hour": 8, "minute": 0},
    {"hour": 16, "minute": 0},
    {"hour": 0, "minute": 0}
  ],
  "userId": "user_id_here",
  "createdBy": "caregiver_id_or_null",
  "isActive": true,
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

### Estructura esperada de `reminder_confirmations`:
```json
{
  "id": "conf_456",
  "reminderId": "abc123",
  "userId": "user_id_here",
  "scheduledTime": Timestamp,
  "status": "PENDING",
  "confirmedAt": null,
  "notes": null,
  "createdAt": Timestamp
}
```

---

## 🐛 **Posibles Errores y Soluciones**

### Error: "Permission denied"
**Causa:** Firestore rules no configuradas  
**Solución:** Agrega las rules del inicio de este documento

### Error: "Requires an index"
**Causa:** Falta índice compuesto  
**Solución:** Haz clic en el link del error, Firebase creará el índice automáticamente

### Error: "No se pudo guardar el recordatorio"
**Causa:** Usuario no autenticado o error de red  
**Solución:** 
1. Verifica que `FirebaseAuth.instance.currentUser` no sea null
2. Revisa la consola para ver el error específico

### No aparecen confirmaciones
**Causa:** Error en batch write o validación del modelo  
**Solución:**
1. Revisa la consola: debe mostrar "Generando X confirmaciones..."
2. Verifica que `calculateAllScheduledTimes()` retorne valores

---

## 📊 **Checklist de Funcionalidades**

```
[ ] Crear recordatorio como paciente
[ ] Crear recordatorio como cuidador
[ ] Editar recordatorio existente
[ ] Cambiar fechas (regenera confirmaciones)
[ ] Cambiar horarios (regenera confirmaciones)
[ ] Validación de fechas pasadas
[ ] Personalizar horarios diarios
[ ] Intervalos en horas (4, 6, 8, 12)
[ ] Intervalo personalizado en horas
[ ] Intervalos en días
[ ] Duración: 5 días
[ ] Duración: 1 semana
[ ] Duración: 1 mes
[ ] Duración: personalizada
[ ] Tipo: Medicamento
[ ] Tipo: Actividad
[ ] Se guardan correctamente en Firestore
[ ] Se generan todas las confirmaciones
[ ] Mensajes de éxito/error apropiados
```

---

## 🚀 **Próximos Pasos Después del Testing**

Una vez que el testing básico funcione:

1. **Actualizar `welcome.dart`** para mostrar confirmaciones pendientes
2. **Crear pantalla de confirmaciones** para el paciente
3. **Dashboard de adherencia** para el cuidador
4. **Notificaciones push** por horario
5. **Background job** para marcar como MISSED

---

## 💡 **Tips de Debugging**

### Ver logs en la consola:
El service imprime logs útiles:
```
✅ Recordatorio creado: abc123 con 21 confirmaciones
Generando 21 confirmaciones...
✅ Confirmaciones generadas exitosamente
```

### Queries útiles en Firestore Console:
```javascript
// Ver todos los recordatorios de un usuario
where userId == "user_id"
where isActive == true

// Ver confirmaciones pendientes de hoy
where userId == "user_id"
where status == "PENDING"
where scheduledTime >= today_start
where scheduledTime < today_end
```

---

**Fecha:** 29 Octubre 2024  
**Versión:** 1.0  
**Estado:** ✅ Listo para testing
