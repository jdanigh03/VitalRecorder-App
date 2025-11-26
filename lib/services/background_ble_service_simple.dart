import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Servicio simplificado para mantener BLE activo
/// Esta es una implementación básica que funciona con las APIs disponibles
class BackgroundBleService {
  static FlutterLocalNotificationsPlugin? _notificationsPlugin;
  static Timer? _keepAliveTimer;
  static bool _isServiceRunning = false;
  
  /// Inicializar el servicio
  static Future<void> initialize() async {
    try {
      await _initializeNotifications();
      print('[BG] Servicio BLE simplificado inicializado');
    } catch (e) {
      print('[BG] Error inicializando servicio: $e');
    }
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
    print('[BG] Notificaciones inicializadas');
  }
  
  /// Iniciar el servicio simplificado
  static Future<void> startService() async {
    if (_isServiceRunning) {
      print('[BG] Servicio ya está ejecutándose');
      return;
    }
    
    _isServiceRunning = true;
    
    // Timer que mantiene la app "activa" para BLE
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      print('[BG] Keepalive - manteniendo BLE activo');
      _showBackgroundNotification();
    });
    
    await _showBackgroundNotification();
    print('[BG] Servicio simplificado iniciado');
  }
  
  /// Detener el servicio
  static Future<void> stopService() async {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    _isServiceRunning = false;
    
    await _cancelBackgroundNotification();
    print('[BG] Servicio simplificado detenido');
  }
  
  /// Verificar si el servicio está corriendo
  static Future<bool> isServiceRunning() async {
    return _isServiceRunning;
  }
  
  /// Mostrar notificación de servicio activo
  static Future<void> _showBackgroundNotification() async {
    if (_notificationsPlugin == null) return;
    
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'vital_recorder_bg_simple',
        'VitalRecorder Background',
        channelDescription: 'Mantiene BLE activo para la manilla',
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
        999,
        'VitalRecorder BLE',
        'Manteniendo conexión con manilla...',
        notificationDetails,
      );
    } catch (e) {
      print('[BG] Error mostrando notificación: $e');
    }
  }
  
  /// Cancelar notificación de fondo
  static Future<void> _cancelBackgroundNotification() async {
    if (_notificationsPlugin == null) return;
    
    try {
      await _notificationsPlugin!.cancel(999);
    } catch (e) {
      print('[BG] Error cancelando notificación: $e');
    }
  }
  
  /// Mostrar notificación de recordatorio completado
  static Future<void> showReminderCompletedNotification(String reminderTitle) async {
    if (_notificationsPlugin == null) return;
    
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
        '"$reminderTitle" confirmado desde la manilla',
        notificationDetails,
      );
      
      print('[BG] Notificación de recordatorio completado enviada');
    } catch (e) {
      print('[BG] Error enviando notificación: $e');
    }
  }
}