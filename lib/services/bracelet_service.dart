import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/bracelet_device.dart';
import '../models/reminder_new.dart';
import '../reminder_service_new.dart';
import 'background_ble_service_simple.dart';
import 'bracelet_storage_service.dart';
import 'notification_service.dart';

class BraceletService extends ChangeNotifier {
  static final BraceletService _instance = BraceletService._internal();
  factory BraceletService() => _instance;
  BraceletService._internal() {
    // Iniciar escucha global inmediatamente
    _startGlobalBleListener();
    // Iniciar verificación de conexión
    _startConnectionMonitoring();
  }

  // Estado del servicio
  BraceletDevice? _connectedDevice;
  BluetoothDevice? _bluetoothDevice;
  BluetoothCharacteristic? _rxCharacteristic;
  BluetoothCharacteristic? _txCharacteristic;
  
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _characteristicSubscription;
  
  final StreamController<BraceletResponse> _responseController = 
      StreamController<BraceletResponse>.broadcast();
  final StreamController<BraceletConnectionStatus> _connectionStatusController =
      StreamController<BraceletConnectionStatus>.broadcast();
  
  final List<BluetoothDevice> _discoveredDevices = [];
  bool _isScanning = false;
  bool _isSyncing = false;
  
  // Sistema de reconexión automática
  Timer? _reconnectionTimer;
  bool _isAttemptingReconnection = false;
  BraceletDevice? _savedBracelet;
  
  // Sistema de verificación de conexión
  Timer? _connectionCheckTimer;
  bool _isCheckingConnection = false;
  DateTime? _lastSuccessfulResponse;
  static const Duration _connectionCheckInterval = Duration(minutes: 1);
  static const Duration _responseTimeout = Duration(seconds: 10);
  
  // Estado de recordatorios activos en la manilla
  int? _activeReminderIndex;
  String? _activeReminderTitle;
  
  // Getters
  BraceletDevice? get connectedDevice => _connectedDevice;
  List<BluetoothDevice> get discoveredDevices => _discoveredDevices;
  bool get isScanning => _isScanning;
  bool get isSyncing => _isSyncing;
  bool get isConnected => _connectedDevice?.connectionStatus == BraceletConnectionStatus.connected;
  Stream<BraceletResponse> get responseStream => _responseController.stream;
  Stream<BraceletConnectionStatus> get connectionStatusStream => _connectionStatusController.stream;
  
  // Estado de recordatorios activos en la manilla
  int? get activeReminderIndex => _activeReminderIndex;
  String? get activeReminderTitle => _activeReminderTitle;
  bool get hasActiveReminder => _activeReminderIndex != null;

  /// Sincronizar recordatorios con la manilla
  Future<void> syncRemindersToBracelet() async {
    if (!isConnected) {
      throw Exception("Manilla no conectada");
    }

    _isSyncing = true;
    notifyListeners();

    try {
      final reminderService = ReminderServiceNew();
      final allReminders = await reminderService.getAllReminders();
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Obtener todas las ocurrencias de hoy de todos los recordatorios activos y NO pausados
      List<Map<String, dynamic>> todayOccurrences = [];
      
      for (final reminder in allReminders) {
        // Excluir recordatorios pausados
        if (reminder.isPaused) {
          print("⛸️ Recordatorio pausado excluido de sincronización: ${reminder.title}");
          continue;
        }
        
        if (reminder.hasOccurrencesOnDay(today)) {
          // Agregar todas las ocurrencias del día que sean FUTURAS
          for (final time in reminder.dailyScheduleTimes) {
            final scheduledDateTime = DateTime(
              today.year, 
              today.month, 
              today.day, 
              time.hour, 
              time.minute
            );

            // Si el recordatorio ya pasó hoy, no enviarlo a la manilla
            // (Damos 1 minuto de gracia por si acaso)
            if (scheduledDateTime.isBefore(now.subtract(Duration(minutes: 1)))) {
              print("⏭️ Omitiendo recordatorio pasado para manilla: ${reminder.title} a las ${time.hour}:${time.minute}");
              continue;
            }

            todayOccurrences.add({
              'hour': time.hour,
              'minute': time.minute,
              'title': reminder.title,
              'description': reminder.description,
              'reminderId': reminder.id,
            });
          }
        }
      }
      
      print("Total recordatorios activos: ${allReminders.length}");
      print("Ocurrencias válidas para enviar a manilla hoy: ${todayOccurrences.length}");

      // 1. Sincronizar la hora actual
      await sendCommand(BraceletCommand.syncTime());
      await Future.delayed(const Duration(milliseconds: 200));

      // 2. Borrar recordatorios existentes en la manilla
      await sendCommand(BraceletCommand.clearReminders);
      await Future.delayed(const Duration(milliseconds: 500));

      // 3. Enviar cada ocurrencia válida
      for (final occ in todayOccurrences) {
        final command = BraceletCommand.addReminder(
          occ['hour'] as int,
          occ['minute'] as int,
          occ['title'] as String,
          occ['description'] as String,
        );
        await sendCommand(command);
        await Future.delayed(const Duration(milliseconds: 200));
      }

    } catch (e) {
      print("Error sincronizando recordatorios: $e");
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }


  /// Inicializar el servicio BLE
  Future<bool> initialize() async {
    try {
      // Inicializar la base de datos de zonas horarias
      tz.initializeTimeZones();

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
      
      // Cargar manilla guardada y comenzar reconexión automática
      await _loadSavedBraceletAndStartReconnection();

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

      // Sincronizar tiempo del celular con la manilla automáticamente
      print("Sincronizando tiempo con la manilla...");
      try {
        await sendCommand(BraceletCommand.syncTime());
        await Future.delayed(const Duration(milliseconds: 500));
        print("Tiempo sincronizado exitosamente");
      } catch (e) {
        print("Error sincronizando tiempo: $e");
        // No fallar la conexión por error de sincronización de tiempo
      }

      // Enviar comando inicial para verificar conexión
      await sendCommand(BraceletCommand.status);
      
      // Guardar información de la manilla para reconexión automática
      await BraceletStorageService.saveLastConnectedBracelet(_connectedDevice!);
      await BraceletStorageService.resetReconnectAttempts();
      
      // Detener sistema de reconexión ya que estamos conectados
      stopReconnection();
      
      print("Conectado exitosamente a la manilla");
      
      // Sincronizar recordatorios automáticamente
      print("🔄 Sincronizando recordatorios con la manilla...");
      try {
        await syncRemindersToBracelet();
        print("✅ Recordatorios sincronizados exitosamente");
      } catch (e) {
        print("⚠️ Error sincronizando recordatorios: $e");
        // No fallar la conexión por error de sincronización
      }
      
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
      
      // Reiniciar sistema de reconexión automática si hay manilla guardada
      if (_savedBracelet != null) {
        final shouldReconnect = await BraceletStorageService.shouldAutoReconnect();
        if (shouldReconnect) {
          print('[RECONNECT] ♾️ Desconectado - reiniciando sistema de reconexión...');
          _startReconnectionLoop();
        }
      }
      
      notifyListeners();
      print("Desconectado de la manilla");
    } catch (e) {
      print("Error desconectando: $e");
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
        _connectionStatusController.add(BraceletConnectionStatus.connected);
        break;
      case BluetoothConnectionState.disconnected:
        _connectedDevice = _connectedDevice!.copyWith(
          connectionStatus: BraceletConnectionStatus.disconnected,
        );
        _connectionStatusController.add(BraceletConnectionStatus.disconnected);
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
      print("[GLOBAL BLE] ✅ Respuesta recibida: $response");
      
      // Actualizar timestamp de última respuesta exitosa
      _lastSuccessfulResponse = DateTime.now();

      // Crear objeto de respuesta
      final braceletResponse = BraceletResponse.fromRawResponse("", response);
      _responseController.add(braceletResponse);

      // Procesar respuestas específicas
      _processSpecificResponses(response);
      
    } catch (e) {
      print("[GLOBAL BLE] ❌ Error procesando datos entrantes: $e");
    }
  }
  
  /// Procesar respuestas específicas del Arduino
  void _processSpecificResponses(String response) {
    try {
      print("[PROCESS] 🔄 Procesando: $response");
      
      if (response.startsWith('OK REMINDER_COMPLETED_BY_BUTTON')) {
        print("[PROCESS] 🟢 Detectado recordatorio completado por botón");
        // El usuario completó un recordatorio presionando el botón físico
        final parts = response.split(' ');
        print("[PROCESS] Parts: $parts");
        if (parts.length >= 3) {
          final reminderIndex = int.tryParse(parts[2]);
          print("[PROCESS] 🔢 Índice parseado: $reminderIndex");
          if (reminderIndex != null) {
            _handleReminderCompletedByButton(reminderIndex);
          }
        }
      } else if (response.startsWith('OK REMINDER_ACTIVATED')) {
        print("[PROCESS] 🔔 Detectado recordatorio activado");
        // Se activó un recordatorio en la manilla
        final parts = response.split(' ');
        if (parts.length >= 3) {
          final reminderIndex = int.tryParse(parts[2]);
          if (reminderIndex != null) {
            _handleReminderActivated(reminderIndex);
          }
        }
      } else if (response.startsWith('COMPLETED_LIST')) {
        print("[PROCESS] 📋 Lista de completados detectada");
        // Lista de recordatorios completados al reconectar
        _handleCompletedListSync(response);
      } else if (response.startsWith('OK REMINDER_CONFIRMED')) {
        print("[PROCESS] 🟢 Detectado recordatorio confirmado desde la manilla");
        try {
          final parts = response.split(' ');
          if (parts.length >= 3) {
            final reminderIndex = int.tryParse(parts[2]);
            if (reminderIndex != null) {
              print("[PROCESS] 🔢 Índice de recordatorio confirmado: $reminderIndex");
              _handleReminderCompletedByButton(reminderIndex);
            } else {
              print("[PROCESS] ⚠️ No se pudo parsear el índice del recordatorio.");
            }
          }
        } catch (e) {
          print("[PROCESS] ❌ Error parseando mensaje REMINDER_CONFIRMED: $e");
        }
      } else {
        print("[PROCESS] ℹ️ Mensaje no procesado: $response");
      }
    } catch (e) {
      print('[PROCESS] ❌ Error procesando respuesta específica: $e');
    }
  }
  
  /// Manejar confirmación de recordatorio por botón físico
  void _handleReminderCompletedByButton(int reminderIndex) async {
    try {
      print('[HANDLE] 🔴 Iniciando manejo de recordatorio completado por botón');
      print('[HANDLE] 🔢 Índice recibido: $reminderIndex');
      
      final reminderService = ReminderServiceNew();
      final allReminders = await reminderService.getAllReminders();
      print('[HANDLE] 📄 Total recordatorios en BD: ${allReminders.length}');
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Obtener todas las ocurrencias de hoy en orden
      List<Map<String, dynamic>> todayOccurrences = [];
      
      for (final reminder in allReminders) {
        if (reminder.hasOccurrencesOnDay(today)) {
          for (final time in reminder.dailyScheduleTimes) {
            final occurrenceTime = DateTime(
              today.year,
              today.month,
              today.day,
              time.hour,
              time.minute,
            );
            todayOccurrences.add({
              'reminderId': reminder.id,
              'title': reminder.title,
              'scheduledTime': occurrenceTime,
            });
          }
        }
      }
      
      print('[HANDLE] 📅 Ocurrencias para hoy: ${todayOccurrences.length}');
      
      // Encontrar la ocurrencia correspondiente al índice
      if (reminderIndex < todayOccurrences.length) {
        final occurrence = todayOccurrences[reminderIndex];
        final reminderId = occurrence['reminderId'] as String;
        final title = occurrence['title'] as String;
        final scheduledTime = occurrence['scheduledTime'] as DateTime;
        
        print('[HANDLE] ✅ Ocurrencia encontrada: "$title" programada a ${scheduledTime.hour}:${scheduledTime.minute}');
        
        // Confirmar en el sistema nuevo
        final success = await reminderService.confirmReminder(
          reminderId: reminderId,
          scheduledTime: scheduledTime,
          notes: 'Confirmado desde manilla',
        );
        
        if (success) {
          print('[HANDLE] 🎆 ¡Recordatorio "$title" confirmado!');
          
          await BackgroundBleService.showReminderCompletedNotification(title);
          print('[HANDLE] 🔔 Notificación enviada');
          
          _activeReminderIndex = null;
          _activeReminderTitle = null;
          
          notifyListeners();
          print('[HANDLE] 📡 Listeners notificados');
        } else {
          print('[HANDLE] ❌ Error confirmando recordatorio');
        }
      } else {
        print('[HANDLE] ⚠️ Índice $reminderIndex fuera de rango (max: ${todayOccurrences.length - 1})');
      }
      
    } catch (e) {
      print('[HANDLE] 💥 Error manejando confirmación por botón: $e');
    }
  }
  
  /// Manejar activación de recordatorio en la manilla  
  void _handleReminderActivated(int reminderIndex) async {
    try {
      print('Recordatorio $reminderIndex activado en la manilla');
      
      final reminderService = ReminderServiceNew();
      final allReminders = await reminderService.getAllReminders();
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Obtener todas las ocurrencias de hoy
      List<Map<String, dynamic>> todayOccurrences = [];
      
      for (final reminder in allReminders) {
        if (reminder.hasOccurrencesOnDay(today)) {
          for (final time in reminder.dailyScheduleTimes) {
            todayOccurrences.add({
              'title': reminder.title,
            });
          }
        }
      }
      
      // Actualizar estado del recordatorio activo
      if (reminderIndex < todayOccurrences.length) {
        final occurrence = todayOccurrences[reminderIndex];
        _activeReminderIndex = reminderIndex;
        _activeReminderTitle = occurrence['title'] as String;
        
        print('Recordatorio activo: "${_activeReminderTitle}"');
      }
      
      notifyListeners();
    } catch (e) {
      print('Error manejando activación de recordatorio: $e');
    }
  }
  
  /// Manejar sincronización de recordatorios completados al reconectar
  void _handleCompletedListSync(String response) async {
    try {
      print('Sincronizando recordatorios completados: $response');
      
      // Extraer índices de recordatorios completados
      final parts = response.replaceFirst('COMPLETED_LIST ', '').trim();
      if (parts.isEmpty) {
        print('No hay recordatorios completados para sincronizar');
        return;
      }
      
      final completedIndices = parts.split(',').where((s) => s.isNotEmpty).map((s) => int.tryParse(s)).where((i) => i != null).cast<int>().toList();
      
      if (completedIndices.isEmpty) {
        print('No se encontraron índices válidos para sincronizar');
        return;
      }
      
      print('Índices completados a sincronizar: $completedIndices');
      
      // Procesar cada recordatorio completado
      for (final index in completedIndices) {
        _handleReminderCompletedByButton(index);
        await Future.delayed(const Duration(milliseconds: 100)); // Pequeña pausa entre sincronizaciones
      }
      
      print('Sincronización de recordatorios completados finalizada');
      
    } catch (e) {
      print('Error manejando sincronización de completados: $e');
    }
  }

  /// Enviar comando a la manilla con detección de timeout
  Future<void> sendCommand(String command, {Duration? timeout}) async {
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
  
  /// Enviar comando con espera de respuesta y timeout
  Future<bool> sendCommandWithResponse(String command, {Duration? timeout}) async {
    if (!isConnected || _rxCharacteristic == null) {
      return false;
    }

    try {
      final responseTimeout = timeout ?? _responseTimeout;
      bool responseReceived = false;
      
      // Suscribirse temporalmente a las respuestas
      final subscription = _responseController.stream.listen((response) {
        responseReceived = true;
      });
      
      // Enviar comando
      final data = utf8.encode(command + '\r\n');
      await _rxCharacteristic!.write(data);
      print("[CONNECTION_CHECK] Comando enviado: $command");
      
      // Esperar respuesta o timeout
      final startTime = DateTime.now();
      while (!responseReceived && DateTime.now().difference(startTime) < responseTimeout) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      subscription.cancel();
      
      if (responseReceived) {
        _lastSuccessfulResponse = DateTime.now();
        print("[CONNECTION_CHECK] ✅ Respuesta recibida");
      } else {
        print("[CONNECTION_CHECK] ⚠️ Timeout - No se recibió respuesta");
      }
      
      return responseReceived;
    } catch (e) {
      print("[CONNECTION_CHECK] ❌ Error enviando comando: $e");
      return false;
    }
  }

  Future<void> getStatus() async {
    await sendCommand(BraceletCommand.status);
  }

  /// Envía un comando para simular una alerta en la manilla
  Future<void> simulateAlert() async {
    await sendCommand("SIMULATE_ALERT");
  }

  /// Completar recordatorio activo en la manilla desde la app
  Future<void> completeReminderOnBracelet(int reminderIndex) async {
    if (!isConnected) {
      throw Exception("Manilla no conectada");
    }
    
    try {
      await sendCommand(BraceletCommand.completeReminder(reminderIndex));
      print("Recordatorio $reminderIndex marcado como completado en la manilla");
    } catch (e) {
      print("Error completando recordatorio en manilla: $e");
      rethrow;
    }
  }

  /// Envía una notificación de recordatorio a la manilla
  Future<void> sendReminderNotification(BraceletNotification notification) async {
    if (!isConnected) {
      print('No hay conexión activa con la manilla para enviar notificación');
      return;
    }

    try {
      String command;
      
      // Generar comando basado en el tipo de notificación
      switch (notification.type) {
        case BraceletNotificationType.medicationTime:
          command = 'NOTIFY_MED "${notification.title}" ${notification.duration}';
          break;
        case BraceletNotificationType.exerciseTime:
          command = 'NOTIFY_EX "${notification.title}" ${notification.duration}';
          break;
        case BraceletNotificationType.appointmentAlert:
          command = 'NOTIFY_APPT "${notification.title}" ${notification.duration}';
          break;
        default:
          command = 'NOTIFY "${notification.title}" ${notification.duration}';
          break;
      }
      
      await sendCommand(command);
      print('Notificación enviada a la manilla: ${notification.title}');
      
    } catch (e) {
      print('Error enviando notificación a la manilla: $e');
      rethrow;
    }
  }

  /// Iniciar escucha global BLE (funciona desde cualquier pantalla)
  void _startGlobalBleListener() {
    print('[GLOBAL BLE] Iniciando escucha global...');
    
    // Timer que verifica conexiones activas cada 5 segundos
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (isConnected && _characteristicSubscription != null) {
        // Ya está escuchando, no hacer nada
        return;
      }
      
      if (isConnected && _txCharacteristic != null && _characteristicSubscription == null) {
        print('[GLOBAL BLE] Estableciendo escucha de características...');
        
        // Escuchar respuestas BLE SIEMPRE
        _characteristicSubscription = _txCharacteristic!.lastValueStream.listen((data) {
          _handleIncomingData(data);
        });
        
        _txCharacteristic!.setNotifyValue(true);
        print('[GLOBAL BLE] Escucha global BLE establecida');
      }
    });
  }
  
  /// Cargar manilla guardada e iniciar sistema de reconexión
  Future<void> _loadSavedBraceletAndStartReconnection() async {
    try {
      _savedBracelet = await BraceletStorageService.getLastConnectedBracelet();
      
      if (_savedBracelet != null) {
        print('[RECONNECT] 🔄 Manilla guardada encontrada: ${_savedBracelet!.name}');
        
        final shouldReconnect = await BraceletStorageService.shouldAutoReconnect();
        if (shouldReconnect) {
          print('[RECONNECT] ⚙️ Iniciando sistema de reconexión automática...');
          _startReconnectionLoop();
        }
      } else {
        print('[RECONNECT] ℹ️ No hay manilla guardada');
      }
    } catch (e) {
      print('[RECONNECT] ❌ Error cargando manilla guardada: $e');
    }
  }
  
  /// Iniciar bucle de reconexión automática
  void _startReconnectionLoop() {
    // Cancelar timer existente
    _reconnectionTimer?.cancel();
    
    // Iniciar nuevo timer que verifica cada 30 segundos
    _reconnectionTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _attemptAutoReconnection();
    });
    
    // Intentar reconexión inmediata
    _attemptAutoReconnection();
  }
  
  /// Intentar reconexión automática
  Future<void> _attemptAutoReconnection() async {
    // No intentar si ya está conectado o ya está intentando
    if (isConnected || _isAttemptingReconnection || _savedBracelet == null) {
      return;
    }
    
    try {
      _isAttemptingReconnection = true;
      await BraceletStorageService.incrementReconnectAttempts();
      
      final attempts = await BraceletStorageService.getReconnectAttempts();
      print('[RECONNECT] 🔍 Intento de reconexión #$attempts para ${_savedBracelet!.name}');
      
      // Límite de intentos (por ejemplo, 100 intentos = ~50 minutos)
      if (attempts > 100) {
        print('[RECONNECT] ⚠️ Límite de intentos alcanzado, pausando reconexión');
        _reconnectionTimer?.cancel();
        return;
      }
      
      // Buscar dispositivos BLE
      print('[RECONNECT] 🔎 Escaneando dispositivos BLE...');
      await _scanForSavedBracelet();
      
    } catch (e) {
      print('[RECONNECT] ❌ Error en reconexión automática: $e');
    } finally {
      _isAttemptingReconnection = false;
    }
  }
  
  /// Escanear específicamente por la manilla guardada
  Future<void> _scanForSavedBracelet() async {
    if (_savedBracelet == null) return;
    
    try {
      // Escaneo rápido de 10 segundos
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: true,
      );
      
      // Buscar en resultados usando listen
      final results = <ScanResult>[];
      
      // Escuchar resultados del escaneo
      final subscription = FlutterBluePlus.scanResults.listen((scanResults) {
        results.addAll(scanResults);
      });
      
      // Esperar un poco para que se complete el escaneo
      await Future.delayed(const Duration(seconds: 2));
      subscription.cancel();
      
      for (final result in results) {
        final device = result.device;
        final name = device.platformName.isNotEmpty ? device.platformName : 'Dispositivo desconocido';
        
        // Verificar si coincide con la manilla guardada
        if (_isMatchingSavedBracelet(device, name)) {
          print('[RECONNECT] ✅ ¡Manilla encontrada! Intentando conectar...');
          
          // Intentar conexión
          final success = await _connectToFoundBracelet(device);
          
          if (success) {
            print('[RECONNECT] 🎆 ¡Reconexión exitosa!');
            await BraceletStorageService.resetReconnectAttempts();
            _reconnectionTimer?.cancel();
            return;
          }
        }
      }
      
      print('[RECONNECT] 🔍 Manilla no encontrada en este escaneo');
    } catch (e) {
      print('[RECONNECT] ❌ Error durante escaneo: $e');
    }
  }
  
  /// Verificar si un dispositivo coincide con la manilla guardada
  bool _isMatchingSavedBracelet(BluetoothDevice device, String name) {
    if (_savedBracelet == null) return false;
    
    // Verificar por MAC address (más confiable)
    if (_savedBracelet!.macAddress.isNotEmpty && 
        device.remoteId.toString().toLowerCase() == _savedBracelet!.macAddress.toLowerCase()) {
      return true;
    }
    
    // Verificar por nombre
    if (name.contains('Vital Recorder') || name == _savedBracelet!.name) {
      return true;
    }
    
    return false;
  }
  
  /// Conectar a manilla encontrada
  Future<bool> _connectToFoundBracelet(BluetoothDevice device) async {
    try {
      print('[RECONNECT] 🔗 Conectando a ${device.platformName}...');
      
      await device.connect(
        timeout: const Duration(seconds: 15),
      );
      
      // Actualizar estado interno
      _bluetoothDevice = device;
      _connectedDevice = BraceletDevice(
        name: device.platformName.isNotEmpty ? device.platformName : _savedBracelet!.name,
        macAddress: device.remoteId.toString(),
        id: device.remoteId.toString(),
        connectionStatus: BraceletConnectionStatus.connected,
        lastConnected: DateTime.now(),
      );
      
      // Configurar servicios y características
      await _setupServicesAndCharacteristics();
      
      // Guardar información actualizada
      await BraceletStorageService.saveLastConnectedBracelet(_connectedDevice!);
      
      notifyListeners();
      
      // Sincronizar recordatorios automáticamente después de reconectar
      print('[RECONNECT] 🔄 Sincronizando recordatorios...');
      try {
        await syncRemindersToBracelet();
        print('[RECONNECT] ✅ Recordatorios sincronizados exitosamente');
      } catch (e) {
        print('[RECONNECT] ⚠️ Error sincronizando recordatorios: $e');
        // No fallar la reconexión por error de sincronización
      }
      
      return true;
      
    } catch (e) {
      print('[RECONNECT] ❌ Error conectando: $e');
      return false;
    }
  }
  
  /// Configurar servicios y características después de conectar
  Future<void> _setupServicesAndCharacteristics() async {
    if (_bluetoothDevice == null) return;
    
    try {
      await _bluetoothDevice!.discoverServices();
      final services = await _bluetoothDevice!.discoverServices();
      
      for (final service in services) {
        if (service.uuid.toString().toLowerCase() == BraceletDevice.serviceUuid.toLowerCase()) {
          final characteristics = service.characteristics;
          
          for (final characteristic in characteristics) {
            final uuidStr = characteristic.uuid.toString().toLowerCase();
            
            if (uuidStr == '6e400002-b5a3-f393-e0a9-e50e24dcca9e') {
              _rxCharacteristic = characteristic;
              print('[RECONNECT] 📝 RX Characteristic configurada');
            } else if (uuidStr == '6e400003-b5a3-f393-e0a9-e50e24dcca9e') {
              _txCharacteristic = characteristic;
              
              // Configurar notificaciones
              await _txCharacteristic!.setNotifyValue(true);
              
              _characteristicSubscription = _txCharacteristic!.lastValueStream.listen((data) {
                _handleIncomingData(data);
              });
              
              print('[RECONNECT] 📡 TX Characteristic configurada con notificaciones');
            }
          }
          break;
        }
      }
      
      print('[RECONNECT] ⚙️ Servicios y características configurados correctamente');
    } catch (e) {
      print('[RECONNECT] ❌ Error configurando servicios: $e');
      throw e;
    }
  }
  
  /// Detener sistema de reconexión automática
  void stopReconnection() {
    _reconnectionTimer?.cancel();
    _reconnectionTimer = null;
    _isAttemptingReconnection = false;
    print('[RECONNECT] ⏹️ Sistema de reconexión detenido');
  }

  /// Iniciar monitoreo de conexión cada minuto
  void _startConnectionMonitoring() {
    _connectionCheckTimer = Timer.periodic(_connectionCheckInterval, (timer) async {
      await _checkConnectionHealth();
    });
    print('[CONNECTION_CHECK] 🔍 Sistema de monitoreo de conexión iniciado (cada 1 minuto)');
  }
  
  /// Verificar salud de la conexión
  Future<void> _checkConnectionHealth() async {
    // Solo verificar si hay una conexión activa
    if (!isConnected || _isCheckingConnection) {
      return;
    }
    
    _isCheckingConnection = true;
    
    try {
      print('[CONNECTION_CHECK] 🔍 Verificando conexión con la manilla...');
      
      // Enviar comando STATUS y esperar respuesta
      final responseReceived = await sendCommandWithResponse(BraceletCommand.status);
      
      if (!responseReceived) {
        // No se recibió respuesta - marcar como desconectada
        print('[CONNECTION_CHECK] ⚠️ Manilla no responde - marcando como desconectada');
        await _handleConnectionLost();
      } else {
        print('[CONNECTION_CHECK] ✅ Conexión saludable');
      }
    } catch (e) {
      print('[CONNECTION_CHECK] ❌ Error verificando conexión: $e');
    } finally {
      _isCheckingConnection = false;
    }
  }
  
  /// Manejar pérdida de conexión detectada
  Future<void> _handleConnectionLost() async {
    if (_connectedDevice == null) return;
    
    // Actualizar estado a desconectado
    _connectedDevice = _connectedDevice!.copyWith(
      connectionStatus: BraceletConnectionStatus.disconnected,
    );
    _connectionStatusController.add(BraceletConnectionStatus.disconnected);
    
    notifyListeners();
    
    // Enviar notificación de desconexión
    try {
      final notificationService = NotificationService();
      await notificationService.showBraceletDisconnectedNotification();
    } catch (e) {
      print('[CONNECTION_CHECK] Error enviando notificación: $e');
    }
    
    // Iniciar reconexión automática si está habilitada
    if (_savedBracelet != null) {
      final shouldReconnect = await BraceletStorageService.shouldAutoReconnect();
      if (shouldReconnect) {
        print('[CONNECTION_CHECK] 🔄 Iniciando reconexión automática...');
        _startReconnectionLoop();
      }
    }
  }
  
  @override
  void dispose() {
    _reconnectionTimer?.cancel();
    _connectionCheckTimer?.cancel();
    _connectionSubscription?.cancel();
    _characteristicSubscription?.cancel();
    super.dispose();
  }
}
