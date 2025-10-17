# 🧪 **Instrucciones para Probar el Botón Físico**

## 📋 **Pasos para la Prueba**

### **1. 🔧 Preparación**
1. Asegúrate de que la **manilla esté conectada** a la app
2. Ve a **"Control de Manilla"** en la app
3. Verifica que aparezca **"Conectado"** en la tarjeta superior

### **2. 🎯 Método de Prueba A: Leer Estado del Botón**

1. **En la app**, presiona el botón **"Leer Estado Botón (GPIO9)"**
2. **Mantén presionado** el botón físico en la manilla (GPIO9)
3. **Mientras mantienes presionado**, presiona de nuevo **"Leer Estado Botón (GPIO9)"** en la app
4. **En los logs** deberías ver:
   ```
   OK read 9 = 1    (botón no presionado)
   OK read 9 = 0    (botón presionado)
   ```

### **3. 🚨 Método de Prueba B: Con Recordatorio Activo**

1. **Simular alerta**: Presiona **"Simular Alerta"** en la app
2. **Verificar en logs**: Deberías ver algo como:
   ```
   OK SIMULATING_ALERT
   ```
3. **Presionar botón físico** en la manilla (GPIO9)
4. **En los logs** deberías ver inmediatamente:
   ```
   OK BUTTON_PRESSED
   OK REMINDER_COMPLETED_BY_BUTTON 0 "Alerta Simulada"
   ```

### **4. 🔄 Método de Prueba C: Con Recordatorio Real**

1. **Crear recordatorio** para la hora actual + 1 minuto
2. **Sincronizar recordatorios** (botón "Sincronizar Recordatorios")
3. **Esperar** a que se active el recordatorio
4. **En logs** verás:
   ```
   OK REMINDER_ACTIVATED 0 "Tu Recordatorio" 20:XX
   ```
5. **Presionar botón físico** en la manilla
6. **En logs** deberías ver:
   ```
   OK BUTTON_PRESSED
   OK REMINDER_COMPLETED_BY_BUTTON 0 "Tu Recordatorio"
   ```

## 📊 **Mensajes que Esperamos Ver en los Logs**

### **✅ Cuando Funciona Correctamente:**

```bash
# Al activarse un recordatorio:
[10:23:45] OK REMINDER_ACTIVATED 0 "testprueba" 20:56

# Al presionar el botón:
[10:23:50] OK BUTTON_PRESSED
[10:23:50] OK REMINDER_COMPLETED_BY_BUTTON 0 "testprueba"

# Al leer el botón sin presionar:
[10:24:00] OK read 9 = 1

# Al leer el botón presionado:
[10:24:05] OK read 9 = 0
```

### **🔍 Si No Funciona:**

```bash
# Si no hay recordatorio activo:
[10:25:00] OK BUTTON_PRESSED
[10:25:00] INFO NO_ACTIVE_REMINDER

# Si el botón no responde:
# (No aparece nada en los logs al presionarlo)
```

## 🛠️ **Troubleshooting**

### **❌ Problema: No aparece nada al presionar el botón**
- **Verificar conexión**: ¿La manilla está conectada?
- **Verificar GPIO**: ¿Estás presionando el botón correcto?
- **Verificar configuración**: ¿El código usa `BUTTON_PIN 9`?

### **❌ Problema: Aparece `read 9 = 1` siempre**
- **Pull-up funciona**: El botón está configurado correctamente
- **Conexión**: Posible problema con el botón físico o pin

### **❌ Problema: Aparece `read 9 = 0` siempre**
- **Posible cortocircuito**: El pin puede estar conectado a GND permanentemente
- **Hardware**: Revisar conexión del botón

## 🎉 **Resultado Exitoso**

Si ves estos mensajes en los logs de la app cuando presionas el botón físico:

```
[HH:MM:SS] OK BUTTON_PRESSED
[HH:MM:SS] OK REMINDER_COMPLETED_BY_BUTTON X "Nombre del Recordatorio"
```

**¡El botón físico está funcionando perfectamente!** ✨

## 📱 **Dónde Ver los Logs**

1. **Abrir la app** VitalRecorder
2. **Navegar** a la pantalla de "Control de Manilla"
3. **Scroll hacia abajo** hasta "Log de Respuestas"
4. **Observar** los mensajes en tiempo real con timestamps

Los logs se actualizan **automáticamente** cuando la manilla envía cualquier mensaje al celular.