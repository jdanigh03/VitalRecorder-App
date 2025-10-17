import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/bracelet_device.dart';
import '../models/reminder.dart';
import 'reminder_service.dart';
import 'background_ble_service_simple.dart';

class BraceletService extends ChangeNotifier {
  static final BraceletService _instance = BraceletService._internal();
  factory BraceletService() => _instance;
  BraceletService._internal() {
    // Iniciar escucha global inmediatamente
    _startGlobalBleListener();
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
  
  final List<BluetoothDevice> _discoveredDevices = [];
  bool _isScanning = false;
  bool _isSyncing = false;
  
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
      final reminderService = ReminderService();
      final allReminders = await reminderService.getAllReminders();
      
      // Expandir recordatorios según su frecuencia para hoy
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      List<Reminder> validReminders = [];
      
      for (final reminder in allReminders) {
        final reminderInstances = _generateReminderInstancesForToday(reminder, today);
        validReminders.addAll(reminderInstances);
      }
      
      print("Total recordatorios activos: ${allReminders.length}");
      print("Recordatorios válidos para enviar a manilla: ${validReminders.length}");
      
      // Desactivar recordatorios del pasado (opcional, para limpiar la DB)
      final obsoleteReminders = allReminders.where((reminder) {
        final reminderDate = DateTime(
          reminder.dateTime.year, 
          reminder.dateTime.month, 
          reminder.dateTime.day
        );
        return reminderDate.isBefore(today);
      }).toList();
      
      if (obsoleteReminders.isNotEmpty) {
        print("Desactivando ${obsoleteReminders.length} recordatorios obsoletos...");
        for (final obsoleteReminder in obsoleteReminders) {
          try {
            await reminderService.deactivateReminder(obsoleteReminder.id);
          } catch (e) {
            print("Error desactivando recordatorio ${obsoleteReminder.id}: $e");
          }
        }
      }

      // 1. Sincronizar la hora actual
      await sendCommand(BraceletCommand.syncTime());
      await Future.delayed(const Duration(milliseconds: 200));

      // 2. Borrar recordatorios existentes en la manilla
      await sendCommand(BraceletCommand.clearReminders);
      await Future.delayed(const Duration(milliseconds: 500));

      // 3. Enviar cada recordatorio válido
      for (final reminder in validReminders) {
        final command = BraceletCommand.addReminder(
          reminder.dateTime.hour,
          reminder.dateTime.minute,
          reminder.title,
        );
        await sendCommand(command);
        await Future.delayed(const Duration(milliseconds: 200)); // Pequeña pausa
      }

    } catch (e) {
      print("Error sincronizando recordatorios: $e");
      rethrow; // Propagar el error a la UI
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
  
  /// Generar instancias de recordatorios para hoy según su frecuencia
  List<Reminder> _generateReminderInstancesForToday(Reminder reminder, DateTime today) {
    final List<Reminder> instances = [];
    
    // Verificar si el recordatorio debe activarse hoy según su frecuencia
    final reminderDate = DateTime(
      reminder.dateTime.year,
      reminder.dateTime.month, 
      reminder.dateTime.day
    );
    
    // Si es una fecha futura, no incluir hoy
    if (reminderDate.isAfter(today)) {
      return instances;
    }
    
    // Si es una fecha pasada, verificar frecuencia
    switch (reminder.frequency.toLowerCase()) {
      case 'diario':
        // Solo si la fecha original es hoy o anterior
        if (reminderDate.isBefore(today) || reminderDate.isAtSameMomentAs(today)) {
          instances.add(reminder.copyWith(
            dateTime: DateTime(
              today.year,
              today.month, 
              today.day,
              reminder.dateTime.hour,
              reminder.dateTime.minute
            )
          ));
        }
        break;
        
      case 'cada 8 horas':
        if (reminderDate.isBefore(today) || reminderDate.isAtSameMomentAs(today)) {
          // Generar 3 instancias: hora original, +8h, +16h
          for (int i = 0; i < 3; i++) {
            final instanceTime = reminder.dateTime.add(Duration(hours: 8 * i));
            instances.add(reminder.copyWith(
              dateTime: DateTime(
                today.year,
                today.month,
                today.day,
                instanceTime.hour,
                instanceTime.minute
              )
            ));
          }
        }
        break;
        
      case 'cada 12 horas':
        if (reminderDate.isBefore(today) || reminderDate.isAtSameMomentAs(today)) {
          // Generar 2 instancias: hora original, +12h
          for (int i = 0; i < 2; i++) {
            final instanceTime = reminder.dateTime.add(Duration(hours: 12 * i));
            instances.add(reminder.copyWith(
              dateTime: DateTime(
                today.year,
                today.month,
                today.day,
                instanceTime.hour,
                instanceTime.minute
              )
            ));
          }
        }
        break;
        
      case 'semanal':
        // Solo si ha pasado al menos una semana o es el día original
        final daysSinceOriginal = today.difference(reminderDate).inDays;
        if (daysSinceOriginal >= 0 && daysSinceOriginal % 7 == 0) {
          instances.add(reminder.copyWith(
            dateTime: DateTime(
              today.year,
              today.month,
              today.day, 
              reminder.dateTime.hour,
              reminder.dateTime.minute
            )
          ));
        }
        break;
        
      case 'mensual':
        // Solo si es el mismo día del mes
        if (today.day == reminder.dateTime.day && 
            (today.isAfter(reminderDate) || today.isAtSameMomentAs(reminderDate))) {
          instances.add(reminder.copyWith(
            dateTime: DateTime(
              today.year,
              today.month,
              today.day,
              reminder.dateTime.hour, 
              reminder.dateTime.minute
            )
          ));
        }
        break;
        
      default: // 'Una vez' o 'Personalizado'
        // Solo si es exactamente hoy
        if (reminderDate.isAtSameMomentAs(today)) {
          instances.add(reminder);
        }
        break;
    }
    
    return instances;
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
      print("[GLOBAL BLE] ✅ Respuesta recibida: $response");

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
      
      // Obtener recordatorios activos para encontrar el que corresponde al índice
      final reminderService = ReminderService();
      final allReminders = await reminderService.getAllReminders();
      print('[HANDLE] 📄 Total recordatorios en BD: ${allReminders.length}');
      
      // Filtrar solo recordatorios de hoy para sincronizar con los enviados a la manilla
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      final validReminders = allReminders.where((reminder) {
        final reminderDate = DateTime(
          reminder.dateTime.year, 
          reminder.dateTime.month, 
          reminder.dateTime.day
        );
        return reminderDate.isAtSameMomentAs(today) || reminderDate.isAfter(today);
      }).toList();
      
      print('[HANDLE] 📅 Recordatorios válidos para hoy: ${validReminders.length}');
      
      // Aplicar la misma lógica de generación de instancias que en syncRemindersToBracelet
      List<Reminder> syncedReminders = [];
      for (final reminder in validReminders) {
        final reminderInstances = _generateReminderInstancesForToday(reminder, today);
        syncedReminders.addAll(reminderInstances);
      }
      
      print('[HANDLE] 🔄 Recordatorios sincronizados: ${syncedReminders.length}');
      for (int i = 0; i < syncedReminders.length; i++) {
        print('[HANDLE] [$i] ${syncedReminders[i].title} - ${syncedReminders[i].id}');
      }
      
      // Encontrar el recordatorio correspondiente al índice
      if (reminderIndex < syncedReminders.length) {
        final completedReminder = syncedReminders[reminderIndex];
        print('[HANDLE] ✅ Recordatorio encontrado: "${completedReminder.title}" (ID: ${completedReminder.id})');
        
        // Marcar como completado en Firestore
        final success = await reminderService.markAsCompleted(completedReminder.id, true);
        
        if (success) {
          print('[HANDLE] 🎆 ¡Recordatorio "${completedReminder.title}" marcado como completado en Firestore!');
          
          // Mostrar notificación de recordatorio completado
          await BackgroundBleService.showReminderCompletedNotification(completedReminder.title);
          print('[HANDLE] 🔔 Notificación enviada');
          
          // Limpiar estado de recordatorio activo
          _activeReminderIndex = null;
          _activeReminderTitle = null;
          
          // Notificar a los listeners que hubo un cambio
          notifyListeners();
          print('[HANDLE] 📡 Listeners notificados');
        } else {
          print('[HANDLE] ❌ Error marcando recordatorio como completado en Firestore');
        }
      } else {
        print('[HANDLE] ⚠️ Índice de recordatorio $reminderIndex fuera de rango (max: ${syncedReminders.length - 1})');
      }
      
    } catch (e) {
      print('[HANDLE] 💥 Error manejando confirmación por botón: $e');
      print('[HANDLE] Stack trace: ${StackTrace.current}');
    }
  }
  
  /// Manejar activación de recordatorio en la manilla  
  void _handleReminderActivated(int reminderIndex) async {
    try {
      print('Recordatorio $reminderIndex activado en la manilla');
      
      // Obtener información del recordatorio para mostrar en la UI
      final reminderService = ReminderService();
      final allReminders = await reminderService.getAllReminders();
      
      // Filtrar y generar instancias igual que en la sincronización
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      final validReminders = allReminders.where((reminder) {
        final reminderDate = DateTime(
          reminder.dateTime.year, 
          reminder.dateTime.month, 
          reminder.dateTime.day
        );
        return reminderDate.isAtSameMomentAs(today) || reminderDate.isAfter(today);
      }).toList();
      
      List<Reminder> syncedReminders = [];
      for (final reminder in validReminders) {
        final reminderInstances = _generateReminderInstancesForToday(reminder, today);
        syncedReminders.addAll(reminderInstances);
      }
      
      // Actualizar estado del recordatorio activo
      if (reminderIndex < syncedReminders.length) {
        final activeReminder = syncedReminders[reminderIndex];
        _activeReminderIndex = reminderIndex;
        _activeReminderTitle = activeReminder.title;
        
        print('Recordatorio activo: "${activeReminder.title}"');
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
  
  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _characteristicSubscription?.cancel();
    super.dispose();
  }
}
