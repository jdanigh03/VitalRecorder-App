# Mejoras al Firmware Arduino v2.0 - Sistema de Conexión

## Fecha de Actualización
18 de Noviembre de 2025

## Resumen de Cambios

Se ha mejorado el firmware de la manilla Arduino (ESP32-C3) para trabajar de manera óptima con el nuevo sistema de monitoreo de conexión de la app. Las mejoras incluyen:

1. **Heartbeat automático** cada 30 segundos
2. **Respuestas mejoradas** al comando STATUS
3. **Nuevo comando PING/PONG** para verificación rápida
4. **Detección proactiva** de desconexión
5. **Logs optimizados** para mejor debugging

---

## 🔄 Cambios Implementados

### 1. Sistema de Heartbeat Automático

```cpp
// Nuevas variables globales
uint32_t lastHeartbeatTime = 0;
const uint32_t HEARTBEAT_INTERVAL = 30000; // 30 segundos
```

**Funcionalidad:**
- La manilla envía automáticamente un mensaje `HEARTBEAT` cada 30 segundos
- Solo se envía cuando hay conexión BLE activa
- Incluye timestamp actual si el reloj está sincronizado
- Mantiene la conexión "viva" y previene timeouts

**Implementación en loop():**
```cpp
if (deviceConnected && (now - lastHeartbeatTime > HEARTBEAT_INTERVAL)) {
    lastHeartbeatTime = now;
    String heartbeat = "HEARTBEAT ";
    if (deviceClock > 0) {
        // Agregar hora actual
        sprintf(timeStr, "%02d:%02d:%02d", hour, min, sec);
        heartbeat += String(timeStr);
    }
    pTxChar->notify();
}
```

**Beneficios:**
- ✅ Previene timeouts innecesarios
- ✅ La app puede confirmar que la manilla está "viva"
- ✅ Información adicional sobre el estado del reloj

---

### 2. Comando STATUS Mejorado

**Antes:**
```cpp
bleSendLine("STATUS OK v2.0\r\n");
```

**Ahora:**
```cpp
String response = "OK STATUS v2.0";
if (deviceClock > 0) {
    // Agregar hora actual
    response += " HH:MM:SS";
}
response += " REM:" + reminderCount;
response += " CONN:" + (deviceConnected ? "YES" : "NO");
bleSendLine(response + "\r\n");
```

**Ejemplo de respuesta:**
```
OK STATUS v2.0 14:35:22 REM:5 CONN:YES
```

**Información incluida:**
- ✅ Versión del firmware (v2.0)
- ✅ Hora actual (si está sincronizado)
- ✅ Cantidad de recordatorios cargados
- ✅ Estado de conexión BLE

---

### 3. Nuevo Comando PING/PONG

```cpp
else if (up == "PING") {
    bleSendLine("PONG\r\n");
    Serial.println("[PING] Pong enviado");
}
```

**Propósito:**
- Verificación ultrarrápida de conexión
- Respuesta mínima sin procesamiento adicional
- Ideal para health checks frecuentes

**Uso desde la app:**
```dart
await sendCommand("PING");
// Espera respuesta "PONG"
```

---

### 4. Detección Proactiva de Desconexión

**Mejoras en el loop():**
```cpp
// Verificación cada 5 segundos (antes era 2)
if (deviceConnected && pServer && pServer->getConnectedCount() == 0) {
    Serial.println("[BLE] ⚠️ Conexión perdida detectada");
    deviceConnected = false;
    displayMessage("Desconectado", "Reconectando...");
}
```

**Cambios:**
- Intervalo de verificación aumentado a 5 segundos (reduce spam en logs)
- Mensaje visual en pantalla OLED cuando se pierde conexión
- Log más visible con emoji de advertencia

---

### 5. Callbacks de Conexión Mejorados

**onConnect():**
```cpp
void onConnect(NimBLEServer* s) {
    deviceConnected = true;
    justConnected = true;
    lastHeartbeatTime = millis(); // ⭐ Reset heartbeat
    Serial.println("[BLE] ✅ *** CONEXIÓN ESTABLECIDA ***");
    bleSendLine("OK CONNECTED v2.0\r\n");
    
    delay(1000);
    syncPendingConfirmations();
}
```

**Mejoras:**
- Reset del timer de heartbeat al conectar
- Mensaje de versión en la respuesta
- Log más visible con emoji

**onDisconnect():**
```cpp
void onDisconnect(NimBLEServer* s) {
    deviceConnected = false;
    justDisconnected = true;
    Serial.println("[BLE] 🔴 Desconectado, reanudando advertising...");
    NimBLEDevice::startAdvertising();
    lastHeartbeatTime = 0; // ⭐ Reset heartbeat
}
```

---

### 6. Logs Optimizados

**Cambios en el estado periódico:**

**Antes:**
```cpp
// Cada 2 segundos
Serial.printf("[STATUS] BTN=%s | BLE=%s | REM=%s\n", ...);
```

**Ahora:**
```cpp
// Cada 5 segundos, más información
Serial.printf("[STATUS] BTN=%s | BLE=%s | REM=%s | CLOCK=%s\n", 
    buttonState, bleState, reminderState, clockState);
```

**Beneficios:**
- ⬇️ Menos spam en el monitor serial
- ℹ️ Más información por línea
- 🕐 Estado del reloj incluido

---

## 🔗 Integración con la App

### Flujo de Verificación de Conexión

```
App (cada 1 minuto)
    ↓
Envía: "STATUS"
    ↓
Arduino responde: "OK STATUS v2.0 14:35:22 REM:5 CONN:YES"
    ↓
App detecta respuesta en < 10s
    ↓
✅ Conexión OK

SI NO HAY RESPUESTA:
    ↓
⚠️ Timeout (10s)
    ↓
App marca como desconectada
    ↓
🔔 Notificación al usuario
    ↓
🔄 Inicia reconexión automática
```

### Heartbeat Complementario

```
Cada 30 segundos (Arduino)
    ↓
Envía: "HEARTBEAT 14:35:22"
    ↓
App recibe mensaje
    ↓
Actualiza _lastSuccessfulResponse
    ↓
✅ Confirma que conexión está viva
```

---

## 📋 Nuevos Comandos Disponibles

| Comando | Respuesta | Propósito |
|---------|-----------|-----------|
| `STATUS` | `OK STATUS v2.0 HH:MM:SS REM:X CONN:YES` | Verificación completa |
| `PING` | `PONG` | Verificación rápida |
| `HEARTBEAT` | (automático) | Mantener conexión viva |

---

## 🎯 Compatibilidad

### Con Sistema Anterior
✅ **Totalmente compatible** - Los comandos anteriores siguen funcionando:
- `REM_ADD`
- `REM_CLEAR`
- `REM_CONFIRM`
- `SYNC_TIME`
- `GET_PENDING`
- etc.

### Con Sistema Nuevo de Monitoreo
✅ **Optimizado** para trabajar con:
- Verificaciones cada 1 minuto
- Timeout de 10 segundos
- Reconexión automática
- Notificaciones de desconexión

---

## 🔧 Configuración

### Constantes Configurables

```cpp
// Intervalo de heartbeat (30 segundos por defecto)
const uint32_t HEARTBEAT_INTERVAL = 30000;

// Intervalo de logs de estado (5 segundos)
// Cambiar en: if (millis() - lastStatusTime > 5000)

// Timeout de recordatorio activo (5 minutos)
// En: alertUntil = millis() + 300000;
```

---

## 🧪 Pruebas Recomendadas

### Test 1: Verificar Heartbeat
1. Conectar manilla
2. Monitorear serial por 1 minuto
3. Verificar que aparece `[HEARTBEAT] Enviado` cada 30s

### Test 2: Respuesta a STATUS
1. Enviar comando `STATUS` desde la app
2. Verificar respuesta completa con todos los datos
3. Tiempo de respuesta debe ser < 1 segundo

### Test 3: Comando PING
1. Enviar comando `PING` desde la app
2. Verificar respuesta `PONG` inmediata
3. Debe ser más rápido que STATUS

### Test 4: Detección de Desconexión
1. Conectar manilla
2. Apagar Bluetooth del teléfono
3. Verificar que manilla detecta desconexión en ~5 segundos
4. Verificar mensaje en OLED: "Desconectado - Reconectando..."

### Test 5: Reconexión con Heartbeat
1. Provocar desconexión
2. Reconectar
3. Verificar que heartbeat se reinicia correctamente

---

## 📊 Rendimiento

### Consumo de Recursos

| Característica | Impacto | Frecuencia |
|----------------|---------|------------|
| Heartbeat | Mínimo | 30s |
| STATUS check | Bajo | A demanda |
| PING/PONG | Mínimo | A demanda |
| Logs reducidos | ⬇️ Mejora | 5s (antes 2s) |

### Consumo de Batería
- ✅ **Optimizado** - Heartbeat cada 30s es suficiente
- ✅ **Eficiente** - Logs reducidos = menos procesamiento
- ✅ **Inteligente** - Solo envía heartbeat si está conectado

---

## 🐛 Troubleshooting

### Problema: No se reciben heartbeats
**Solución:**
- Verificar que `deviceConnected` sea `true`
- Verificar logs: debe aparecer `[HEARTBEAT] Enviado`
- Verificar que `pTxChar` no sea `nullptr`

### Problema: STATUS no responde
**Solución:**
- Verificar conexión BLE activa
- Verificar que el comando llega al callback RX
- Verificar logs: debe aparecer `[BLE RX] STATUS`

### Problema: Manilla no detecta desconexión
**Solución:**
- Verificar que el loop se ejecuta (no bloqueado)
- Verificar `pServer->getConnectedCount()`
- Aumentar frecuencia de verificación si es necesario

---

## 📝 Notas de Versión

### v2.0 (18 Nov 2025)
- ✅ Agregado sistema de heartbeat automático
- ✅ Mejorado comando STATUS con más información
- ✅ Agregado comando PING/PONG
- ✅ Optimizados logs (5s en lugar de 2s)
- ✅ Mejorada detección de desconexión
- ✅ Callbacks con reset de heartbeat

### Versiones Futuras Planeadas
- Modo de bajo consumo adaptativo
- Métricas de calidad de señal
- Compresión de datos para heartbeat
- Configuración dinámica de intervalos

---

## 🔐 Seguridad

El firmware mantiene las mismas garantías de seguridad:
- ✅ No expone datos sensibles en heartbeat
- ✅ Validación de comandos mantiene integridad
- ✅ Sin cambios en autenticación BLE

---

## 📚 Referencias

- **Archivo principal:** `manilla_Arduino_v2.ino`
- **Sistema de app:** `SISTEMA_MONITOREO_CONEXION_MANILLA.md`
- **Protocolo BLE:** Nordic UART Service (NUS)
- **Hardware:** ESP32-C3 Super Mini

---

## ✅ Checklist de Actualización

Para actualizar el firmware a esta versión:

- [ ] Hacer backup del firmware anterior
- [ ] Cargar nuevo código en ESP32-C3
- [ ] Verificar compilación sin errores
- [ ] Probar conexión BLE básica
- [ ] Verificar heartbeat en serial monitor
- [ ] Probar comando STATUS mejorado
- [ ] Probar comando PING/PONG
- [ ] Verificar detección de desconexión
- [ ] Probar con app actualizada
- [ ] Verificar logs optimizados

---

## 💡 Conclusión

Las mejoras al firmware v2.0 complementan perfectamente el sistema de monitoreo de conexión de la app, proporcionando:

- 🔄 Comunicación bidireccional confiable
- ⚡ Respuestas rápidas y eficientes
- 🛡️ Detección proactiva de problemas
- 📊 Información detallada de estado
- 🔋 Optimización de recursos

El sistema ahora es más robusto, confiable y fácil de mantener.
