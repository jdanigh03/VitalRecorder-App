# Integración de Manilla BLE - Vital Recorder

## 📋 Resumen

Se ha integrado completamente la funcionalidad de manilla BLE ESP32-C3 en la aplicación Vital Recorder. La manilla utiliza el protocolo Nordic UART Service para comunicación bidireccional y permite enviar notificaciones LED cuando se completan recordatorios.

## 🔧 Arquitectura de la Solución

### Componentes Implementados

1. **Modelo de Datos** (`lib/models/bracelet_device.dart`)
   - `BraceletDevice`: Estado de la manilla
   - `BraceletCommand`: Comandos disponibles 
   - `BraceletResponse`: Respuestas de la manilla
   - `BraceletNotification`: Tipos de notificaciones LED

2. **Servicio BLE** (`lib/services/bracelet_service.dart`)
   - Singleton para gestión centralizada
   - Escaneo y conexión automática
   - Comunicación Nordic UART Service
   - Gestión de notificaciones LED

3. **Pantallas de Usuario**
   - `BraceletSetupScreen`: Configuración inicial
   - `BraceletControlScreen`: Control y debugging
   - Widget integrado en dashboard principal

4. **Permisos y Dependencias**
   - `flutter_blue_plus ^1.32.7`
   - `permission_handler ^11.3.1`
   - Permisos BLE Android/iOS configurados

## 🎯 Funcionalidades

### Conexión BLE
- Escaneo automático de dispositivos "Vital Recorder"
- Conexión usando UUID del servicio Nordic UART
- Gestión automática de reconexión

### Comandos Disponibles
```
LED ON          - Enciende LED
LED OFF         - Apaga LED  
PIN <gpio> <0|1> - Control GPIO
READ <gpio>     - Leer estado GPIO
STATUS          - Estado general
HELP            - Lista de comandos
```

### Notificaciones por Tipo
- **Medicación**: LED constante 3 segundos
- **Ejercicio**: Parpadeo ON/OFF/ON
- **Alerta General**: 3 parpadeos rápidos

## 🚀 Instrucciones de Prueba

### 1. Preparar Hardware
```cpp
// El código Arduino ya está en: manilla_Arduino/manilla_Arduino.ino
// Cargar en ESP32-C3 Super Mini
// Nombre del dispositivo: "Vital Recorder"
// LED en pin 3 (configurable)
```

### 2. Instalar Dependencias
```bash
flutter pub get
```

### 3. Prueba de Conexión

1. **Abrir la aplicación** y navegar al dashboard
2. **Ver widget de manilla** en la sección superior
3. **Tap en "Configurar Manilla"** si no conectada
4. **Buscar dispositivos** - debe aparecer "Vital Recorder"
5. **Conectar** - debe mostrar "Conectado exitosamente"

### 4. Prueba de Comandos

1. **Navegar a pantalla de control** (tap en widget conectado)
2. **Probar LED ON/OFF** - debe encender/apagar LED físico
3. **Enviar comando STATUS** - ver respuesta en log
4. **Simular alerta** - debe parpadear LED

### 5. Prueba de Notificaciones

1. **Crear un recordatorio** en la app
2. **Marcar como completado** - debe activar LED según tipo:
   - Medicamento → LED constante
   - Ejercicio → Parpadeo especial
   - Otros → Parpadeos rápidos

## 🐛 Debugging

### Log de Debugging
```dart
// En BraceletService se registran estos eventos:
print("Dispositivo manilla encontrado: $name");
print("Conectado exitosamente a la manilla");  
print("Respuesta recibida: $response");
print("Comando enviado: $command");
```

### Verificación de Estados
```dart
// Verificar conexión
BraceletService().isConnected

// Ver dispositivo actual  
BraceletService().connectedDevice

// Stream de respuestas
BraceletService().responseStream.listen((response) {
  print("Respuesta: ${response.response}");
});
```

### Problemas Comunes

1. **No encuentra dispositivo**
   - Verificar que ESP32 esté encendido
   - Verificar permisos de ubicación/Bluetooth
   - Verificar nombre "Vital Recorder" en código Arduino

2. **No se conecta**
   - Verificar UUIDs del servicio Nordic UART
   - Verificar que características estén disponibles
   - Revisar logs de conexión

3. **Comandos no responden**
   - Verificar formato de comandos (terminar con \r\n)
   - Verificar que características estén suscritas
   - Verificar baud rate (115200)

## 📱 Uso en Producción

### Configuración Recomendada
```dart
// En BraceletService, ajustar timeouts según necesidad:
static const Duration SCAN_TIMEOUT = Duration(seconds: 15);
static const Duration CONNECT_TIMEOUT = Duration(seconds: 15);
static const Duration COMMAND_TIMEOUT = Duration(seconds: 5);
```

### Gestión de Errores
- Errores de conexión no bloquean la app
- Notificaciones de manilla son opcionales
- Reconexión automática implementada

### Optimización de Batería
```cpp
// En código Arduino, añadir sleep modes:
esp_sleep_enable_timer_wakeup(30 * 1000000); // 30 segundos
esp_light_sleep_start();
```

## ✅ Estado de Implementación

- ✅ Modelo de datos completo
- ✅ Servicio BLE funcional  
- ✅ Pantallas de configuración
- ✅ Integración en dashboard
- ✅ Notificaciones automáticas
- ✅ Permisos configurados
- ⏳ Pruebas con hardware físico

## 🔄 Próximas Mejoras

1. **Notificaciones Push**: Enviar notificaciones cuando se acerca hora de recordatorio
2. **Gestión de Batería**: Mostrar nivel de batería de la manilla
3. **Configuración Avanzada**: Personalizar patrones de LED
4. **Historial**: Registro de actividad de la manilla
5. **Múltiples Dispositivos**: Soporte para varios ESP32

---

La integración está **lista para usar** y **probada funcionalmente**. Solo falta validación con el hardware ESP32-C3 físico.
