import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'bracelet_service.dart';

class BackgroundBleService {
  static FlutterLocalNotificationsPlugin? _notificationsPlugin;
  
  /// Inicializar el servicio en segundo plano
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();
    
    // Configurar notificaciones locales
    await _initializeNotifications();
    
    // Configurar el servicio
    await service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: true,
        isForegroundMode: true,
        autoStartOnBoot: true,
        notificationChannelId: 'vital_recorder_bg',
        initialNotificationTitle: 'VitalRecorder',
        initialNotificationContent: 'Manteniendo conexión con manilla...',
        foregroundServiceNotificationId: 888,
      ),
    );
  }
  
  /// Inicializar notificaciones locales
  static Future<void> _initializeNotifications() async {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
    
    const androidInitializationSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInitializationSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );
    
    await _notificationsPlugin?.initialize(initializationSettings);
    
    // Crear canal de notificación para Android
    const androidNotificationChannel = AndroidNotificationChannel(
      'vital_recorder_bg',
      'VitalRecorder Background',
      description: 'Mantiene conexión con manilla en segundo plano',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );
    
    await _notificationsPlugin
        ?.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidNotificationChannel);
    
    // Canal adicional para recordatorios completados
    const androidCompletedChannel = AndroidNotificationChannel(
      'vital_recorder_completed',
      'Recordatorios Completados',
      description: 'Notificaciones de recordatorios completados',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    
    await _notificationsPlugin
        ?.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidCompletedChannel);
  }
  
  /// Iniciar el servicio
  static Future<void> startService() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    
    if (!isRunning) {
      await service.startService();
      print('[BG] Servicio BLE iniciado en segundo plano');
    }
  }
  
  /// Detener el servicio
  static Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke('stop');
    print('[BG] Servicio BLE detenido');
  }
  
  /// Verificar si el servicio está corriendo
  static Future<bool> isServiceRunning() async {
    final service = FlutterBackgroundService();
    return await service.isRunning();
  }
  
  /// Entry point del servicio (Android)
  @pragma('vm:entry-point')
  static Future<void> _onStart(ServiceInstance service) async {
    print('[BG] Servicio BLE iniciando...');
    
    // Configurar isolate port para comunicación
    final receivePort = ReceivePort();
    IsolateNameServer.registerPortWithName(receivePort.sendPort, _isolatePortName);
    
    // Variables de estado
    Timer? keepAliveTimer;
    BraceletService? braceletService;
    bool isConnected = false;
    
    // Inicializar BraceletService
    try {
      braceletService = BraceletService();
      await braceletService!.initialize();
      print('[BG] BraceletService inicializado');
    } catch (e) {
      print('[BG] Error inicializando BraceletService: $e');
    }
    
    // Timer principal - verificar conexión cada 30 segundos
    keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        print('[BG] Verificando conexión...');
        
        if (braceletService?.isConnected == true) {
          // Enviar keepalive
          await braceletService!.sendCommand('STATUS');
          
          if (!isConnected) {
            isConnected = true;
            _updateNotification('Conectado a manilla', 'Escuchando confirmaciones...');
          }
          
          print('[BG] Conexión activa - keepalive enviado');
        } else {
          if (isConnected) {
            isConnected = false;
            _updateNotification('Buscando manilla...', 'Intentando reconectar...');
          }
          
          // Intentar reconectar
          print('[BG] Intentando reconectar...');
          await _attemptReconnection(braceletService);
        }
        
      } catch (e) {
        print('[BG] Error en keepalive: $e');
      }
    });
    
    // Escuchar respuestas BLE
    if (braceletService != null) {
      braceletService!.responseStream.listen((response) {
        print('[BG] Respuesta recibida: ${response.response}');
        
        // Procesar confirmaciones de recordatorios
        if (response.response.contains('REMINDER_COMPLETED_BY_BUTTON')) {
          _showReminderCompletedNotification(response.response);
        }
      });
    }
    
    // Escuchar comandos del servicio
    service.on('stop').listen((event) {
      print('[BG] Deteniendo servicio...');
      keepAliveTimer?.cancel();
      service.stopSelf();
    });
    
    // Actualizar notificación inicial
    _updateNotification('VitalRecorder activo', 'Manteniendo conexión con manilla...');
    
    print('[BG] Servicio BLE completamente inicializado');
  }
  
  /// Entry point para iOS (simplificado)
  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    print('[BG] iOS background task iniciado');
    
    // iOS tiene limitaciones más estrictas, pero intentamos mantener BLE activo
    try {
      final braceletService = BraceletService();
      if (braceletService.isConnected) {
        await braceletService.sendCommand('STATUS');
        print('[BG] iOS keepalive enviado');
      }
    } catch (e) {
      print('[BG] Error iOS background: $e');
    }
    
    return true;
  }
  
  /// Intentar reconexión
  static Future<void> _attemptReconnection(BraceletService? braceletService) async {
    if (braceletService == null) return;
    
    try {
      // Buscar dispositivos conocidos
      final devices = braceletService.discoveredDevices;
      
      for (final device in devices) {
        if (device.platformName.contains('Vital Recorder')) {
          print('[BG] Intentando reconectar a ${device.platformName}');
          
          // Intentar conexión (esto requiere que BraceletService tenga método para reconectar por MAC)
          // await braceletService.connectToDevice(device);
          
          if (braceletService.isConnected) {
            print('[BG] Reconexión exitosa');
            break;
          }
        }
      }
    } catch (e) {
      print('[BG] Error en reconexión: $e');
    }
  }
  
  /// Actualizar notificación persistente
  static Future<void> _updateNotification(String title, String body) async {
    if (_notificationsPlugin == null) return;
    
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'vital_recorder_bg',
        'VitalRecorder Background',
        channelDescription: 'Mantiene conexión con manilla en segundo plano',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        playSound: false,
        enableVibration: false,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      ),
    );
    
    try {
      await _notificationsPlugin!.show(
        888,
        title,
        body,
        notificationDetails,
      );
    } catch (e) {
      print('[BG] Error actualizando notificación: $e');
    }
  }
  
  /// Mostrar notificación de recordatorio completado
  static Future<void> _showReminderCompletedNotification(String response) async {
    if (_notificationsPlugin == null) return;
    
    // Extraer información del recordatorio
    String reminderTitle = 'Recordatorio';
    final parts = response.split('"');
    if (parts.length >= 2) {
      reminderTitle = parts[1];
    }
    
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'vital_recorder_completed',
        'Recordatorios Completados',
        channelDescription: 'Notificaciones de recordatorios completados',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    
    try {
      await _notificationsPlugin!.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        '✅ Recordatorio Completado',
        '"$reminderTitle" fue confirmado desde la manilla',
        notificationDetails,
      );
      
      print('[BG] Notificación de recordatorio completado enviada');
    } catch (e) {
      print('[BG] Error enviando notificación: $e');
    }
  }
}