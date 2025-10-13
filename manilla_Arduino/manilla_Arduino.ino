// ===== ESP32-C3 Super Mini - "Serial BLE" tipo Nordic UART (compat) =====
// Requiere Arduino-ESP32 (core >= 2.0.x) con NimBLE-Arduino (incluido).
// Herramientas -> Placa: "ESP32C3 Dev Module" (o equivalente).

#include <NimBLEDevice.h>

// ---------- Configuración ----------
#define DEVICE_NAME "Vital Recorder"
#define LED_PIN 3  // Cambia al pin real de tu placa

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

// Utilidad: enviar una línea al cliente BLE
void bleSendLine(const String& s) {
  if (!deviceConnected || pTxChar == nullptr) return;
  pTxChar->setValue((uint8_t*)s.c_str(), s.length());
  pTxChar->notify();
}

// ---------- Callbacks de conexión (sin 'override' para compatibilidad) ----------
class ServerCallbacks : public NimBLEServerCallbacks {
public:
  // Algunas versiones exponen esta firma simple:
  void onConnect(NimBLEServer* s) {
    deviceConnected = true;
    Serial.println("[BLE] Conectado");
    bleSendLine("OK CONNECTED\r\n");
  }

  // Otras versiones exponen una sobrecarga con 'ble_gap_conn_desc*':
  void onConnect(NimBLEServer* s, ble_gap_conn_desc* /*desc*/) {
    deviceConnected = true;
    Serial.println("[BLE] Conectado (+desc)");
    bleSendLine("OK CONNECTED\r\n");
  }

  void onDisconnect(NimBLEServer* s) {
    deviceConnected = false;
    Serial.println("[BLE] Desconectado, reanudando advertising...");
    NimBLEDevice::startAdvertising();
  }
};

// ---------- Callback para RX (escrituras desde el teléfono) ----------
class RxCallbacks : public NimBLECharacteristicCallbacks {
public:
  // Versión común
  void onWrite(NimBLECharacteristic* ch) {
    std::string rx = ch->getValue();
    if (rx.empty()) return;
    handleCommand(String(rx.c_str()));
  }

  // Algunas versiones agregan info de conexión:
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

    String up = cmd;
    up.toUpperCase();

    if (up == "LED ON") {
      pinMode(LED_PIN, OUTPUT);
      digitalWrite(LED_PIN, HIGH);
      bleSendLine("OK LED ON\r\n");

    } else if (up == "LED OFF") {
      pinMode(LED_PIN, OUTPUT);
      digitalWrite(LED_PIN, LOW);
      bleSendLine("OK LED OFF\r\n");

    } else if (up.startsWith("PIN ")) {
      // PIN <gpio> <0|1>
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
      // READ <gpio>
      int pin = -1;
      int matches = sscanf(cmd.c_str(), "READ %d", &pin);
      if (matches == 1 && pin >= 0) {
        pinMode(pin, INPUT_PULLUP);
        int v = digitalRead(pin);
        bleSendLine("OK READ " + String(pin) + " = " + String(v) + "\r\n");
      } else {
        bleSendLine("ERR USAGE: READ <gpio>\r\n");
      }

    } else if (up == "STATUS") {
      int v = digitalRead(LED_PIN);
      bleSendLine("STATUS LED=" + String(v) + (v ? " (ON)\r\n" : " (OFF)\r\n"));

    } else if (up == "HELP") {
      bleSendLine(
        "CMDS:\r\n"
        "  LED ON | LED OFF\r\n"
        "  PIN <gpio> <0|1>\r\n"
        "  READ <gpio>\r\n"
        "  STATUS\r\n");

    } else {
      bleSendLine("ECHO: " + cmd + "\r\n");
    }
  }
};

void startAdvertising() {
  if (!pAdvertising) return;
  pAdvertising->addServiceUUID(NUS_SERVICE_UUID);
  NimBLEDevice::startAdvertising();  // suficiente en NimBLE
  Serial.println("[BLE] Advertising iniciado");
}

void setup() {
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  Serial.begin(115200);
  delay(200);
  Serial.println();
  Serial.println("=== ESP32-C3 BLE UART (compat) ===");

  // Inicializar BLE
  NimBLEDevice::init(DEVICE_NAME);
  // Potencia de radio (ajusta si hace falta)
  NimBLEDevice::setPower(ESP_PWR_LVL_P9);

  // Servidor
  pServer = NimBLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  // Servicio NUS
  pService = pServer->createService(NUS_SERVICE_UUID);

  // TX (Notify hacia el teléfono)
  pTxChar = pService->createCharacteristic(
    NUS_TX_UUID,
    NIMBLE_PROPERTY::NOTIFY);

  // RX (Write desde el teléfono)
  pRxChar = pService->createCharacteristic(
    NUS_RX_UUID,
    NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR);
  pRxChar->setCallbacks(new RxCallbacks());

  pService->start();

  // Advertising
  pAdvertising = NimBLEDevice::getAdvertising();
  startAdvertising();

  Serial.println("[BLE] Dispositivo: " + String(DEVICE_NAME));
  Serial.println("[BLE] Servicio NUS listo");
  bleSendLine("READY\r\n");
}

void loop() {
  // "Latido" del LED cuando no está conectado (opcional)
  static uint32_t t0 = 0;
  if (!deviceConnected) {
    if (millis() - t0 > 800) {
      t0 = millis();
      digitalWrite(LED_PIN, !digitalRead(LED_PIN));
    }
  }
  delay(10);
}