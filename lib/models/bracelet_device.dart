// ========================================
// ARCHIVO: lib/models/bracelet_device.dart
// ========================================
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BraceletDevice {
  final String id;
  final String name;
  final String macAddress;
  final BraceletConnectionStatus connectionStatus;
  final int? batteryLevel;
  final DateTime? lastConnected;
  final bool isLedOn;
  final Map<int, bool> pinStates; // Estados de los pines GPIO
  
  // UUIDs del servicio Nordic UART
  static const String serviceUuid = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
  static const String rxCharacteristicUuid = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"; // Write
  static const String txCharacteristicUuid = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"; // Notify

  BraceletDevice({
    required this.id,
    required this.name,
    required this.macAddress,
    this.connectionStatus = BraceletConnectionStatus.disconnected,
    this.batteryLevel,
    this.lastConnected,
    this.isLedOn = false,
    this.pinStates = const {},
  });

  // CopyWith para inmutabilidad
  BraceletDevice copyWith({
    String? id,
    String? name,
    String? macAddress,
    BraceletConnectionStatus? connectionStatus,
    int? batteryLevel,
    DateTime? lastConnected,
    bool? isLedOn,
    Map<int, bool>? pinStates,
  }) {
    return BraceletDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      macAddress: macAddress ?? this.macAddress,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      lastConnected: lastConnected ?? this.lastConnected,
      isLedOn: isLedOn ?? this.isLedOn,
      pinStates: pinStates ?? this.pinStates,
    );
  }

  // Conversión a Map para almacenamiento
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'macAddress': macAddress,
      'connectionStatus': connectionStatus.index,
      'batteryLevel': batteryLevel,
      'lastConnected': lastConnected?.toIso8601String(),
      'isLedOn': isLedOn,
      'pinStates': pinStates.map((key, value) => MapEntry(key.toString(), value)),
    };
  }

  // Conversión desde Map para recuperación
  factory BraceletDevice.fromMap(Map<String, dynamic> map) {
    return BraceletDevice(
      id: map['id'],
      name: map['name'],
      macAddress: map['macAddress'],
      connectionStatus: BraceletConnectionStatus.values[map['connectionStatus'] ?? 0],
      batteryLevel: map['batteryLevel'],
      lastConnected: map['lastConnected'] != null 
          ? DateTime.parse(map['lastConnected'])
          : null,
      isLedOn: map['isLedOn'] ?? false,
      pinStates: Map<int, bool>.from(
        map['pinStates']?.map((key, value) => MapEntry(int.parse(key), value)) ?? {}
      ),
    );
  }

  @override
  String toString() {
    return 'BraceletDevice(id: $id, name: $name, status: $connectionStatus)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BraceletDevice && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

enum BraceletConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

// Comandos disponibles para la manilla
class BraceletCommand {
  static const String ledOn = 'LED ON';
  static const String ledOff = 'LED OFF';
  static const String status = 'STATUS';
  static const String help = 'HELP';
  static String pinControl(int pin, bool state) => 'PIN $pin ${state ? 1 : 0}';
  static String readPin(int pin) => 'READ $pin';

  // Comandos de Sincronización
  static String syncTime() {
    // Obtener la hora local y ajustar el timestamp
    final now = DateTime.now();
    final utcNow = now.toUtc();
    final offsetInSeconds = now.timeZoneOffset.inSeconds;
    
    // Crear timestamp que cuando se interprete como UTC en el Arduino,
    // muestre la hora local correcta
    final localTimestamp = (utcNow.millisecondsSinceEpoch ~/ 1000) + offsetInSeconds;
    return 'SYNC_TIME $localTimestamp';
  }
  static const String clearReminders = 'REM_CLEAR';
  static String addReminder(int hour, int minute, String title) {
    // Escapar comillas en el título si es necesario y truncar
    String safeTitle = title.replaceAll('"', '\'');
    if (safeTitle.length > 19) {
      safeTitle = safeTitle.substring(0, 19);
    }
    return 'REM_ADD $hour:$minute "$safeTitle"';
  }
  static String completeReminder(int index) => 'REM_COMPLETE $index';
  
  // Comandos de respuesta del Arduino
  static const String reminderCompletedByButton = 'REMINDER_COMPLETED_BY_BUTTON';
  static const String reminderActivated = 'REMINDER_ACTIVATED';
}

// Respuestas típicas de la manilla
class BraceletResponse {
  final String command;
  final String response;
  final DateTime timestamp;
  final bool isSuccess;

  BraceletResponse({
    required this.command,
    required this.response,
    required this.timestamp,
    required this.isSuccess,
  });

  bool get isError => response.startsWith('ERR');
  bool get isOk => response.startsWith('OK');

  static BraceletResponse fromRawResponse(String command, String response) {
    return BraceletResponse(
      command: command,
      response: response.trim(),
      timestamp: DateTime.now(),
      isSuccess: !response.trim().startsWith('ERR'),
    );
  }
}

// Estados de notificación para recordatorios
enum BraceletNotificationType {
  reminderAlert,    // Alerta de recordatorio (LED parpadeando)
  medicationTime,   // Hora de medicamento (LED constante)
  exerciseTime,     // Hora de ejercicio (LED diferente)
  appointmentAlert, // Alerta de cita
}

class BraceletNotification {
  final BraceletNotificationType type;
  final String title;
  final String message;
  final int duration; // duración en segundos
  final DateTime scheduledTime;

  BraceletNotification({
    required this.type,
    required this.title,
    required this.message,
    this.duration = 10,
    required this.scheduledTime,
  });
}
