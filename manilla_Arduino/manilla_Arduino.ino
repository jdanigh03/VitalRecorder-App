// ===== ESP32-C3 Super Mini - "Serial BLE" tipo Nordic UART (compat) =====
// Requiere Arduino-ESP32 (core >= 2.0.x) con NimBLE-Arduino (incluido).
// Herramientas -> Placa: "ESP32C3 Dev Module" (o equivalente).

#include <NimBLEDevice.h>
#include <U8g2lib.h>
#include <time.h>

// ---------- Configuración ----------
#define DEVICE_NAME "Vital Recorder"

// Configuración para ESP32-C3 Super Mini - SIMPLE
#define LED_PIN 8       // LED onboard ESP32-C3 Super Mini (GPIO 8, lógica invertida)
#define BUTTON_PIN 2    // Botón externo en GPIO2 (pin seguro sin conflictos)
#define LED_INVERTED true  // El LED integrado tiene lógica invertida (LOW = encendido)

// Configuración de la pantalla OLED (SSD1306/SSD1315) - OPCIONAL
// Si no tienes pantalla, comenta estas líneas
#ifdef U8X8_HAVE_HW_I2C
#include <Wire.h>
#endif
U8G2_SSD1306_128X64_NONAME_F_HW_I2C u8g2(U8G2_R0, /* clock (SCL)=*/ 9, /* data (SDA)=*/ 8, /* reset=*/ U8X8_PIN_NONE);

// UUIDs Nordic UART Service (NUS)
static BLEUUID NUS_SERVICE_UUID("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
static BLEUUID NUS_RX_UUID("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");  // Write
static BLEUUID NUS_TX_UUID("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");  // Notify

// ---------- Globals BLE ----------
NimBLEServer* pServer = nullptr;
NimBLEService* pService = nullptr;
NimBLECharacteristic* pTxChar = nullptr;  // Notifica al celular
NimBLECharacteristic* pRxChar = nullptr;  // Recibe del celular
NimBLEAdvertising* pAdvertising = nullptr;

volatile bool deviceConnected = false;
volatile bool showSyncConfirmation = false;
volatile bool showClearConfirmation = false;
volatile bool justConnected = false;
volatile bool justDisconnected = false;

// Control de alertas y recordatorios activos
uint32_t alertUntil = 0;
int activeReminderId = -1;     // Índice del recordatorio activo (-1 = ninguno)
bool reminderActive = false;   // Si hay un recordatorio activo persistente
uint32_t ledBlinkTime = 0;     // Para hacer parpadear el LED
bool ledState = false;         // Estado actual del LED

// ---------- Lógica de Recordatorios ----------
const int MAX_REMINDERS = 10;
struct Reminder {
  uint8_t hour;
  uint8_t minute;
  char title[20];    // Título corto para la pantalla
  char id[10];       // ID único del recordatorio (para sincronización con app)
  bool triggered;    // Si ya fue activado hoy
};

Reminder reminders[MAX_REMINDERS];
int reminderCount = 0;

// Tiempo Unix (segundos desde 1970-01-01)
// Se sincroniza desde el celular
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
    Serial.printf("[BLE] No se puede enviar: %s (Connected=%s, TxChar=%s)\n", 
                  s.c_str(), 
                  deviceConnected ? "SI" : "NO", 
                  pTxChar ? "OK" : "NULL");
    return;
  }
  
  Serial.printf("[BLE] Enviando: %s\n", s.c_str());
  pTxChar->setValue((uint8_t*)s.c_str(), s.length());
  pTxChar->notify();
  Serial.println("[BLE] Mensaje enviado OK");
}

// Función helper para controlar LED con lógica invertida
void setLED(bool state) {
  if (LED_INVERTED) {
    digitalWrite(LED_PIN, state ? LOW : HIGH);  // Lógica invertida: LOW = encendido
  } else {
    digitalWrite(LED_PIN, state ? HIGH : LOW);  // Lógica normal: HIGH = encendido
  }
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
    Serial.printf("[BUTTON] Completando recordatorio ID %d\n", activeReminderId);
    
    String remTitle = "";
    if (activeReminderId < reminderCount) {
      remTitle = String(reminders[activeReminderId].title);
    }
    
    // IMPORTANTE: Enviar el mensaje ANTES de completar para que el ID sea correcto
    bleSendLine("OK REMINDER_COMPLETED_BY_BUTTON " + String(activeReminderId) + " \"" + remTitle + "\"\r\n");
    
    // Ahora completar el recordatorio
    completeReminder(activeReminderId);
  } else {
    Serial.println("[BUTTON] No hay recordatorio activo");
    bleSendLine("INFO NO_REMINDER\r\n");
  }
}

// Completar recordatorio activo
void completeReminder(int remIndex) {
  if (remIndex == activeReminderId) {
    Serial.printf("[REM] Completando recordatorio ID %d\n", remIndex);
    
    // Apagar LED y limpiar estado
    setLED(false);
    reminderActive = false;
    activeReminderId = -1;
    alertUntil = 0; // Limpiar timeout
    
    // Marcar como activado para evitar repetición
    if (remIndex >= 0 && remIndex < reminderCount) {
      reminders[remIndex].triggered = true;
    }
    
    displayMessage("Completado!", "");
    delay(2000);
    Serial.println("[REM] Recordatorio completado y estado limpiado");
  }
}

// Activar recordatorio
void activateReminder(int remIndex) {
  if (remIndex >= 0 && remIndex < reminderCount && !reminders[remIndex].triggered) {
    activeReminderId = remIndex;
    reminderActive = true;
    reminders[remIndex].triggered = true;
    
    displayMessage("Recordatorio:", reminders[remIndex].title);
    setLED(true);
    ledBlinkTime = millis();
    
    // Configurar timeout de 5 minutos (300,000 ms) para auto-completar si no se confirma
    alertUntil = millis() + 300000; // 5 minutos
    
    Serial.print("[REM] Activando recordatorio: ");
    Serial.println(reminders[remIndex].title);
    Serial.println("[REM] Recordatorio activo por 5 minutos");
    
    // Notificar a la app que se activó un recordatorio con detalles
    bleSendLine("OK REMINDER_ACTIVATED " + String(remIndex) + " \"" + String(reminders[remIndex].title) + "\" " + String(reminders[remIndex].hour) + ":" + String(reminders[remIndex].minute) + "\r\n");
  }
}


// ---------- Callbacks de conexión (sin 'override' para compatibilidad) ----------
class ServerCallbacks : public NimBLEServerCallbacks {
public:
  void onConnect(NimBLEServer* s) {
    deviceConnected = true;
    justConnected = true;
    Serial.println("[BLE] *** CONEXION ESTABLECIDA ***");
    bleSendLine("OK CONNECTED\r\n");
    
    // Enviar recordatorios completados automáticamente al reconectar
    delay(1000); // Dar tiempo para que se establezca la conexión
    String completed = "COMPLETED_LIST ";
    for (int i = 0; i < reminderCount; i++) {
      if (reminders[i].triggered) {
        completed += String(i) + ",";
      }
    }
    if (completed != "COMPLETED_LIST ") {
      bleSendLine(completed + "\r\n");
      Serial.println("[BLE] Enviando recordatorios completados al reconectar");
    }
  }

  void onConnect(NimBLEServer* s, ble_gap_conn_desc* /*desc*/) {
    deviceConnected = true;
    justConnected = true;
    Serial.println("[BLE] Conectado (+desc)");
    bleSendLine("OK CONNECTED\r\n");
  }

  void onDisconnect(NimBLEServer* s) {
    deviceConnected = false;
    justDisconnected = true;
    Serial.println("[BLE] Desconectado, reanudando advertising...");
    NimBLEDevice::startAdvertising();
  }
};

// ---------- Callback para RX (escrituras desde el teléfono) ----------
class RxCallbacks : public NimBLECharacteristicCallbacks {
public:
  void onWrite(NimBLECharacteristic* ch) {
    std::string rx = ch->getValue();
    if (rx.empty()) return;
    handleCommand(String(rx.c_str()));
  }

  void onWrite(NimBLECharacteristic* ch, NimBLEConnInfo& /*connInfo*/) {
    std::string rx = ch->getValue();
    if (rx.empty()) return;
    handleCommand(String(rx.c_str()));
  }

private:
  void handleCommand(String cmd) {
    cmd.trim();
    Serial.print("[BLE RX] ");
    Serial.println(cmd);
    
    // Si recibimos un comando, significa que estamos conectados
    if (!deviceConnected) {
      deviceConnected = true;
      Serial.println("[BLE] Conexión detectada via RX");
    }

    String up = cmd;
    up.toUpperCase();

    if (up.startsWith("PIN ")) {
      int pin = -1, val = -1;
      int matches = sscanf(cmd.c_str(), "PIN %d %d", &pin, &val);
      if (matches == 2 && pin >= 0 && (val == 0 || val == 1)) {
        pinMode(pin, OUTPUT);
        digitalWrite(pin, val ? HIGH : LOW);
        bleSendLine("OK PIN " + String(pin) + " = " + String(val) + "\r\n");
      } else {
        bleSendLine("ERR USAGE: PIN <gpio> <0|1>\r\n");
      }
    } else if (up.startsWith("READ ")) {
      int pin = -1;
      int matches = sscanf(cmd.c_str(), "READ %d", &pin);
      if (matches == 1 && pin >= 0) {
        pinMode(pin, INPUT_PULLUP);
        int v = digitalRead(pin);
        bleSendLine("OK READ " + String(pin) + " = " + String(v) + "\r\n");
      } else {
        bleSendLine("ERR USAGE: READ <gpio>\r\n");
      }
    } else if (up.startsWith("SYNC_TIME ")) {
      // SYNC_TIME <timestamp_local>
      // El timestamp ya viene en hora local desde el celular
      time_t timestamp = 0;
      
      int matches = sscanf(cmd.substring(10).c_str(), "%ld", &timestamp);

      if (matches == 1 && timestamp > 0) {
        deviceClock = timestamp;
        // No configurar zona horaria, usar el timestamp local directamente
        bleSendLine("OK TIME_SYNCED");
      } else {
        bleSendLine("ERR INVALID_TIMESTAMP");
      }
    } else if (up == "REM_CLEAR") {
      reminderCount = 0;
      bleSendLine("OK REM_CLEARED");
      showClearConfirmation = true;
    } else if (up.startsWith("REM_ADD ")) {
      if (reminderCount >= MAX_REMINDERS) {
        bleSendLine("ERR REM_FULL");
        return;
      }
      String cmd_part = cmd.substring(8);
      cmd_part.trim();
      int first_space = cmd_part.indexOf(' ');
      if (first_space > 0) {
        String time_str = cmd_part.substring(0, first_space);
        String title_str = cmd_part.substring(first_space + 1);
        uint8_t h = 0, m = 0;
        if (sscanf(time_str.c_str(), "%hhu:%hhu", &h, &m) == 2) {
          title_str.replace("\"", "");
          reminders[reminderCount].hour = h;
          reminders[reminderCount].minute = m;
          strncpy(reminders[reminderCount].title, title_str.c_str(), 19);
          reminders[reminderCount].title[19] = '\0';
          reminderCount++;
          bleSendLine("OK REM_ADDED");
          showSyncConfirmation = true;
          return;
        }
      }
      bleSendLine("ERR REM_FORMAT");
    } else if (up.startsWith("REM_COMPLETE ")) {
      // REM_COMPLETE <reminder_index>
      int remIndex = -1;
      int matches = sscanf(cmd.substring(13).c_str(), "%d", &remIndex);
      if (matches == 1 && remIndex >= 0 && remIndex < reminderCount) {
        completeReminder(remIndex);
        bleSendLine("OK REM_COMPLETED");
      } else {
        bleSendLine("ERR INVALID_REM_INDEX");
      }
    } else if (up == "SIMULATE_ALERT") {
      // Crear un recordatorio de prueba activo
      activeReminderId = 0;
      reminderActive = true;
      
      // Crear recordatorio temporal si no hay ninguno
      if (reminderCount == 0) {
        strncpy(reminders[0].title, "Test Alert", 19);
        reminders[0].title[19] = '\0';
        reminders[0].hour = 12;
        reminders[0].minute = 0;
        reminders[0].triggered = true;
        reminderCount = 1;
      }
      
      displayMessage("Recordatorio:", reminders[0].title);
      setLED(true);
      ledBlinkTime = millis();
      
      Serial.println("[SIMULATE] Recordatorio activo creado para prueba");
      bleSendLine("OK SIMULATING_ALERT");
    } else if (up == "GET_COMPLETED") {
      // Enviar lista de recordatorios completados desde la última sincronización
      String completed = "COMPLETED_LIST ";
      for (int i = 0; i < reminderCount; i++) {
        if (reminders[i].triggered) {
          completed += String(i) + ",";
        }
      }
      bleSendLine(completed + "\r\n");
    } else if (up == "STATUS") {
      bleSendLine("STATUS OK\r\n");
    } else if (up == "HELP") {
      bleSendLine("CMDS:\r\n  PIN <gpio> <0|1>\r\n  READ <gpio>\r\n  SYNC_TIME <local_timestamp>\r\n  REM_CLEAR\r\n  REM_ADD HH:MM Title\r\n  REM_COMPLETE <index>\r\n  GET_COMPLETED\r\n  SIMULATE_ALERT\r\n  STATUS\r\n");
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
  setLED(false);  // Apagar LED al inicio
  
  Serial.begin(115200);
  delay(500);  // Dar tiempo para que se abra el monitor serial
  
  // Configurar botón
  setupButton();
  
  Serial.println();
  Serial.println("=== ESP32-C3 BLE UART (compat) ===");
  Serial.printf("LED configurado en GPIO%d (%s)\n", LED_PIN, LED_INVERTED ? "lógica invertida" : "lógica normal");

  u8g2.begin();
  displayMessage("Iniciando...", "VitalRecorder");
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
  Serial.println("[BLE] Servicio NUS listo");
  bleSendLine("READY\r\n");
}

void loop() {
  static uint32_t lastSecond = 0;
  static uint32_t lastDisplayUpdate = 0;
  static uint32_t lastDayReset = 0;
  uint32_t now = millis();

  // Enviar estado cada 2 segundos
  if (millis() - lastStatusTime > 2000) {
    bool currentState = digitalRead(BUTTON_PIN);
    Serial.printf("[STATUS] GPIO%d = %s | BLE: %s | REM: %s\n", 
                  BUTTON_PIN, currentState ? "LIBERADO" : "PRESIONADO",
                  deviceConnected ? "CONECTADO" : "DESCONECTADO",
                  reminderActive ? "ACTIVO" : "INACTIVO");
    lastStatusTime = millis();
    
    // Verificar si realmente hay conexión
    if (deviceConnected && pServer && pServer->getConnectedCount() == 0) {
      Serial.println("[BLE] Conexión perdida detectada");
      deviceConnected = false;
    }
  }
  
  // Detectar cambios de estado del botón
  bool currentState = digitalRead(BUTTON_PIN);
  if (currentState != lastButtonState && (millis() - lastButtonChangeTime > 50)) {
    lastButtonState = currentState;
    lastButtonChangeTime = millis();
    
    if (currentState == LOW) {
      // Botón presionado (con pull-up, LOW = presionado)
      Serial.println("[BUTTON] *** PRESIONADO ***");
      onButtonPressed();
    } else {
      // Botón liberado
      Serial.println("[BUTTON] *** LIBERADO ***");
    }
  }

  // --- Manejo de estado de conexión (no bloqueante) ---
  if (justConnected) {
    justConnected = false;
    displayMessage("Conectado a:", "VitalRecorder");
    lastDisplayUpdate = 0; // Forzar actualización de hora
  }
  if (justDisconnected) {
    justDisconnected = false;
    displayMessage("Desconectado", "Esperando...");
  }

  // Incrementar el reloj interno cada segundo
  if (now - lastSecond >= 1000) {
    lastSecond += 1000;
    if (deviceClock > 0) {
      deviceClock++;
    }
  }

  // Resetear flags de recordatorios activados cada día (a medianoche)
  if (deviceClock > 0) {
    struct tm* timeinfo = gmtime(&deviceClock);
    if (timeinfo->tm_hour == 0 && timeinfo->tm_min == 0 && timeinfo->tm_sec < 5) {
      if (now - lastDayReset > 10000) { // Evitar reset múltiple
        for (int i = 0; i < reminderCount; i++) {
          reminders[i].triggered = false;
        }
        lastDayReset = now;
        Serial.println("[REM] Recordatorios reseteados para el nuevo día");
      }
    }
  }

  // --- Recordatorio persistente activo (prioridad máxima) ---
  if (reminderActive && activeReminderId >= 0) {
    // Verificar si el timeout de 5 minutos ha expirado
    if (now >= alertUntil) {
      Serial.println("[REM] Timeout de 5 minutos alcanzado - auto-completando recordatorio");
      bleSendLine("INFO REMINDER_TIMEOUT " + String(activeReminderId) + "\r\n");
      
      // Auto-completar recordatorio
      completeReminder(activeReminderId);
      return;
    }
    
    // Hacer parpadear el LED cada 500ms
    if (now - ledBlinkTime > 500) {
      ledState = !ledState;
      setLED(ledState);
      ledBlinkTime = now;
    }
    
    // Mostrar tiempo restante cada 30 segundos
    static uint32_t lastTimeoutCheck = 0;
    if (now - lastTimeoutCheck > 30000) {
      uint32_t timeLeft = (alertUntil - now) / 1000; // segundos restantes
      Serial.printf("[REM] Tiempo restante: %d segundos\n", timeLeft);
      lastTimeoutCheck = now;
    }
    
    // Mantener el mensaje en pantalla - no actualizar nada más
    delay(10);
    return;
  }

  // --- Alertas temporales (confirmaciones) - SOLO si no hay recordatorio activo ---
  if (!reminderActive) {
    if (showClearConfirmation) {
      showClearConfirmation = false;
      displayMessage("Recordatorios", "Borrados");
      alertUntil = now + 2000;
      // Resetear todas las flags de recordatorios
      for (int i = 0; i < reminderCount; i++) {
        reminders[i].triggered = false;
      }
      return;
    }

    if (showSyncConfirmation) {
      showSyncConfirmation = false;
      displayMessage("Recordatorio", "Sincronizado");
      alertUntil = now + 2000; // Reducido a 2s
      return;
    }

    // Si hay una alerta temporal activa, no hacer más nada hasta que termine
    if (now < alertUntil) {
      return;
    }
    
    // Si la alerta temporal acaba de terminar, limpiar y forzar refresco
    if (alertUntil > 0) {
      setLED(false);
      alertUntil = 0;
      lastDisplayUpdate = 0;
    }
  }

  // --- Chequear recordatorios nuevos (solo si el reloj está sincronizado) ---
  if (deviceClock > 0) {
    struct tm* timeinfo = gmtime(&deviceClock);
    for (int i = 0; i < reminderCount; i++) {
      // Verificar si es hora del recordatorio y no ha sido activado
      if (timeinfo->tm_hour == reminders[i].hour && 
          timeinfo->tm_min == reminders[i].minute && 
          timeinfo->tm_sec < 5 && 
          !reminders[i].triggered) {
        
        activateReminder(i);
        return; // Activar solo uno a la vez
      }
    }
  }

  // --- Pantalla por defecto: Mostrar la hora ---
  if (now - lastDisplayUpdate > 15000 || lastDisplayUpdate == 0) {
    lastDisplayUpdate = now;
    if (deviceClock > 0) {
      char timeStr[6];
      struct tm* timeinfo = gmtime(&deviceClock);
      sprintf(timeStr, "%02d:%02d", timeinfo->tm_hour, timeinfo->tm_min);
      displayMessage("VitalRecorder", timeStr);
    } else {
      if (deviceConnected) {
        displayMessage("Conectado", "Sincronize hora");
      } else {
        displayMessage("VitalRecorder", "Sincronizar...");
      }
    }
  }
  
  delay(10);
}
