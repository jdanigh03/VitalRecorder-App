import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Stream para manejar clics en notificaciones
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
  Future<void> enviarNotificacionPushAUsuario({
    required String destinatarioUserId,
    required String titulo,
    required String mensaje,
    Map<String, String>? data,
  }) async {
    try {
      // Crear notificación pendiente en Firestore
      await _crearNotificacionPendiente(
        destinatarioUserId: destinatarioUserId,
        titulo: titulo,
        mensaje: mensaje,
        data: data,
      );

      // Intentar enviar Push mediante Backend (simulado o real)
      try {
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
      // Obtener todos los cuidadores del paciente desde su subcolección
      final cuidadoresSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(pacienteId)
          .collection('cuidadores')
          .where('activo', isEqualTo: true)
          .get();

      if (cuidadoresSnapshot.docs.isEmpty) {
        print('No hay cuidadores activos para notificar');
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
          mensaje = '$pacienteNombre ha modificado el recordatorio "$recordatorioTitulo"';
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
          titulo = '¡Alerta de Incumplimiento!';
          mensaje = '$pacienteNombre olvidó su recordatorio "$recordatorioTitulo"';
          tipoNotif = 'alerta_incumplimiento';
          break;
        case 'confirmed':
          titulo = 'Recordatorio completado';
          mensaje = '$pacienteNombre completó "$recordatorioTitulo"';
          break;
        case 'confirmed_late':
          titulo = 'Recordatorio completado tarde';
          mensaje = '$pacienteNombre completó "$recordatorioTitulo" ${detalle ?? 'tarde'}';
          break;
      }

      int notificadosCount = 0;

      for (var doc in cuidadoresSnapshot.docs) {
        final data = doc.data();
        final emailCuidador = data['email'] as String?;
        
        if (emailCuidador != null && emailCuidador.isNotEmpty) {
          // Buscar el userId del cuidador por su email
          final userQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: emailCuidador)
              .where('role', isEqualTo: 'cuidador')
              .limit(1)
              .get();

          if (userQuery.docs.isNotEmpty) {
            final cuidadorUserId = userQuery.docs.first.id;
            
            await enviarNotificacionPushAUsuario(
              destinatarioUserId: cuidadorUserId,
              titulo: titulo,
              mensaje: mensaje,
              data: {
                'tipo': tipoNotif,
                'pacienteId': pacienteId,
                'pacienteNombre': pacienteNombre,
                'recordatorioTitulo': recordatorioTitulo,
                'accion': accion,
              },
            );
            notificadosCount++;
          }
        }
      }
      
      print('✅ Notificaciones de evento "$accion" enviadas a $notificadosCount cuidador(es)');

    } catch (e) {
      print('❌ Error al notificar cuidadores: $e');
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
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
            .toList();
          
          // Ordenar en memoria para evitar requerir índice compuesto
          docs.sort((a, b) {
            final ta = a['timestamp'] as Timestamp?;
            final tb = b['timestamp'] as Timestamp?;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta); // Descendente
          });
          
          return docs;
        });
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

  /// Envía notificación cuando la manilla se reconecta
  Future<void> showBraceletConnectedNotification() async {
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
      999, // Mismo ID para reemplazar la de desconexión si existe
      '🟢 Manilla conectada',
      'La manilla se ha conectado correctamente.',
      platformChannelSpecifics,
    );
    print('📢 Notificación de conexión de manilla enviada');
  }

  Future<int> _getNotificationAnticipationMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    final timeString = prefs.getString('notification_time') ?? '5 minutos antes';
    
    switch (timeString) {
      case 'A la hora exacta': return 0;
      case '5 minutos antes': return 5;
      case '10 minutos antes': return 10;
      case '15 minutos antes': return 15;
      case '30 minutos antes': return 30;
      default: return 5;
    }
  }
}

// Manejar mensajes en segundo plano
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}
