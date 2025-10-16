// ========================================
// ARCHIVO: lib/services/bracelet_service.dart
// ========================================
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/bracelet_device.dart';

class BraceletService extends ChangeNotifier {
  static final BraceletService _instance = BraceletService._internal();
  factory BraceletService() => _instance;
  BraceletService._internal();

  // Estado del servicio
  BraceletDevice? _connectedDevice;
  BluetoothDevice? _bluetoothDevice;
  BluetoothCharacteristic? _rxCharacteristic;
  BluetoothCharacteristic? _txCharacteristic;
  
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _characteristicSubscription;
  
  final StreamController<BraceletResponse> _responseController = 
      StreamController<BraceletResponse>.broadcast();
  
  final List<BluetoothDevice> _discoveredDevices = [];
  bool _isScanning = false;
  
  // Getters
  BraceletDevice? get connectedDevice => _connectedDevice;
  List<BluetoothDevice> get discoveredDevices => _discoveredDevices;
  bool get isScanning => _isScanning;
  bool get isConnected => _connectedDevice?.connectionStatus == BraceletConnectionStatus.connected;
  Stream<BraceletResponse> get responseStream => _responseController.stream;

  /// Inicializar el servicio BLE
  Future<bool> initialize() async {
    try {
      // Verificar si el Bluetooth está disponible
      if (await FlutterBluePlus.isAvailable == false) {
        print("Bluetooth no está disponible en este dispositivo");
        return false;
      }

      // Solicitar permisos necesarios
      await _requestPermissions();
      
      // Verificar estado del Bluetooth
      final state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        print("Bluetooth está desactivado");
        return false;
      }

      print("BraceletService inicializado correctamente");
      return true;
    } catch (e) {
      print("Error inicializando BraceletService: $e");
      return false;
    }
  }

  /// Solicitar permisos necesarios para BLE
  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.location,
      ].request();
      
      for (var permission in statuses.entries) {
        if (!permission.value.isGranted) {
          print("Permiso ${permission.key} denegado");
        }
      }
    }
  }

  /// Buscar dispositivos manilla
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    try {
      if (_isScanning) return;
      
      _isScanning = true;
      _discoveredDevices.clear();
      notifyListeners();

      // Configurar el escaneo
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: true,
      );

      // Escuchar resultados del escaneo
      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          final device = result.device;
          final name = device.platformName.isNotEmpty ? device.platformName : 'Dispositivo desconocido';
          
          // Filtrar por nombre "Vital Recorder" o UUIDs conocidos
          if (name.contains("Vital Recorder") || 
              result.advertisementData.serviceUuids.any((uuid) => 
                  uuid.toString().toUpperCase() == BraceletDevice.serviceUuid.toUpperCase())) {
            
            if (!_discoveredDevices.any((d) => d.remoteId == device.remoteId)) {
              _discoveredDevices.add(device);
              print("Dispositivo manilla encontrado: $name (${device.remoteId})");
              notifyListeners();
            }
          }
        }
      });

      // Detener escaneo automáticamente después del timeout
      Future.delayed(timeout, () {
        stopScan();
      });

    } catch (e) {
      print("Error durante el escaneo: $e");
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Detener escaneo
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      _isScanning = false;
      notifyListeners();
      print("Escaneo detenido");
    } catch (e) {
      print("Error deteniendo escaneo: $e");
    }
  }

  /// Conectar a la manilla
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      // Actualizar estado a conectando
      _connectedDevice = BraceletDevice(
        id: device.remoteId.toString(),
        name: device.platformName.isNotEmpty ? device.platformName : 'Vital Recorder',
        macAddress: device.remoteId.toString(),
        connectionStatus: BraceletConnectionStatus.connecting,
      );
      notifyListeners();

      // Conectar al dispositivo
      await device.connect(timeout: const Duration(seconds: 15));
      _bluetoothDevice = device;

      // Escuchar cambios de conexión
      _connectionSubscription = device.connectionState.listen((state) {
        _handleConnectionStateChange(state);
      });

      // Descubrir servicios
      final services = await device.discoverServices();
      
      // Buscar el servicio Nordic UART
      BluetoothService? targetService;
      for (final service in services) {
        if (service.uuid.toString().toUpperCase() == BraceletDevice.serviceUuid.toUpperCase()) {
          targetService = service;
          break;
        }
      }

      if (targetService == null) {
        throw Exception("Servicio Nordic UART no encontrado");
      }

      // Configurar características
      for (final characteristic in targetService.characteristics) {
        final uuid = characteristic.uuid.toString().toUpperCase();
        
        if (uuid == BraceletDevice.rxCharacteristicUuid.toUpperCase()) {
          _rxCharacteristic = characteristic;
        } else if (uuid == BraceletDevice.txCharacteristicUuid.toUpperCase()) {
          _txCharacteristic = characteristic;
          // Suscribirse a notificaciones
          await characteristic.setNotifyValue(true);
          _characteristicSubscription = characteristic.lastValueStream.listen(_handleIncomingData);
        }
      }

      if (_rxCharacteristic == null || _txCharacteristic == null) {
        throw Exception("Características necesarias no encontradas");
      }

      // Actualizar estado a conectado
      _connectedDevice = _connectedDevice!.copyWith(
        connectionStatus: BraceletConnectionStatus.connected,
        lastConnected: DateTime.now(),
      );
      notifyListeners();

      // Enviar comando inicial para verificar conexión
      await sendCommand(BraceletCommand.status);
      
      print("Conectado exitosamente a la manilla");
      return true;

    } catch (e) {
      print("Error conectando a la manilla: $e");
      _connectedDevice = _connectedDevice?.copyWith(
        connectionStatus: BraceletConnectionStatus.error,
      );
      notifyListeners();
      return false;
    }
  }

  /// Desconectar de la manilla
  Future<void> disconnect() async {
    try {
      await _connectionSubscription?.cancel();
      await _characteristicSubscription?.cancel();
      
      if (_bluetoothDevice != null) {
        await _bluetoothDevice!.disconnect();
      }

      _connectedDevice = null;
      _bluetoothDevice = null;
      _rxCharacteristic = null;
      _txCharacteristic = null;
      
      notifyListeners();
      print("Desconectado de la manilla");
    } catch (e) {
      print("Error desconectando: $e");
    }
  }

  /// Enviar comando a la manilla
  Future<void> sendCommand(String command) async {
    if (!isConnected || _rxCharacteristic == null) {
      throw Exception("No hay conexión activa con la manilla");
    }

    try {
      final data = utf8.encode(command + '\r\n');
      await _rxCharacteristic!.write(data);
      print("Comando enviado: $command");
    } catch (e) {
      print("Error enviando comando: $e");
      throw e;
    }
  }

  /// Controles específicos de la manilla
  Future<void> turnLedOn() async {
    await sendCommand(BraceletCommand.ledOn);
    if (_connectedDevice != null) {
      _connectedDevice = _connectedDevice!.copyWith(isLedOn: true);
      notifyListeners();
    }
  }

  Future<void> turnLedOff() async {
    await sendCommand(BraceletCommand.ledOff);
    if (_connectedDevice != null) {
      _connectedDevice = _connectedDevice!.copyWith(isLedOn: false);
      notifyListeners();
    }
  }

  Future<void> controlPin(int pin, bool state) async {
    await sendCommand(BraceletCommand.pinControl(pin, state));
    if (_connectedDevice != null) {
      final updatedPinStates = Map<int, bool>.from(_connectedDevice!.pinStates);
      updatedPinStates[pin] = state;
      _connectedDevice = _connectedDevice!.copyWith(pinStates: updatedPinStates);
      notifyListeners();
    }
  }

  Future<void> readPin(int pin) async {
    await sendCommand(BraceletCommand.readPin(pin));
  }

  Future<void> getStatus() async {
    await sendCommand(BraceletCommand.status);
  }

  /// Enviar notificación de recordatorio
  Future<void> sendReminderNotification(BraceletNotification notification) async {
    switch (notification.type) {
      case BraceletNotificationType.medicationTime:
        // LED constante para medicamentos
        await turnLedOn();
        break;
      case BraceletNotificationType.exerciseTime:
        // Parpadeo para ejercicios (on/off/on/off)
        await turnLedOn();
        await Future.delayed(Duration(milliseconds: 500));
        await turnLedOff();
        await Future.delayed(Duration(milliseconds: 500));
        await turnLedOn();
        break;
      case BraceletNotificationType.reminderAlert:
      case BraceletNotificationType.appointmentAlert:
      default:
        // Parpadeo rápido para alertas generales
        for (int i = 0; i < 3; i++) {
          await turnLedOn();
          await Future.delayed(Duration(milliseconds: 200));
          await turnLedOff();
          await Future.delayed(Duration(milliseconds: 200));
        }
        break;
    }
  }

  /// Manejar cambios de estado de conexión
  void _handleConnectionStateChange(BluetoothConnectionState state) {
    if (_connectedDevice == null) return;

    switch (state) {
      case BluetoothConnectionState.connected:
        _connectedDevice = _connectedDevice!.copyWith(
          connectionStatus: BraceletConnectionStatus.connected,
          lastConnected: DateTime.now(),
        );
        break;
      case BluetoothConnectionState.disconnected:
        _connectedDevice = _connectedDevice!.copyWith(
          connectionStatus: BraceletConnectionStatus.disconnected,
        );
        break;
      default:
        break;
    }
    notifyListeners();
  }

  /// Manejar datos entrantes de la manilla
  void _handleIncomingData(List<int> data) {
    try {
      final response = utf8.decode(data).trim();
      print("Respuesta recibida: $response");

      // Crear objeto de respuesta
      final braceletResponse = BraceletResponse.fromRawResponse("", response);
      _responseController.add(braceletResponse);

      // Procesar respuestas específicas
      if (response.contains("LED=")) {
        final isLedOn = response.contains("LED=1") || response.contains("(ON)");
        if (_connectedDevice != null) {
          _connectedDevice = _connectedDevice!.copyWith(isLedOn: isLedOn);
          notifyListeners();
        }
      }
    } catch (e) {
      print("Error procesando datos entrantes: $e");
    }
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _characteristicSubscription?.cancel();
    _responseController.close();
    disconnect();
    super.dispose();
  }
}
