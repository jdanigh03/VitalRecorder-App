
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

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

  static final StreamController<String?> onNotificationClick = StreamController<String?>.broadcast();

  Future<void> initNotifications() async {
    // Solicitar permiso para recibir notificaciones
    await _firebaseMessaging.requestPermission();

    // Obtener el token del dispositivo (FCM Token)
    final fcmToken = await _firebaseMessaging.getToken();
    print('FCM Token: $fcmToken');

    // Guardar token en Firestore
    if (fcmToken != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': fcmToken,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    // Inicializar el plugin de notificaciones locales
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
        );
        
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          print('Notificación tocada con payload: ${response.payload}');
          onNotificationClick.add(response.payload);
        }
      },
    );

    // Manejar mensajes de Firebase en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
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
        payload: jsonEncode(message.data),
      );
    }
  }

  Future<void> sendLocalNotification(String title, String body, {String? payload}) async {
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
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // ID único basado en tiempo
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
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

      // Intentar enviar Push mediante Backend
      try {
         // Usar 10.0.2.2 para Android Emulator, localhost para iOS/Web.
         // Cambiar si el servidor está en otra IP.
         final url = Uri.parse('http://10.0.2.2:3000/api/notifications/send'); 
         await http.post(
           url,
           headers: {'Content-Type': 'application/json'},
           body: jsonEncode({
             'userId': destinatarioUserId,
             'title': titulo,
             'body': mensaje,
             'data': data,
           }),
         );
         print('✅ Notificación Push enviada al backend');
      } catch (e) {
         print('⚠️ No se pudo enviar al backend (posiblemente no disponible): $e');
      }
      
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

  /// Notifica a los cuidadores sobre eventos del recordatorio
  Future<void> notificarEventoRecordatorio({
    required String pacienteId,
    required String pacienteNombre,
    required String recordatorioTitulo,
    required String accion, // 'created', 'updated', 'paused', 'resumed', 'archived', 'missed', 'confirmed', 'confirmed_late'
    String? detalle, // Para detalles adicionales como "30 min tarde"
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

      String titulo = '';
      String mensaje = '';
      String tipoNotif = 'recordatorio_evento';

      switch (accion) {
        case 'created':
          titulo = '¡Nuevo recordatorio!';
          mensaje = '$pacienteNombre ha creado el recordatorio "$recordatorioTitulo"';
          break;
        case 'updated':
          titulo = 'Recordatorio actualizado';
          mensaje = '$pacienteNombre ha editado el recordatorio "$recordatorioTitulo"';
          break;
        case 'paused':
          titulo = 'Recordatorio pausado';
          mensaje = '$pacienteNombre ha pausado el recordatorio "$recordatorioTitulo"';
          break;
        case 'resumed':
          titulo = 'Recordatorio reanudado';
          mensaje = '$pacienteNombre ha reanudado el recordatorio "$recordatorioTitulo"';
          break;
        case 'archived':
          titulo = 'Recordatorio archivado';
          mensaje = '$pacienteNombre ha archivado el recordatorio "$recordatorioTitulo"';
          break;
        case 'missed':
          titulo = 'Recordatorio omitido';
          mensaje = '$pacienteNombre no aceptó/omitió el recordatorio "$recordatorioTitulo"';
          tipoNotif = 'alerta_adherencia';
          break;
        case 'confirmed':
          // Opcional: Tal vez no notificar confirmaciones normales para no saturar
          // Pero si se pide, se hace.
          titulo = 'Recordatorio completado';
          mensaje = '$pacienteNombre completó el recordatorio "$recordatorioTitulo"';
          break;
        case 'confirmed_late':
          titulo = 'Recordatorio completado con retraso';
          mensaje = '$pacienteNombre completó "$recordatorioTitulo" tarde ($detalle)';
          tipoNotif = 'alerta_adherencia';
          break;
        default:
          titulo = 'Actividad en recordatorio';
          mensaje = '$pacienteNombre: Actividad en "$recordatorioTitulo"';
      }

      // Enviar notificación a cada cuidador
      for (final doc in cuidadoresSnapshot.docs) {
        final cuidadorId = doc.data()['cuidadorId'] as String?;
        if (cuidadorId != null) {
          await enviarNotificacionPushAUsuario(
            destinatarioUserId: cuidadorId,
            titulo: titulo,
            mensaje: mensaje,
            data: {
              'tipo': tipoNotif,
              'pacienteId': pacienteId,
              'recordatorioTitulo': recordatorioTitulo,
              'accion': accion,
            },
          );
        }
      }

      print('✅ Notificaciones de evento "$accion" enviadas a ${cuidadoresSnapshot.docs.length} cuidador(es)');
    } catch (e) {
      print('❌ Error notificando evento a cuidadores: $e');
    }
  }

  /// Notifica a los cuidadores sobre la creación o edición de un recordatorio (Legacy support)
  Future<void> notificarCuidadoresSobreRecordatorio({
    required String pacienteId,
    required String pacienteNombre,
    required String recordatorioTitulo,
    required bool esNuevo,
  }) async {
    return notificarEventoRecordatorio(
      pacienteId: pacienteId,
      pacienteNombre: pacienteNombre,
      recordatorioTitulo: recordatorioTitulo,
      accion: esNuevo ? 'created' : 'updated',
    );
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
  
  /// Envía notificación cuando la manilla se desconecta
  Future<void> showBraceletDisconnectedNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'bracelet_status_channel',
      'Bracelet Status Notifications',
      channelDescription: 'Notifications for bracelet connection status',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(
      999, // ID único para notificaciones de manilla
      '⚠️ Manilla desconectada',
      'La conexión con la manilla se ha perdido. Por favor verifica la conexión.',
      platformChannelSpecifics,
    );
    print('📢 Notificación de desconexión de manilla enviada');
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

