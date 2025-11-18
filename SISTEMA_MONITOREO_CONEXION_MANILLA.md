# Sistema de Monitoreo de Conexión de la Manilla

## Fecha de Implementación
18 de Noviembre de 2025

## Descripción General

Se ha implementado un sistema automático de monitoreo de conexión que verifica cada **1 minuto** el estado de conexión con la manilla BLE. Si la manilla no responde después de un timeout de **10 segundos**, el sistema:

1. Marca la manilla como desconectada
2. Envía una notificación al usuario
3. Actualiza el estado en todas las secciones de la app
4. Inicia automáticamente el proceso de reconexión

## Cambios Implementados

### 1. BraceletService (`lib/services/bracelet_service.dart`)

#### Nuevas Variables
- `_connectionCheckTimer`: Timer que ejecuta verificación cada 1 minuto
- `_isCheckingConnection`: Flag para evitar verificaciones concurrentes
- `_lastSuccessfulResponse`: Timestamp de la última respuesta exitosa
- `_connectionCheckInterval`: Constante de 1 minuto para intervalo de verificación
- `_responseTimeout`: Constante de 10 segundos para timeout de respuesta

#### Nuevos Métodos

**`_startConnectionMonitoring()`**
- Inicia el Timer periódico de verificación cada 1 minuto
- Se ejecuta automáticamente al inicializar el servicio

**`_checkConnectionHealth()`**
- Verifica la salud de la conexión enviando comando STATUS
- Solo se ejecuta si hay conexión activa y no hay otra verificación en curso
- Detecta timeouts y llama a `_handleConnectionLost()` si no hay respuesta

**`sendCommandWithResponse(String command, {Duration? timeout})`**
- Nueva versión de envío de comandos con espera de respuesta
- Implementa timeout configurable (por defecto 10 segundos)
- Retorna `true` si recibe respuesta, `false` en caso de timeout
- Actualiza `_lastSuccessfulResponse` cuando recibe respuesta

**`_handleConnectionLost()`**
- Maneja la pérdida de conexión detectada
- Actualiza estado del dispositivo a `disconnected`
- Notifica a los listeners para actualizar UI
- Envía notificación al usuario
- Inicia reconexión automática si está habilitada

#### Modificaciones a Métodos Existentes

**`_handleIncomingData(List<int> data)`**
- Ahora actualiza `_lastSuccessfulResponse` cada vez que recibe datos
- Esto permite rastrear la última comunicación exitosa

**`dispose()`**
- Ahora también cancela `_connectionCheckTimer`

### 2. NotificationService (`lib/services/notification_service.dart`)

#### Nuevo Método

**`showBraceletDisconnectedNotification()`**
- Envía notificación local cuando se detecta desconexión
- Prioridad alta para asegurar visibilidad
- Canal dedicado: `bracelet_status_channel`
- Título: "⚠️ Manilla desconectada"
- Mensaje: "La conexión con la manilla se ha perdido. Por favor verifica la conexión."

### 3. BraceletStatusWidget (`lib/widgets/bracelet_status_widget.dart`)

El widget ya existente maneja correctamente los estados:
- **Desconectada**: Muestra ícono de Bluetooth deshabilitado con mensaje
- **Conectada**: Muestra ícono verde de Bluetooth conectado
- **Con recordatorio activo**: Muestra ícono naranja con detalles del recordatorio

## Flujo de Funcionamiento

```
┌─────────────────────────────────────────┐
│   App inicia → BraceletService init     │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│   _startConnectionMonitoring()          │
│   Timer.periodic(1 minuto)              │
└──────────────┬──────────────────────────┘
               │
               ▼ (cada 1 minuto)
┌─────────────────────────────────────────┐
│   _checkConnectionHealth()              │
│   • Envía comando STATUS                │
│   • Espera respuesta (timeout 10s)      │
└──────────────┬──────────────────────────┘
               │
       ┌───────┴────────┐
       │                │
       ▼                ▼
┌─────────────┐   ┌──────────────────────┐
│  Respuesta  │   │   Timeout (10s)      │
│   recibida  │   │   Sin respuesta      │
└─────────────┘   └──────────┬───────────┘
       │                     │
       ▼                     ▼
┌─────────────┐   ┌──────────────────────┐
│  Conexión   │   │ _handleConnectionLost│
│   saludable │   │   • Estado = disc.   │
└─────────────┘   │   • Notificación     │
                  │   • Reconexión auto  │
                  └──────────────────────┘
```

## Características del Sistema

### ✅ Detección Automática
- Verificación cada 60 segundos (1 minuto)
- No requiere intervención del usuario
- Funciona en segundo plano

### ⏱️ Timeout Configurable
- Timeout por defecto: 10 segundos
- Suficientemente largo para evitar falsos positivos
- Suficientemente corto para detección rápida

### 🔔 Notificaciones Inmediatas
- Notificación de alta prioridad
- Se muestra incluso con app en segundo plano
- Mensaje claro para el usuario

### 🔄 Reconexión Automática
- Se inicia automáticamente tras detectar desconexión
- Usa el sistema de reconexión existente
- Escanea cada 30 segundos para encontrar la manilla

### 📱 Actualización de UI
- Todas las secciones se actualizan automáticamente
- BraceletStatusWidget refleja estado en tiempo real
- Indicadores visuales claros (colores, íconos)

## Áreas de la App Afectadas

### Pantallas que Muestran Estado
1. **Welcome Screen** - Dashboard principal
2. **Bracelet Control Screen** - Control de manilla
3. **Bracelet Setup Screen** - Configuración inicial
4. **Calendario** - Vista de recordatorios
5. **Historial** - Registro de confirmaciones
6. **Ajustes** - Configuración general

### Widgets Actualizados Automáticamente
- `BraceletStatusWidget` - Widget de estado principal
- `GlobalReminderIndicator` - Indicador global de recordatorios

## Configuración y Constantes

```dart
// Intervalo de verificación
static const Duration _connectionCheckInterval = Duration(minutes: 1);

// Timeout de espera de respuesta
static const Duration _responseTimeout = Duration(seconds: 10);
```

## Registro de Eventos (Logs)

El sistema genera logs detallados para debugging:

```
[CONNECTION_CHECK] 🔍 Sistema de monitoreo de conexión iniciado (cada 1 minuto)
[CONNECTION_CHECK] 🔍 Verificando conexión con la manilla...
[CONNECTION_CHECK] Comando enviado: STATUS
[CONNECTION_CHECK] ✅ Respuesta recibida
[CONNECTION_CHECK] ✅ Conexión saludable
```

En caso de desconexión:
```
[CONNECTION_CHECK] ⚠️ Timeout - No se recibió respuesta
[CONNECTION_CHECK] ⚠️ Manilla no responde - marcando como desconectada
[CONNECTION_CHECK] 🔄 Iniciando reconexión automática...
📢 Notificación de desconexión de manilla enviada
```

## Pruebas Recomendadas

### Test 1: Desconexión Física
1. Conectar la manilla
2. Apagar la manilla físicamente
3. Esperar 1 minuto
4. Verificar que aparece notificación de desconexión
5. Verificar que el estado cambia en todas las secciones

### Test 2: Pérdida de Señal Bluetooth
1. Conectar la manilla
2. Alejar el dispositivo hasta perder señal
3. Esperar 1 minuto
4. Verificar notificación y cambio de estado

### Test 3: Reconexión Automática
1. Provocar desconexión (apagar manilla)
2. Esperar notificación de desconexión
3. Encender manilla nuevamente
4. Verificar reconexión automática (máximo 30 segundos)

### Test 4: Múltiples Desconexiones
1. Conectar y desconectar varias veces
2. Verificar que el sistema mantiene estabilidad
3. Verificar que no hay memory leaks con los timers

## Consideraciones de Batería

El sistema está optimizado para minimizar consumo:
- Verificación cada 1 minuto (no cada segundo)
- Timeout de 10 segundos evita esperas largas
- Timer se cancela correctamente en dispose()
- No mantiene conexiones innecesarias

## Mejoras Futuras Posibles

1. **Intervalo Adaptativo**
   - Aumentar intervalo si la batería está baja
   - Reducir intervalo si hay recordatorios activos próximos

2. **Historial de Desconexiones**
   - Registrar eventos de desconexión en base de datos
   - Generar reportes de estabilidad

3. **Alertas Inteligentes**
   - No notificar si usuario está usando la app activamente
   - Agrupar múltiples desconexiones en una sola notificación

4. **Métricas de Calidad de Conexión**
   - Medir latencia de respuestas
   - Detectar conexiones débiles antes de que fallen

## Troubleshooting

### La verificación no se ejecuta
- Verificar que `_startConnectionMonitoring()` se llama en el constructor
- Verificar logs para confirmar inicio del timer

### Falsos positivos (marca desconectado estando conectado)
- Aumentar `_responseTimeout` si es necesario
- Verificar que `_handleIncomingData` actualiza `_lastSuccessfulResponse`

### No se reciben notificaciones
- Verificar permisos de notificaciones en Android
- Verificar que `NotificationService` está inicializado
- Revisar configuración de canal de notificaciones

## Notas Técnicas

- Los timers se ejecutan en el contexto del servicio singleton
- Las notificaciones usan el plugin `flutter_local_notifications`
- El estado se propaga usando `ChangeNotifier` y `Provider`
- La reconexión usa el sistema BLE de `flutter_blue_plus`

## Conclusión

El sistema de monitoreo proporciona una experiencia confiable para detectar y recuperarse de desconexiones de la manilla, manteniendo al usuario informado en todo momento y tomando acciones automáticas para restablecer la conexión.
