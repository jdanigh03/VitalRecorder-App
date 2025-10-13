# 🔔 Sistema de Notificaciones Push con Firebase
## Estado Actual y Plan de Implementación

*Documento actualizado: Octubre 2024*

---

## 📋 **RESUMEN EJECUTIVO**

Este documento detalla la implementación completa del sistema de notificaciones push utilizando Firebase Cloud Messaging (FCM) para la aplicación Vital Recorder, incluyendo invitaciones entre cuidadores-pacientes y recordatorios de medicamentos.

---

## ✅ **LO QUE YA TENEMOS IMPLEMENTADO**

### **1. Estructura Base del Sistema**
- ✅ **Modelo Paciente** (`lib/models/paciente.dart`)
  - Relaciones cuidador-paciente
  - Información médica estructurada
  - IDs de cuidadores vinculados

- ✅ **PacienteService** (`lib/services/paciente_service.dart`)
  - CRUD completo de pacientes
  - Asignación/remoción de cuidadores
  - Búsquedas y estadísticas

- ✅ **Sistema de Invitaciones**
  - Modelo `InvitacionCuidador`
  - Flujo completo: envío → aceptación → vinculación
  - Sincronización con nuevo sistema de pacientes

### **2. NotificationService Base**
- ✅ **Configuración FCM** básica
- ✅ **Notificaciones locales** funcionando
- ✅ **Manejo de mensajes** en primer plano
- ✅ **Sistema de notificaciones pendientes** en Firestore

### **3. Integración Sistema de Invitaciones**
- ✅ **Problema resuelto**: La notificación ya NO le llega al cuidador por error
- ✅ **Notificación pendiente**: Se crea en Firestore para que la vea el paciente
- ✅ **Sincronización completa**: Sistema original + nuevo sistema funcionando juntos

---

## 🚨 **PROBLEMAS ACTUALES IDENTIFICADOS**

### **❌ Notificaciones Push NO Funcionan Completamente**
1. **No hay persistencia de FCM tokens** por usuario
2. **No hay Cloud Functions** para enviar push reales
3. **Las notificaciones solo aparecen** cuando se abre la app (pendientes en Firestore)
4. **No hay notificaciones push** para:
   - Invitación recibida (al cuidador)
   - Invitación aceptada (al paciente)
   - Recordatorios de medicamentos con aviso previo
   - Confirmación de toma de pastilla (al cuidador)

---

## 🎯 **PLAN DE IMPLEMENTACIÓN COMPLETO**

### **FASE 1: Persistencia de FCM Tokens** 🔥 *Alta Prioridad*

#### **1.1 Actualizar NotificationService para guardar tokens**
```dart
// Archivo: lib/services/notification_service.dart
Future<void> saveUserFCMToken() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  
  final messaging = FirebaseMessaging.instance;
  final token = await messaging.getToken();
  
  if (token != null) {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('fcmTokens')
        .doc(token) // Usar token como ID para evitar duplicados
        .set({
      'token': token,
      'platform': Platform.isAndroid ? 'android' : 'ios',
      'deviceInfo': await _getDeviceInfo(),
      'updatedAt': FieldValue.serverTimestamp(),
      'active': true,
    });
  }
}

// Manejar renovación de tokens
void _setupTokenRefreshListener() {
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    saveUserFCMToken(); // Guardar nuevo token
  });
}
```

#### **1.2 Integrar en AuthWrapper/Login**
- Llamar `saveUserFCMToken()` después del login exitoso
- Configurar listeners al inicializar la app

#### **1.3 Limpiar tokens inactivos**
- Marcar tokens como `active: false` al cerrar sesión
- Cloud Function periódica para limpiar tokens expirados

---

### **FASE 2: Cloud Functions para Push Notifications** 🔥 *Alta Prioridad*

#### **2.1 Estructura de Cloud Functions**
```
functions/
├── index.js
├── src/
│   ├── notifications/
│   │   ├── invitations.js
│   │   ├── reminders.js
│   │   └── utils.js
│   └── utils/
│       └── messaging.js
```

#### **2.2 Function: Invitación Recibida**
```javascript
// Trigger: onCreate en 'invitaciones_cuidador'
exports.onInvitacionCreada = functions.firestore
  .document('invitaciones_cuidador/{invId}')
  .onCreate(async (snapshot, context) => {
    const invitacion = snapshot.data();
    
    // Buscar cuidador por email y obtener sus tokens
    const cuidadorQuery = await admin.firestore()
      .collection('users')
      .where('email', '==', invitacion.cuidador_email)
      .where('role', '==', 'cuidador')
      .limit(1)
      .get();
    
    if (cuidadorQuery.empty) return null;
    
    const cuidadorId = cuidadorQuery.docs[0].id;
    const tokensSnap = await admin.firestore()
      .collection('users').doc(cuidadorId)
      .collection('fcmTokens')
      .where('active', '==', true)
      .get();
    
    const tokens = tokensSnap.docs.map(doc => doc.data().token);
    if (tokens.length === 0) return null;
    
    const message = {
      notification: {
        title: '🫂 Nueva Invitación de Cuidado',
        body: `${invitacion.paciente_nombre} te invita a ser su cuidador como "${invitacion.relacion}"`,
      },
      data: {
        tipo: 'invitacion_recibida',
        invitacion_id: context.params.invId,
        paciente_nombre: invitacion.paciente_nombre,
        relacion: invitacion.relacion,
        screen: 'invitaciones_cuidador',
      },
      tokens,
    };
    
    return admin.messaging().sendMulticast(message);
  });
```

#### **2.3 Function: Invitación Aceptada**
```javascript
// Trigger: onUpdate en 'invitaciones_cuidador'
exports.onInvitacionAceptada = functions.firestore
  .document('invitaciones_cuidador/{invId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    // Solo procesar cambio de pendiente a aceptada
    if (before.estado === 'pendiente' && after.estado === 'aceptada') {
      const pacienteId = after.paciente_id;
      const cuidadorNombre = after.cuidador_nombre;
      
      // Obtener tokens del paciente
      const tokensSnap = await admin.firestore()
        .collection('users').doc(pacienteId)
        .collection('fcmTokens')
        .where('active', '==', true)
        .get();
      
      const tokens = tokensSnap.docs.map(doc => doc.data().token);
      if (tokens.length === 0) return null;
      
      const message = {
        notification: {
          title: '🎉 ¡Invitación Aceptada!',
          body: `${cuidadorNombre} ha aceptado tu invitación para ser tu cuidador.`,
        },
        data: {
          tipo: 'invitacion_aceptada',
          cuidador_nombre: cuidadorNombre,
          relacion: after.relacion,
          screen: 'home',
        },
        tokens,
      };
      
      return admin.messaging().sendMulticast(message);
    }
    
    return null;
  });
```

---

### **FASE 3: Sistema de Recordatorios Mejorado** 🟡 *Media Prioridad*

#### **3.1 Configuración de Avisos Previos**
```dart
// Agregar a UserSettings o crear ReminderSettings
class ReminderSettings {
  final int minutosAvisoAntes; // 5, 10, 15, 30 minutos
  final bool habilitarAvisoAntes;
  final bool notificarCuidadoresAlTomar;
  final List<String> diasSemana; // Para recordatorios semanales
  
  // ... constructors y métodos
}
```

#### **3.2 Programación Doble de Notificaciones**
```dart
// En ReminderService
Future<void> programarRecordatorioConAvisoAntes(Recordatorio recordatorio) async {
  final settings = await _getReminderSettings();
  
  // 1. Programar notificación principal (a la hora exacta)
  await _programarNotificacionPrincipal(recordatorio);
  
  // 2. Programar aviso previo si está habilitado
  if (settings.habilitarAvisoAntes && settings.minutosAvisoAntes > 0) {
    final tiempoAviso = recordatorio.fechaHora.subtract(
      Duration(minutes: settings.minutosAvisoAntes)
    );
    
    await _programarNotificacionAviso(recordatorio, tiempoAviso);
  }
}
```

#### **3.3 Cloud Function: Toma de Medicamento Registrada**
```javascript
// Trigger: onCreate en 'users/{userId}/tomas_medicamentos'
exports.onTomaRegistrada = functions.firestore
  .document('users/{userId}/tomas_medicamentos/{tomaId}')
  .onCreate(async (snapshot, context) => {
    const toma = snapshot.data();
    const pacienteId = context.params.userId;
    
    // Obtener información del paciente y sus cuidadores
    const pacienteDoc = await admin.firestore()
      .collection('users').doc(pacienteId).get();
    const pacienteData = pacienteDoc.data();
    
    // Buscar todos los cuidadores del paciente
    const cuidadoresSnap = await admin.firestore()
      .collection('users').doc(pacienteId)
      .collection('cuidadores').get();
    
    if (cuidadoresSnap.empty) return null;
    
    // Obtener tokens de todos los cuidadores
    let allTokens = [];
    for (const cuidadorDoc of cuidadoresSnap.docs) {
      const cuidadorEmail = cuidadorDoc.data().email;
      
      const cuidadorUserSnap = await admin.firestore()
        .collection('users')
        .where('email', '==', cuidadorEmail)
        .limit(1).get();
      
      if (!cuidadorUserSnap.empty) {
        const cuidadorUserId = cuidadorUserSnap.docs[0].id;
        const tokensSnap = await admin.firestore()
          .collection('users').doc(cuidadorUserId)
          .collection('fcmTokens')
          .where('active', '==', true).get();
        
        const tokens = tokensSnap.docs.map(doc => doc.data().token);
        allTokens = allTokens.concat(tokens);
      }
    }
    
    if (allTokens.length === 0) return null;
    
    const message = {
      notification: {
        title: `💊 ${pacienteData.persona.nombres} tomó su medicamento`,
        body: `${toma.medicamento_nombre} - ${toma.fecha_hora_toma}`,
      },
      data: {
        tipo: 'medicamento_tomado',
        paciente_id: pacienteId,
        paciente_nombre: pacienteData.persona.nombres,
        medicamento: toma.medicamento_nombre,
        screen: 'paciente_detalle',
      },
      tokens: allTokens,
    };
    
    return admin.messaging().sendMulticast(message);
  });
```

---

### **FASE 4: Mejoras de UX y Configuración** 🟢 *Baja Prioridad*

#### **4.1 Pantalla de Configuración de Notificaciones**
- Toggle para habilitar/deshabilitar cada tipo de notificación
- Selector de tiempo para aviso previo (5, 10, 15, 30 min)
- Configuración de horarios "no molestar"
- Test de notificaciones

#### **4.2 Centro de Notificaciones Mejorado**
- Vista unificada de todas las notificaciones
- Filtros por tipo (invitaciones, recordatorios, confirmaciones)
- Acciones rápidas (aceptar/rechazar desde la notificación)
- Historial de notificaciones

#### **4.3 Analytics y Monitoreo**
- Métricas de entrega de notificaciones
- Tasas de apertura y respuesta
- Tokens inactivos y limpieza automática

---

## 📁 **ARCHIVOS A CREAR/MODIFICAR**

### **Archivos Flutter (Cliente)**
```
lib/services/
├── notification_service.dart (✏️ MODIFICAR)
├── reminder_service.dart (✏️ MODIFICAR)
└── analytics_service.dart (🆕 CREAR)

lib/models/
├── reminder_settings.dart (🆕 CREAR)
├── notification_model.dart (🆕 CREAR)
└── toma_medicamento.dart (🆕 CREAR)

lib/screens/
├── configuracion_notificaciones.dart (🆕 CREAR)
├── centro_notificaciones.dart (🆕 CREAR)
└── test_notificaciones.dart (🆕 CREAR)

lib/utils/
└── notification_handler.dart (🆕 CREAR)
```

### **Cloud Functions (Servidor)**
```
functions/
├── index.js (🆕 CREAR)
├── package.json (🆕 CREAR)
├── src/
│   ├── notifications/
│   │   ├── invitations.js (🆕 CREAR)
│   │   ├── reminders.js (🆕 CREAR)
│   │   └── medication_tracking.js (🆕 CREAR)
│   └── utils/
│       ├── messaging.js (🆕 CREAR)
│       ├── user_utils.js (🆕 CREAR)
│       └── validation.js (🆕 CREAR)
```

---

## 🚀 **PLAN DE DESPLIEGUE**

### **Sprint 1 (Semana 1-2): Fundamentos**
- [ ] Implementar persistencia de FCM tokens
- [ ] Configurar estructura básica de Cloud Functions
- [ ] Deploy inicial de Functions (invitación creada/aceptada)
- [ ] Testing en desarrollo

### **Sprint 2 (Semana 3-4): Recordatorios**
- [ ] Implementar sistema de aviso previo
- [ ] Cloud Function para registro de tomas
- [ ] Integrar configuración de recordatorios
- [ ] Testing completo del flujo de recordatorios

### **Sprint 3 (Semana 5-6): UX y Refinamiento**
- [ ] Pantalla de configuración de notificaciones
- [ ] Centro de notificaciones mejorado
- [ ] Optimización de performance
- [ ] Testing de integración completo

### **Sprint 4 (Semana 7): Producción**
- [ ] Deploy a producción
- [ ] Monitoreo y analytics
- [ ] Documentación final
- [ ] Capacitación de usuarios

---

## 🔧 **CONFIGURACIÓN TÉCNICA REQUERIDA**

### **Firebase Console**
1. **Cloud Functions** habilitado
2. **Cloud Messaging** configurado
3. **Firestore Security Rules** actualizadas para tokens y notificaciones
4. **Billing account** configurado (Functions requiere plan Blaze)

### **Dependencias Adicionales**
```yaml
# pubspec.yaml
dependencies:
  firebase_messaging: ^14.7.9
  flutter_local_notifications: ^16.1.0
  timezone: ^0.9.2
  device_info_plus: ^9.1.0
```

```json
// functions/package.json
{
  "dependencies": {
    "firebase-admin": "^11.11.0",
    "firebase-functions": "^4.4.1"
  }
}
```

---

## ⚠️ **CONSIDERACIONES IMPORTANTES**

### **Seguridad**
- Validar permisos antes de enviar notificaciones
- Cifrar datos sensibles en payloads
- Implementar rate limiting para evitar spam

### **Performance**
- Batch de envío de notificaciones (máximo 500 tokens por request)
- Cache de tokens frecuentemente usados
- Cleanup automático de tokens inválidos

### **UX**
- Notificaciones claras y accionables
- Respeto a configuraciones "no molestar"
- Fallback a notificaciones locales si push falla

### **Testing**
- Testing exhaustivo en dispositivos reales
- Simulación de todos los escenarios de notificación
- Verificación de entrega en diferentes estados de la app

---

## 📊 **MÉTRICAS DE ÉXITO**

- **📬 Tasa de entrega de notificaciones**: >95%
- **👆 Tasa de apertura**: >40%
- **⚡ Tiempo de respuesta promedio**: <5 segundos
- **😊 Satisfacción del usuario**: >4.5/5
- **🐛 Errores de notificación**: <1%

---

*Este documento será actualizado conforme se implemente cada fase del plan.*
