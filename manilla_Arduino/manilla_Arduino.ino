// ===== ESP32-C3 Super Mini - Vital Recorder v2.0 =====
// Compatible con nuevo sistema de confirmaciones individuales
// Requiere Arduino-ESP32 (core >= 2.0.x) con NimBLE-Arduino

#include <NimBLEDevice.h>
#include <U8g2lib.h>
#include <time.h>

// ---------- Configuración ----------
#define DEVICE_NAME "Vital Recorder v2"

// Configuración para ESP32-C3 Super Mini
#define LED_PIN 8         // LED onboard (GPIO 8, lógica invertida)
#define VIBRATION_PIN 3   // Motor de vibración (GPIO 3)
#define BUTTON_PIN 2      // Botón externo en GPIO2
#define LED_INVERTED true

// Configuración de la pantalla OLED (SSD1306/SSD1315)
#ifdef U8X8_HAVE_HW_I2C
#include <Wire.h>
#endif
U8G2_SSD1306_128X64_NONAME_F_HW_I2C u8g2(U8G2_R0, /* clock=*/ 9, /* data=*/ 8, /* reset=*/ U8X8_PIN_NONE);

// UUIDs Nordic UART Service (NUS)
static BLEUUID NUS_SERVICE_UUID("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
static BLEUUID NUS_RX_UUID("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");  // Write
static BLEUUID NUS_TX_UUID("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");  // Notify

// ---------- Globals BLE ----------
NimBLEServer* pServer = nullptr;
NimBLEService* pService = nullptr;
NimBLECharacteristic* pTxChar = nullptr;
NimBLECharacteristic* pRxChar = nullptr;
NimBLEAdvertising* pAdvertising = nullptr;

volatile bool deviceConnected = false;
volatile bool showSyncConfirmation = false;
volatile bool justConnected = false;
volatile bool justDisconnected = false;

// Control de alertas y recordatorios activos
uint32_t alertUntil = 0;
int activeReminderId = -1;
bool reminderActive = false;
uint32_t ledBlinkTime = 0;
bool ledState = false;
bool vibrationState = false;

// Control de heartbeat para mantener conexión activa
uint32_t lastHeartbeatTime = 0;
const uint32_t HEARTBEAT_INTERVAL = 30000; // 30 segundos

// ---------- Lógica de Recordatorios v2 ----------
// Ahora cada recordatorio representa una OCURRENCIA específica
const int MAX_REMINDERS = 20;  // Aumentado para manejar más ocurrencias
struct Reminder {
  uint8_t hour;
  uint8_t minute;
  char title[30];        // Título más largo
  char reminderId[36];   // UUID del recordatorio (para sync con Firestore)
  char occurrenceId[50]; // ID único de la ocurrencia (formato: reminderId_scheduledTime)
  bool confirmed;        // Si fue confirmado desde la manilla
  bool synced;          // Si ya fue sincronizado con la app
  uint32_t scheduledTime; // Timestamp de la hora programada
};

Reminder reminders[MAX_REMINDERS];
int reminderCount = 0;

// Tiempo Unix (segundos desde 1970-01-01)
time_t deviceClock = 0;

// Variables para el manejo del botón
bool lastButtonState = HIGH;
uint32_t lastButtonChangeTime = 0;
uint32_t lastStatusTime = 0;

// Dibuja una o dos líneas de texto en la pantalla
void displayMessage(const char* line1, const char* line2 = "") {
  u8g2.clearBuffer();
  u8g2.setFont(u8g2_font_ncenB10_tr);
  int16_t y = 35;
  if (line2 && strlen(line2) > 0) {
    y = 25;
  }
  u8g2.drawStr((128 - u8g2.getStrWidth(line1)) / 2, y, line1);
  if (line2 && strlen(line2) > 0) {
    u8g2.drawStr((128 - u8g2.getStrWidth(line2)) / 2, y + 20, line2);
  }
  u8g2.sendBuffer();
}

// Utilidad: enviar una línea al cliente BLE
void bleSendLine(const String& s) {
  if (!deviceConnected || pTxChar == nullptr) {
    Serial.printf("[BLE] No conectado: %s\n", s.c_str());
    return;
  }
  
  Serial.printf("[BLE] Enviando: %s\n", s.c_str());
  pTxChar->setValue((uint8_t*)s.c_str(), s.length());
  pTxChar->notify();
}

// Función helper para controlar LED
void setLED(bool state) {
  if (LED_INVERTED) {
    digitalWrite(LED_PIN, state ? LOW : HIGH);
  } else {
    digitalWrite(LED_PIN, state ? HIGH : LOW);
  }
}

// Función helper para controlar motor de vibración
void setVibration(bool state) {
  digitalWrite(VIBRATION_PIN, state ? HIGH : LOW);
  vibrationState = state;
}

void setupButton() {
  Serial.printf("[SETUP] Configurando botón en GPIO%d\n", BUTTON_PIN);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  Serial.println("[SETUP] Botón listo");
}

// Manejar presión de botón
void onButtonPressed() {
  Serial.println("[BUTTON] Procesando presión...");
  bleSendLine("OK BUTTON_PRESSED\r\n");
  
  if (reminderActive && activeReminderId >= 0) {
    Serial.printf("[BUTTON] Confirmando recordatorio ID %d\n", activeReminderId);
    
    // Confirmar el recordatorio
    confirmReminder(activeReminderId);
  } else {
    Serial.println("[BUTTON] No hay recordatorio activo");
    bleSendLine("INFO NO_REMINDER\r\n");
  }
}

// Confirmar recordatorio activo desde la manilla
void confirmReminder(int remIndex) {
  if (remIndex == activeReminderId && remIndex >= 0 && remIndex < reminderCount) {
    Serial.printf("[REM] Confirmando recordatorio ID %d\n", remIndex);
    
    // Marcar como confirmado
    reminders[remIndex].confirmed = true;
    reminders[remIndex].synced = false; // Pendiente de sincronizar con app
    
    // Apagar LED, vibración y limpiar estado
    setLED(false);
    setVibration(false);
    reminderActive = false;
    activeReminderId = -1;
    alertUntil = 0;
    
    // Notificar a la app con detalles completos de la confirmación
    String msg = "OK REMINDER_CONFIRMED ";
    msg += String(remIndex) + " ";
    msg += "\"" + String(reminders[remIndex].reminderId) + "\" ";
    msg += "\"" + String(reminders[remIndex].occurrenceId) + "\" ";
    msg += String(reminders[remIndex].scheduledTime) + " ";
    msg += "\"" + String(reminders[remIndex].title) + "\"";
    bleSendLine(msg + "\r\n");
    
    displayMessage("Confirmado!", "");
    delay(2000);
    Serial.println("[REM] Confirmación registrada");
  }
}

// Activar recordatorio
void activateReminder(int remIndex) {
  if (remIndex >= 0 && remIndex < reminderCount && !reminders[remIndex].confirmed) {
    activeReminderId = remIndex;
    reminderActive = true;
    
    displayMessage("Recordatorio:", reminders[remIndex].title);
    setLED(true);
    setVibration(true);
    ledBlinkTime = millis();
    
    // Timeout de 5 minutos para auto-marcar como omitido
    alertUntil = millis() + 300000;
    
    Serial.print("[REM] Activando: ");
    Serial.println(reminders[remIndex].title);
    
    // Notificar a la app que se activó un recordatorio
    String msg = "OK REMINDER_ACTIVATED ";
    msg += String(remIndex) + " ";
    msg += "\"" + String(reminders[remIndex].title) + "\" ";
    msg += String(reminders[remIndex].hour) + ":" + String(reminders[remIndex].minute);
    bleSendLine(msg + "\r\n");
  }
}

// ---------- Callbacks de conexión ----------
class ServerCallbacks : public NimBLEServerCallbacks {
public:
  void onConnect(NimBLEServer* s) {
    deviceConnected = true;
    justConnected = true;
    lastHeartbeatTime = millis(); // Reset heartbeat al conectar
    Serial.println("[BLE] ✅ *** CONEXIÓN ESTABLECIDA ***");
    bleSendLine("OK CONNECTED v2.0\r\n");
    
    // Enviar confirmaciones pendientes de sincronizar
    delay(1000);
    syncPendingConfirmations();
  }

  void onConnect(NimBLEServer* s, ble_gap_conn_desc*) {
    deviceConnected = true;
    justConnected = true;
    Serial.println("[BLE] Conectado");
    bleSendLine("OK CONNECTED\r\n");
  }

  void onDisconnect(NimBLEServer* s) {
    deviceConnected = false;
    justDisconnected = true;
    Serial.println("[BLE] 🔴 Desconectado, reanudando advertising...");
    NimBLEDevice::startAdvertising();
    lastHeartbeatTime = 0; // Reset heartbeat
  }

private:
  void syncPendingConfirmations() {
    int pendingCount = 0;
    for (int i = 0; i < reminderCount; i++) {
      if (reminders[i].confirmed && !reminders[i].synced) {
        // Enviar confirmación pendiente
        String msg = "PENDING_CONFIRMATION ";
        msg += "\"" + String(reminders[i].reminderId) + "\" ";
        msg += "\"" + String(reminders[i].occurrenceId) + "\" ";
        msg += String(reminders[i].scheduledTime);
        bleSendLine(msg + "\r\n");
        
        reminders[i].synced = true;
        pendingCount++;
        delay(100); // Pequeña pausa entre mensajes
      }
    }
    if (pendingCount > 0) {
      Serial.printf("[BLE] %d confirmaciones sincronizadas\n", pendingCount);
    }
  }
};

// ---------- Callback para RX ----------
class RxCallbacks : public NimBLECharacteristicCallbacks {
public:
  void onWrite(NimBLECharacteristic* ch) {
    std::string rx = ch->getValue();
    if (rx.empty()) return;
    handleCommand(String(rx.c_str()));
  }

  void onWrite(NimBLECharacteristic* ch, NimBLEConnInfo&) {
    std::string rx = ch->getValue();
    if (rx.empty()) return;
    handleCommand(String(rx.c_str()));
  }

private:
  void handleCommand(String cmd) {
    cmd.trim();
    Serial.print("[BLE RX] ");
    Serial.println(cmd);
    
    if (!deviceConnected) {
      deviceConnected = true;
      Serial.println("[BLE] Conexión detectada via RX");
    }

    String up = cmd;
    up.toUpperCase();

    if (up.startsWith("PIN ")) {
      int pin = -1, val = -1;
      if (sscanf(cmd.c_str(), "PIN %d %d", &pin, &val) == 2 && pin >= 0) {
        pinMode(pin, OUTPUT);
        digitalWrite(pin, val ? HIGH : LOW);
        bleSendLine("OK PIN " + String(pin) + " = " + String(val) + "\r\n");
      } else {
        bleSendLine("ERR USAGE: PIN <gpio> <0|1>\r\n");
      }
    } else if (up.startsWith("READ ")) {
      int pin = -1;
      if (sscanf(cmd.c_str(), "READ %d", &pin) == 1 && pin >= 0) {
        pinMode(pin, INPUT_PULLUP);
        int v = digitalRead(pin);
        bleSendLine("OK READ " + String(pin) + " = " + String(v) + "\r\n");
      } else {
        bleSendLine("ERR USAGE: READ <gpio>\r\n");
      }
    } else if (up.startsWith("SYNC_TIME ")) {
      // SYNC_TIME <timestamp_local>
      time_t timestamp = 0;
      if (sscanf(cmd.substring(10).c_str(), "%ld", &timestamp) == 1 && timestamp > 0) {
        deviceClock = timestamp;
        bleSendLine("OK TIME_SYNCED\r\n");
        Serial.printf("[TIME] Sincronizado: %ld\n", timestamp);
      } else {
        bleSendLine("ERR INVALID_TIMESTAMP\r\n");
      }
    } else if (up == "REM_CLEAR") {
      reminderCount = 0;
      bleSendLine("OK REM_CLEARED\r\n");
      Serial.println("[REM] Recordatorios borrados");
    } else if (up.startsWith("REM_ADD ")) {
      // REM_ADD HH:MM "Title" "ReminderId" "OccurrenceId" <ScheduledTimestamp>
      if (reminderCount >= MAX_REMINDERS) {
        bleSendLine("ERR REM_FULL\r\n");
        return;
      }
      
      // Parsear comando más complejo
      int hour, minute;
      char title[30], remId[36], occId[50];
      uint32_t schedTime;
      
      // Formato simplificado: REM_ADD HH:MM "Title"
      int firstQuote = cmd.indexOf('"');
      int secondQuote = cmd.indexOf('"', firstQuote + 1);
      
      if (firstQuote > 0 && secondQuote > firstQuote) {
        String timeStr = cmd.substring(8, firstQuote);
        timeStr.trim();
        String titleStr = cmd.substring(firstQuote + 1, secondQuote);
        
        if (sscanf(timeStr.c_str(), "%d:%d", &hour, &minute) == 2) {
          reminders[reminderCount].hour = hour;
          reminders[reminderCount].minute = minute;
          strncpy(reminders[reminderCount].title, titleStr.c_str(), 29);
          reminders[reminderCount].title[29] = '\0';
          reminders[reminderCount].confirmed = false;
          reminders[reminderCount].synced = true;
          reminders[reminderCount].scheduledTime = deviceClock;
          
          // Generar IDs temporales si no se proporcionan
          snprintf(reminders[reminderCount].reminderId, 36, "REM_%d", reminderCount);
          snprintf(reminders[reminderCount].occurrenceId, 50, "OCC_%d_%d", reminderCount, hour * 60 + minute);
          
          reminderCount++;
          bleSendLine("OK REM_ADDED\r\n");
          showSyncConfirmation = true;
          Serial.printf("[REM] Añadido: %02d:%02d %s\n", hour, minute, titleStr.c_str());
          return;
        }
      }
      bleSendLine("ERR REM_FORMAT\r\n");
    } else if (up.startsWith("REM_CONFIRM ")) {
      // REM_CONFIRM <index>
      int remIndex = -1;
      if (sscanf(cmd.substring(12).c_str(), "%d", &remIndex) == 1 && remIndex >= 0 && remIndex < reminderCount) {
        confirmReminder(remIndex);
        bleSendLine("OK REM_CONFIRMED\r\n");
      } else {
        bleSendLine("ERR INVALID_REM_INDEX\r\n");
      }
    } else if (up == "SIMULATE_ALERT") {
      // Simular alerta para pruebas
      activeReminderId = 0;
      reminderActive = true;
      
      if (reminderCount == 0) {
        strncpy(reminders[0].title, "Test Alert", 29);
        reminders[0].title[29] = '\0';
        reminders[0].hour = 12;
        reminders[0].minute = 0;
        reminders[0].confirmed = false;
        reminderCount = 1;
      }
      
      displayMessage("Recordatorio:", reminders[0].title);
      setLED(true);
      ledBlinkTime = millis();
      
      Serial.println("[SIMULATE] Alert activo");
      bleSendLine("OK SIMULATING_ALERT\r\n");
    } else if (up == "GET_PENDING") {
      // Obtener confirmaciones pendientes de sincronizar
      int pending = 0;
      for (int i = 0; i < reminderCount; i++) {
        if (reminders[i].confirmed && !reminders[i].synced) {
          pending++;
        }
      }
      bleSendLine("PENDING_COUNT " + String(pending) + "\r\n");
    } else if (up == "STATUS") {
      // Respuesta inmediata al comando STATUS para verificación de conexión
      String response = "OK STATUS v2.0";
      if (deviceClock > 0) {
        struct tm* timeinfo = gmtime(&deviceClock);
        char timeStr[20];
        sprintf(timeStr, " %02d:%02d:%02d", timeinfo->tm_hour, timeinfo->tm_min, timeinfo->tm_sec);
        response += String(timeStr);
      }
      response += " REM:" + String(reminderCount);
      response += " CONN:" + String(deviceConnected ? "YES" : "NO");
      bleSendLine(response + "\r\n");
      Serial.println("[STATUS] Respuesta enviada");
    } else if (up == "PING") {
      // Comando simple para verificación rápida de conexión
      bleSendLine("PONG\r\n");
      Serial.println("[PING] Pong enviado");
    } else if (up == "HELP") {
      bleSendLine("CMDS v2:\r\n  PIN <gpio> <0|1>\r\n  READ <gpio>\r\n  SYNC_TIME <ts>\r\n  REM_CLEAR\r\n  REM_ADD HH:MM \"Title\"\r\n  REM_CONFIRM <idx>\r\n  GET_PENDING\r\n  STATUS\r\n  PING\r\n");
    } else {
      bleSendLine("ECHO: " + cmd + "\r\n");
    }
  }
};

void startAdvertising() {
  if (!pAdvertising) return;
  pAdvertising->addServiceUUID(NUS_SERVICE_UUID);
  NimBLEDevice::startAdvertising();
  Serial.println("[BLE] Advertising iniciado");
}

void setup() {
  pinMode(LED_PIN, OUTPUT);
  pinMode(VIBRATION_PIN, OUTPUT);
  setLED(false);
  setVibration(false);
  
  Serial.begin(115200);
  delay(500);
  
  setupButton();
  
  Serial.println();
  Serial.println("=== Vital Recorder v2.0 ===");
  Serial.printf("LED: GPIO%d (%s)\n", LED_PIN, LED_INVERTED ? "invertido" : "normal");
  Serial.printf("Vibración: GPIO%d\n", VIBRATION_PIN);

  u8g2.begin();
  displayMessage("Iniciando...", "v2.0");
  delay(1500);
  
  NimBLEDevice::init(DEVICE_NAME);
  NimBLEDevice::setPower(ESP_PWR_LVL_P9);
  pServer = NimBLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());
  pService = pServer->createService(NUS_SERVICE_UUID);
  pTxChar = pService->createCharacteristic(NUS_TX_UUID, NIMBLE_PROPERTY::NOTIFY);
  pRxChar = pService->createCharacteristic(NUS_RX_UUID, NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR);
  pRxChar->setCallbacks(new RxCallbacks());
  pService->start();
  pAdvertising = NimBLEDevice::getAdvertising();
  startAdvertising();
  
  displayMessage("Esperando...", "(BLE)");
  Serial.println("[BLE] Dispositivo: " + String(DEVICE_NAME));
  Serial.println("[BLE] Listo");
}

void loop() {
  static uint32_t lastSecond = 0;
  static uint32_t lastDisplayUpdate = 0;
  static uint32_t lastDayReset = 0;
  uint32_t now = millis();
  
  // Heartbeat automático cada 30 segundos cuando está conectado
  if (deviceConnected && (now - lastHeartbeatTime > HEARTBEAT_INTERVAL)) {
    lastHeartbeatTime = now;
    // Enviar heartbeat silencioso (no se muestra en logs normales)
    if (pTxChar != nullptr) {
      String heartbeat = "HEARTBEAT ";
      if (deviceClock > 0) {
        struct tm* timeinfo = gmtime(&deviceClock);
        char timeStr[10];
        sprintf(timeStr, "%02d:%02d:%02d", timeinfo->tm_hour, timeinfo->tm_min, timeinfo->tm_sec);
        heartbeat += String(timeStr);
      }
      pTxChar->setValue((uint8_t*)heartbeat.c_str(), heartbeat.length());
      pTxChar->notify();
      Serial.println("[HEARTBEAT] Enviado");
    }
  }

  // Estado cada 5 segundos (reducido para menos spam en logs)
  if (millis() - lastStatusTime > 5000) {
    bool currentState = digitalRead(BUTTON_PIN);
    Serial.printf("[STATUS] BTN=%s | BLE=%s | REM=%s | CLOCK=%s\n", 
                  currentState ? "UP" : "DOWN",
                  deviceConnected ? "ON" : "OFF",
                  reminderActive ? "ACTIVE" : "IDLE",
                  deviceClock > 0 ? "SYNC" : "NOSYNC");
    lastStatusTime = millis();
    
    // Detectar pérdida de conexión
    if (deviceConnected && pServer && pServer->getConnectedCount() == 0) {
      Serial.println("[BLE] ⚠️ Conexión perdida detectada");
      deviceConnected = false;
      justDisconnected = true;
      // Reiniciar advertising para permitir reconexiones
      NimBLEDevice::startAdvertising();
      Serial.println("[BLE] Advertising reiniciado para reconexionar");
      displayMessage("Desconectado", "Reconectando...");
    }
  }
  
  // Detectar botón
  bool currentState = digitalRead(BUTTON_PIN);
  if (currentState != lastButtonState && (millis() - lastButtonChangeTime > 50)) {
    lastButtonState = currentState;
    lastButtonChangeTime = millis();
    
    if (currentState == LOW) {
      Serial.println("[BUTTON] *** PRESS ***");
      onButtonPressed();
    }
  }

  // Manejo de conexión
  if (justConnected) {
    justConnected = false;
    displayMessage("Conectado", "");
    lastDisplayUpdate = 0;
  }
  if (justDisconnected) {
    justDisconnected = false;
    displayMessage("Desconectado", "Reconectando...");
    delay(1000);
    // Asegurarse de que el advertising está activo
    if (!deviceConnected) {
      displayMessage("Esperando...", "(BLE)");
    }
  }

  // Incrementar reloj
  if (now - lastSecond >= 1000) {
    lastSecond += 1000;
    if (deviceClock > 0) {
      deviceClock++;
    }
  }

  // Reset diario de confirmaciones (medianoche)
  if (deviceClock > 0) {
    struct tm* timeinfo = gmtime(&deviceClock);
    if (timeinfo->tm_hour == 0 && timeinfo->tm_min == 0 && timeinfo->tm_sec < 5) {
      if (now - lastDayReset > 10000) {
        for (int i = 0; i < reminderCount; i++) {
          reminders[i].confirmed = false;
        }
        lastDayReset = now;
        Serial.println("[REM] Reset diario");
      }
    }
  }

  // Recordatorio activo (prioridad)
  if (reminderActive && activeReminderId >= 0) {
    // Timeout de 5 minutos
    if (now >= alertUntil) {
      Serial.println("[REM] Timeout - marcando como omitido");
      
      String msg = "INFO REMINDER_MISSED ";
      msg += String(activeReminderId) + " ";
      msg += "\"" + String(reminders[activeReminderId].reminderId) + "\"";
      bleSendLine(msg + "\r\n");
      
      // Limpiar estado sin confirmar
      setLED(false);
      setVibration(false);
      reminderActive = false;
      activeReminderId = -1;
      alertUntil = 0;
      return;
    }
    
    // Parpadear LED y vibración sincronizados
    if (now - ledBlinkTime > 500) {
      ledState = !ledState;
      setLED(ledState);
      setVibration(ledState);
      ledBlinkTime = now;
    }
    
    delay(10);
    return;
  }

  // Alertas temporales
  if (!reminderActive) {
    if (showSyncConfirmation) {
      showSyncConfirmation = false;
      displayMessage("Sincronizado", "");
      alertUntil = now + 2000;
      return;
    }

    if (now < alertUntil) {
      return;
    }
    
    if (alertUntil > 0) {
      setLED(false);
      alertUntil = 0;
      lastDisplayUpdate = 0;
    }
  }

  // Chequear recordatorios
  if (deviceClock > 0) {
    struct tm* timeinfo = gmtime(&deviceClock);
    for (int i = 0; i < reminderCount; i++) {
      if (timeinfo->tm_hour == reminders[i].hour && 
          timeinfo->tm_min == reminders[i].minute && 
          timeinfo->tm_sec < 5 && 
          !reminders[i].confirmed) {
        
        activateReminder(i);
        return;
      }
    }
  }

  // Pantalla por defecto
  if (now - lastDisplayUpdate > 15000 || lastDisplayUpdate == 0) {
    lastDisplayUpdate = now;
    if (deviceClock > 0) {
      char timeStr[6];
      struct tm* timeinfo = gmtime(&deviceClock);
      sprintf(timeStr, "%02d:%02d", timeinfo->tm_hour, timeinfo->tm_min);
      displayMessage("VitalRecorder", timeStr);
    } else {
      if (deviceConnected) {
        displayMessage("Conectado", "Sync...");
      } else {
        displayMessage("VitalRecorder", "v2.0");
      }
    }
  }
  
  delay(10);
}
