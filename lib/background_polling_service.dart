import 'package:workmanager/workmanager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'screens/firebase_options.dart'; // Importante para inicializar Firebase correctamente

const String fetchNotificationsTask = "fetchNotificationsTask";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == fetchNotificationsTask) {
      print("Workmanager: Ejecutando tarea de fondo $task");
      try {
        // Inicializar Firebase
        // Intenta usar DefaultFirebaseOptions si está disponible, si no, initializeApp básico
        try {
          await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        } catch (e) {
          await Firebase.initializeApp();
        }
        
        // Obtener ID del usuario actual desde SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('current_user_id');
        
        if (userId == null) {
          print("Workmanager: No hay usuario logueado (según SharedPreferences)");
          return Future.value(true);
        }
        
        print("Workmanager: Buscando notificaciones para $userId");
        
        // Re-programar la siguiente ejecución para mantener el ciclo "agresivo"
        // Intentamos ejecutar cada 2 minutos (Android puede limitar esto a mínimo 10-15 min si detecta abuso,
        // pero OneTimeTask suele ser más flexible que PeriodicTask)
        Workmanager().registerOneOffTask(
          "fetch_notifications_aggressive_${DateTime.now().millisecondsSinceEpoch}",
          fetchNotificationsTask,
          initialDelay: Duration(minutes: 2),
          constraints: Constraints(
            networkType: NetworkType.connected,
          ),
          existingWorkPolicy: ExistingWorkPolicy.append,
        );
        
        // Consultar notificaciones no leídas en Firestore
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notificaciones_pendientes')
            .where('leida', isEqualTo: false)
            .get();
            
        if (snapshot.docs.isNotEmpty) {
          print("Workmanager: ${snapshot.docs.length} notificaciones encontradas");
          
          // Inicializar notificaciones locales
          final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
              FlutterLocalNotificationsPlugin();
              
          const AndroidInitializationSettings initializationSettingsAndroid =
              AndroidInitializationSettings('@mipmap/ic_launcher');
          const InitializationSettings initializationSettings =
              InitializationSettings(android: initializationSettingsAndroid);
              
          await flutterLocalNotificationsPlugin.initialize(initializationSettings);
          
          // Mostrar cada notificación
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final title = data['titulo'] as String? ?? 'Notificación';
            final body = data['mensaje'] as String? ?? 'Tienes un mensaje nuevo';
            
            // ID único entero para la notificación
            final notificationId = doc.id.hashCode;
            
            const AndroidNotificationDetails androidPlatformChannelSpecifics =
                AndroidNotificationDetails(
              'background_channel',
              'Notificaciones en segundo plano',
              channelDescription: 'Notificaciones recibidas mientras la app estaba cerrada',
              importance: Importance.max,
              priority: Priority.high,
            );
            
            const NotificationDetails platformChannelSpecifics =
                NotificationDetails(android: androidPlatformChannelSpecifics);
                
            await flutterLocalNotificationsPlugin.show(
              notificationId,
              title,
              body,
              platformChannelSpecifics,
            );
            
            // Marcar como 'notificada_en_fondo' para evitar spam si Workmanager corre de nuevo
            // Nota: No marcamos 'leida' = true para que el usuario aún la vea en la UI de notificaciones dentro de la app
            await doc.reference.update({'notified_bg': true});
          }
        } else {
          print("Workmanager: No hay nuevas notificaciones");
        }

        // ==============================================================================
        // NUEVO: Verificar cumplimiento de pacientes (Solo si es cuidador con configuración)
        // ==============================================================================
        final toleranceStr = prefs.getString('caregiver_compliance_tolerance');
        
        if (toleranceStr != null) {
          int toleranceMinutes = 15; // Default
          if (toleranceStr.contains('1 minuto')) toleranceMinutes = 1;
          else if (toleranceStr.contains('3 minutos')) toleranceMinutes = 3;
          else if (toleranceStr.contains('5 minutos')) toleranceMinutes = 5;
          else if (toleranceStr.contains('10 minutos')) toleranceMinutes = 10;
          else if (toleranceStr.contains('15 minutos')) toleranceMinutes = 15;
          
          print("Workmanager: Verificando cumplimiento de pacientes (Tolerancia: $toleranceMinutes min)");
          
          final now = DateTime.now();
          final toleranceTime = now.subtract(Duration(minutes: toleranceMinutes));
          final startOfDay = DateTime(now.year, now.month, now.day);
          
          // 1. Obtener pacientes asignados
          final cuidadoresSnapshot = await FirebaseFirestore.instance
              .collection('cuidadores')
              .where('cuidadorId', isEqualTo: userId)
              .where('estado', isEqualTo: 'aceptado')
              .get();
              
          if (cuidadoresSnapshot.docs.isNotEmpty) {
            final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin(); // Re-instanciar por si acaso
            
            for (final cuidadorDoc in cuidadoresSnapshot.docs) {
              final pacienteId = cuidadorDoc.data()['pacienteId'] as String;
              
              // 2. Buscar confirmaciones pendientes y atrasadas de este paciente
              // Que sean de HOY, que sigan PENDING, que ya haya pasado el tiempo de tolerancia
              // Y que NO hayan sido notificadas ya como alerta
              final confirmationsSnapshot = await FirebaseFirestore.instance
                  .collection('reminder_confirmations')
                  .where('userId', isEqualTo: pacienteId)
                  .where('status', isEqualTo: 'PENDING')
                  .where('scheduledTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
                  .where('scheduledTime', isLessThan: Timestamp.fromDate(toleranceTime))
                  .get();
                  
              for (final confDoc in confirmationsSnapshot.docs) {
                final data = confDoc.data();
                
                // Evitar notificar doble
                if (data.containsKey('notified_missed_alert') && data['notified_missed_alert'] == true) {
                  continue;
                }
                
                // Obtener título del recordatorio para el mensaje
                final reminderId = data['reminderId'];
                String reminderTitle = 'Recordatorio';
                try {
                  final reminderDoc = await FirebaseFirestore.instance.collection('reminders_new').doc(reminderId).get();
                  if (reminderDoc.exists) {
                    reminderTitle = reminderDoc.data()?['title'] ?? 'Recordatorio';
                  }
                } catch (e) {
                  print("Error obteniendo título recordatorio: $e");
                }
                
                // Enviar notificación local al cuidador
                print("⚠️ ALERTA: Paciente $pacienteId no confirmó $reminderTitle");
                
                const AndroidNotificationDetails androidPlatformChannelSpecifics =
                    AndroidNotificationDetails(
                  'compliance_channel',
                  'Alertas de Cumplimiento',
                  channelDescription: 'Alertas cuando un paciente olvida un recordatorio',
                  importance: Importance.max,
                  priority: Priority.high,
                  color: Colors.redAccent,
                );
                
                const NotificationDetails platformChannelSpecifics =
                    NotificationDetails(android: androidPlatformChannelSpecifics);
                    
                await flutterLocalNotificationsPlugin.show(
                  confDoc.id.hashCode, // ID único basado en el doc
                  '⚠️ Alerta de Incumplimiento',
                  'El paciente no ha confirmado: $reminderTitle',
                  platformChannelSpecifics,
                );
                
                // Marcar como notificado para no repetir
                await confDoc.reference.update({'notified_missed_alert': true});
              }
            }
          }
        }
        
      } catch (e) {
        print("Workmanager Error: $e");
        return Future.value(false);
      }
    }
    return Future.value(true);
  });
}

class BackgroundPollingService {
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false, // Poner true para ver logs en consola de debug
    );
  }

  static Future<void> startAggressivePolling() async {
    // Cancelar todo lo anterior para evitar duplicados
    await Workmanager().cancelAll();
    
    // Iniciar el ciclo inmediato (o con breve retraso)
    await Workmanager().registerOneOffTask(
      "fetch_notifications_init",
      fetchNotificationsTask,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      initialDelay: Duration(seconds: 10), // Casi inmediato al inicio
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
    print("Workmanager: Polling agresivo iniciado (Ciclo de 2 minutos)");
  }
  
  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
  }
}
