
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initNotifications() async {
    // Solicitar permiso para recibir notificaciones
    await _firebaseMessaging.requestPermission();

    // Obtener el token del dispositivo (FCM Token)
    final fcmToken = await _firebaseMessaging.getToken();
    print('FCM Token: $fcmToken');

    // Inicializar el plugin de notificaciones locales
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Manejar mensajes de Firebase en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: \${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: \${message.notification}');
        showLocalNotification(message);
      }
    });
  }

  void showLocalNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      _flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel', // id
            'High Importance Notifications', // title
            channelDescription: 'This channel is used for important notifications.', // description
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  }

  Future<void> sendLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'local_channel',
      'Local Notifications',
      channelDescription: 'Channel for local notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(
      1, // ID de notificación diferente para evitar colisiones
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<void> showTestNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Channel for testing notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(
      0,
      '¡Notificación de Prueba!',
      'Esta es una notificación de prueba para Vital Recorder.',
      platformChannelSpecifics,
      payload: 'item x',
    );
  }

  /// Envía una notificación push a un usuario específico por su FCM token
  /// Este método requiere un servidor backend o Cloud Functions para funcionar completamente
  Future<void> enviarNotificacionPushAUsuario({
    required String destinatarioUserId,
    required String titulo,
    required String mensaje,
    Map<String, String>? data,
  }) async {
    try {
      // Para una implementación completa, necesitarías:
      // 1. Guardar el FCM token del usuario en Firestore cuando se autentique
      // 2. Usar Cloud Functions o un servidor para enviar la notificación push
      // 3. O usar el Admin SDK desde tu servidor
      
      // Por ahora, vamos a crear un documento en Firestore que actúe como "mensaje pendiente"
      // que el usuario destinatario pueda leer cuando abra la app
      
      await _crearNotificacionPendiente(
        destinatarioUserId: destinatarioUserId,
        titulo: titulo,
        mensaje: mensaje,
        data: data,
      );
      
      print('=== NOTIFICACIÓN PENDIENTE CREADA ===');
      print('Para usuario: $destinatarioUserId');
      print('Título: $titulo');
      print('Mensaje: $mensaje');
      
    } catch (e) {
      print('Error enviando notificación push: $e');
    }
  }

  /// Crea una notificación pendiente en Firestore que el usuario puede leer
  Future<void> _crearNotificacionPendiente({
    required String destinatarioUserId,
    required String titulo,
    required String mensaje,
    Map<String, String>? data,
  }) async {
    final notificacionData = {
      'titulo': titulo,
      'mensaje': mensaje,
      'timestamp': FieldValue.serverTimestamp(),
      'leida': false,
      'tipo': 'invitacion_aceptada',
      if (data != null) 'data': data,
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(destinatarioUserId)
        .collection('notificaciones_pendientes')
        .add(notificacionData);
  }

  /// Obtiene las notificaciones pendientes para el usuario actual
  Stream<List<Map<String, dynamic>>> getNotificacionesPendientes() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notificaciones_pendientes')
        .where('leida', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
            .toList());
  }

  /// Marca una notificación como leída
  Future<void> marcarNotificacionComoLeida(String notificacionId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notificaciones_pendientes')
        .doc(notificacionId)
        .update({'leida': true});
  }
}

// Manejar mensajes en segundo plano
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: \${message.messageId}");
}

