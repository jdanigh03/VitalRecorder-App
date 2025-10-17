# Configuración del Botón Físico - ESP32-C3 Super Mini

## 🔧 **Configuración de Hardware**

La funcionalidad del botón físico permite confirmar recordatorios directamente desde la manilla sin necesidad de usar el celular.

### **Opciones de Pin para el Botón:**

#### **Configuración para ESP32-C3 Super Mini (Verificado)**
```cpp
#define LED_PIN 8       // LED onboard ESP32-C3 Super Mini (GPIO 8, lógica invertida)
#define BUTTON_PIN 9    // Botón BOOT ESP32-C3 Super Mini (GPIO 9)
#define LED_INVERTED true  // El LED integrado tiene lógica invertida
```
- **Ventajas**: Configuración correcta para ESP32-C3 Super Mini
- **Características**: 
  - Botón en GPIO9 con pull-up interno
  - LED en GPIO8 con lógica invertida (LOW = encendido)
  - Compatible con pantalla OLED en GPIO8/9 para I2C

### **¿Cómo determinar qué pin usar?**

1. **Método 1 - Prueba física:**
   - Mira tu ESP32-C3 Super Mini
   - Localiza el botón físico (generalmente marcado como "BOOT")
   - Usa un multímetro para probar continuidad entre el botón y los pines

2. **Método 2 - Prueba de software:**
   - Usa el código con GPIO0 primero
   - Si no funciona, cambia a GPIO9
   - Compila y prueba la funcionalidad

3. **Método 3 - Monitor serial:**
   - El código muestra en el monitor serial: `Botón físico configurado en GPIO0`
   - Presiona el botón y verifica si se activa durante un recordatorio

## 🚀 **Cómo Funciona**

### **Flujo de Confirmación por Botón:**

1. **Se activa un recordatorio:**
   - LED parpadea
   - Pantalla muestra el recordatorio
   - Arduino envía `REMINDER_ACTIVATED <index>` a la app

2. **Usuario presiona el botón físico:**
   - Arduino detecta la pulsación (con debounce)
   - Completa el recordatorio localmente
   - Apaga LED y limpia pantalla
   - Envía `REMINDER_COMPLETED_BY_BUTTON <index>` a la app

3. **La app recibe la confirmación:**
   - BraceletService procesa el comando
   - Marca el recordatorio como completado en Firestore
   - Actualiza la UI automáticamente

### **Estados del Sistema:**

- **🔴 Sin recordatorios activos**: LED apagado, botón sin efecto
- **🟠 Recordatorio activo**: LED parpadeando, botón funcional
- **🟢 Recordatorio completado**: LED apagado, mensaje "Completado!"

## 🛠️ **Configuración en el Código**

En `manilla_Arduino.ino`, líneas 13-15:

```cpp
// Configuración para ESP32-C3 Super Mini (basado en ejemplo de Grok)
#define LED_PIN 8       // LED onboard ESP32-C3 Super Mini (GPIO 8, lógica invertida)
#define BUTTON_PIN 9    // Botón BOOT ESP32-C3 Super Mini (GPIO 9)
#define LED_INVERTED true  // El LED integrado tiene lógica invertida (LOW = encendido)
```

### **Si tienes conflictos con I2C:**

Si usas GPIO9 para el botón y también para I2C (pantalla OLED), considera:

1. **Opción A**: Usar GPIO0 para el botón
2. **Opción B**: Cambiar los pines I2C de la pantalla
3. **Opción C**: Usar un pin libre (GPIO1, GPIO2, etc.)

## 📱 **Integración con la App**

### **Widgets disponibles:**

```dart
// Mostrar estado de recordatorios activos
BraceletStatusWidget(),

// Botón para completar desde la app
CompleteReminderButton(),
```

### **Estado en tiempo real:**

La app mantiene el estado sincronizado:
- `braceletService.hasActiveReminder` - Si hay recordatorio activo
- `braceletService.activeReminderTitle` - Título del recordatorio activo
- `braceletService.activeReminderIndex` - Índice para completar desde app

## 🔍 **Troubleshooting**

### **El botón no responde:**

1. **Verificar pin**: ¿Estás usando el GPIO correcto?
2. **Verificar conexión**: ¿El botón tiene continuidad?
3. **Verificar estado**: ¿Hay un recordatorio activo?
4. **Verificar monitor serial**: ¿Aparecen mensajes de debug?

### **Conflicto con otros componentes:**

1. **I2C OLED**: Si usas GPIO9, podría haber conflicto
2. **Programación**: GPIO0 puede interfierir con la carga del programa
3. **Pull-up**: El código usa `INPUT_PULLUP` interno

### **Comandos de debug:**

```
// Desde la app hacia Arduino:
SIMULATE_ALERT          // Activar alerta de prueba
STATUS                  // Verificar estado
HELP                    // Ver comandos disponibles

// Desde Arduino hacia app:
REMINDER_ACTIVATED 0    // Se activó recordatorio índice 0
REMINDER_COMPLETED_BY_BUTTON 0  // Completado por botón físico
```

## ✅ **Verificación de Funcionamiento**

1. **Conecta la manilla** a la app
2. **Sincroniza recordatorios** 
3. **Espera** a que se active un recordatorio (o usa `SIMULATE_ALERT`)
4. **Presiona el botón físico** en la manilla
5. **Verifica** que el LED se apague y la app marque como completado

¡La funcionalidad está lista y completamente integrada! 🎉