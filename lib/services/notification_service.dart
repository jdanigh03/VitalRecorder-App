
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Obtiene los minutos de anticipación configurados por el usuario
  Future<int> _getNotificationAnticipationMinutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final anticipationSetting = prefs.getString('notification_time') ?? '5 minutos antes';
      
      // Extraer número de minutos del texto
      if (anticipationSetting.contains('5 minutos')) return 5;
      if (anticipationSetting.contains('10 minutos')) return 10;
      if (anticipationSetting.contains('15 minutos')) return 15;
      if (anticipationSetting.contains('30 minutos')) return 30;
      if (anticipationSetting.contains('1 hora')) return 60;
      
      return 5; // Por defecto 5 minutos
    } catch (e) {
      print('Error obteniendo configuración de anticipación: $e');
      return 5;
    }
  }

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
    String tipo = 'general',
  }) async {
    final notificacionData = {
      'titulo': titulo,
      'mensaje': mensaje,
      'timestamp': FieldValue.serverTimestamp(),
      'leida': false,
      'tipo': tipo,
      if (data != null) 'data': data,
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(destinatarioUserId)
        .collection('notificaciones_pendientes')
        .add(notificacionData);
  }

  /// Notifica a los cuidadores sobre la creación o edición de un recordatorio
  Future<void> notificarCuidadoresSobreRecordatorio({
    required String pacienteId,
    required String pacienteNombre,
    required String recordatorioTitulo,
    required bool esNuevo,
  }) async {
    try {
      // Obtener todos los cuidadores del paciente
      final cuidadoresSnapshot = await FirebaseFirestore.instance
          .collection('cuidadores')
          .where('pacienteId', isEqualTo: pacienteId)
          .where('estado', isEqualTo: 'aceptado')
          .get();

      if (cuidadoresSnapshot.docs.isEmpty) {
        print('No hay cuidadores para notificar');
        return;
      }

      // Crear el mensaje apropiado
      final accion = esNuevo ? 'ha creado' : 'ha editado';
      final titulo = esNuevo ? '¡Nuevo recordatorio!' : 'Recordatorio actualizado';
      final mensaje = '$pacienteNombre $accion el recordatorio "$recordatorioTitulo"';

      // Enviar notificación a cada cuidador
      for (final doc in cuidadoresSnapshot.docs) {
        final cuidadorId = doc.data()['cuidadorId'] as String?;
        if (cuidadorId != null) {
          await enviarNotificacionPushAUsuario(
            destinatarioUserId: cuidadorId,
            titulo: titulo,
            mensaje: mensaje,
            data: {
              'tipo': 'recordatorio_modificado',
              'pacienteId': pacienteId,
              'recordatorioTitulo': recordatorioTitulo,
              'accion': esNuevo ? 'creado' : 'editado',
            },
          );
        }
      }

      print('✅ Notificaciones enviadas a ${cuidadoresSnapshot.docs.length} cuidador(es)');
    } catch (e) {
      print('❌ Error notificando a cuidadores: $e');
    }
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
  
  /// Envía notificación para recordatorio próximo
  Future<void> sendReminderNotification({
    required String title,
    required String description,
    required DateTime scheduledTime,
    required String type,
  }) async {
    final now = DateTime.now();
    final minutesUntil = scheduledTime.difference(now).inMinutes;
    
    String notificationTitle;
    String notificationBody;
    
    if (minutesUntil >= -5 && minutesUntil <= 0) {
      // Recordatorio es ahora o recién pasó (hasta 5 minutos)
      notificationTitle = '🔔 ¡Es hora!';
      notificationBody = '$title - $description';
    } else if (minutesUntil > 0 && minutesUntil <= 5) {
      // Recordatorio muy próximo (1-5 minutos)
      notificationTitle = '⏰ ¡Próximo recordatorio!';
      notificationBody = '$title en $minutesUntil minutos';
    } else if (minutesUntil > 5 && minutesUntil <= 15) {
      // Recordatorio próximo (6-15 minutos)
      notificationTitle = '⏰ Recordatorio próximo';
      notificationBody = '$title en $minutesUntil minutos';
    } else if (minutesUntil > 15 && minutesUntil <= 60) {
      // Recordatorio en la próxima hora
      notificationTitle = '📅 Tienes un recordatorio pendiente';
      notificationBody = '$title programado para las ${scheduledTime.hour}:${scheduledTime.minute.toString().padLeft(2, '0')}';
    } else if (minutesUntil > 60) {
      // Recordatorio para más tarde
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final scheduledDay = DateTime(scheduledTime.year, scheduledTime.month, scheduledTime.day);
      
      if (scheduledDay.isAtSameMomentAs(tomorrow)) {
        notificationTitle = '🌅 Recordatorio para mañana';
        notificationBody = '$title a las ${scheduledTime.hour}:${scheduledTime.minute.toString().padLeft(2, '0')}';
      } else {
        notificationTitle = '📅 Recordatorio pendiente';
        notificationBody = '$title programado para ${scheduledTime.day}/${scheduledTime.month}';
      }
    } else {
      // Recordatorio muy vencido (más de 5 minutos), no enviar notificación
      print('=== NOTIFICACIÓN CANCELADA ===');
      print('Recordatorio muy vencido: $title');
      print('Minutos transcurridos: ${minutesUntil.abs()}');
      return;
    }
    
    await sendLocalNotification(notificationTitle, notificationBody);
    
    print('=== NOTIFICACIÓN DE RECORDATORIO ENVIADA ===');
    print('Título: $notificationTitle');
    print('Mensaje: $notificationBody');
    print('Minutos restantes: $minutesUntil');
  }
  
  /// Verifica y envía notificaciones para recordatorios pendientes
  Future<void> checkAndSendReminderNotifications(List reminders) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final anticipationMinutes = await _getNotificationAnticipationMinutes();
    
    for (final reminder in reminders) {
      if (reminder.isCompleted) continue;
      
      final dt = reminder.dateTime.toLocal();
      final ca = reminder.createdAt?.toLocal();
      final rd = DateTime(dt.year, dt.month, dt.day);
      final isToday = rd.isAtSameMomentAs(today);
      final minutesUntil = dt.difference(now).inMinutes;
      
      bool shouldNotify = false;
      
      if (isToday) {
        // Para hoy: notificar según configuración de anticipación del usuario
        // Rango: desde anticipationMinutes antes hasta 5 minutos después
        shouldNotify = minutesUntil <= anticipationMinutes && minutesUntil >= -5;
      } else if (rd.isBefore(today)) {
        // Para fechas pasadas: solo notificar casos muy específicos
        final createdAfterSchedule = ca != null && ca.isAfter(dt);
        final createdRecently = ca != null && now.difference(ca).inHours < 2;
        
        // Solo notificar si fue creado después de la hora Y fue creado recientemente (menos de 2 horas)
        shouldNotify = createdAfterSchedule && createdRecently;
      } else {
        // Fecha futura: notificar si es mañana y faltan menos de 24 horas
        final tomorrow = DateTime(now.year, now.month, now.day + 1);
        final isWithinNext24Hours = minutesUntil <= 1440; // 24 horas en minutos
        shouldNotify = rd.isAtSameMomentAs(tomorrow) && isWithinNext24Hours;
      }
      
      if (shouldNotify) {
        await sendReminderNotification(
          title: reminder.title,
          description: reminder.description,
          scheduledTime: reminder.dateTime,
          type: reminder.type,
        );
      }
    }
  }
}

// Manejar mensajes en segundo plano
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: \${message.messageId}");
}

