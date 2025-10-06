import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/reminder.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({Key? key}) : super(key: key);

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  // -----------------------------------------------------------
  // Inicialización de notificaciones
  // -----------------------------------------------------------
  Future<void> _initializeNotifications() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // -----------------------------------------------------------
  // Mostrar una notificación inmediata (para prueba)
  // -----------------------------------------------------------
  Future<void> _mostrarNotificacionInstantanea() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'vital_recorder_channel',
      'Recordatorios Vital Recorder',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFF4A90E2),
    );

    const NotificationDetails generalNotificationDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Prueba de notificación',
      'Este es un ejemplo de notificación instantánea',
      generalNotificationDetails,
    );
  }

  // -----------------------------------------------------------
  // Programar notificación para un recordatorio
  // -----------------------------------------------------------
  Future<void> programarNotificacion(Reminder reminder) async {
    final tz.TZDateTime fechaProgramada =
        tz.TZDateTime.from(reminder.dateTime, tz.local);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'vital_recorder_channel',
      'Recordatorios Vital Recorder',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFF4A90E2),
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      reminder.dateTime.millisecondsSinceEpoch ~/ 1000, // ID único
      reminder.title,
      reminder.description.isNotEmpty
          ? reminder.description
          : 'Tienes un recordatorio pendiente',
      fechaProgramada,
      notificationDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // -----------------------------------------------------------
  // Cancelar todas las notificaciones
  // -----------------------------------------------------------
  Future<void> _cancelarTodas() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Todas las notificaciones han sido canceladas'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  // -----------------------------------------------------------
  // Interfaz visual
  // -----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo degradado
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E3A5F), Color(0xFF2D5082), Color(0xFF4A90E2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Botón volver
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 8),

                  const Text(
                    'Notificaciones',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Gestiona las alertas locales de tus recordatorios.',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 30),

                  _botonAccion(
                    texto: 'Probar notificación instantánea',
                    color: Colors.green,
                    icono: Icons.notifications,
                    onPressed: _mostrarNotificacionInstantanea,
                  ),
                  const SizedBox(height: 16),

                  _botonAccion(
                    texto: 'Cancelar todas las notificaciones',
                    color: Colors.redAccent,
                    icono: Icons.cancel_outlined,
                    onPressed: _cancelarTodas,
                  ),
                  const SizedBox(height: 30),

                  const Divider(color: Colors.white54),
                  const SizedBox(height: 10),

                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final reminder = Reminder(
                          id: 'test1',
                          title: 'Tomar agua',
                          description: 'Hidrátate adecuadamente',
                          dateTime: DateTime.now().add(const Duration(seconds: 10)),
                          frequency: 'Una vez',
                          type: 'Salud',
                        );
                        programarNotificacion(reminder);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Notificación programada en 10 segundos'),
                            backgroundColor: Colors.blueAccent,
                          ),
                        );
                      },
                      icon: const Icon(Icons.schedule, color: Colors.white),
                      label: const Text(
                        'Programar notificación de prueba',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A90E2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonAccion({
    required String texto,
    required Color color,
    required IconData icono,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        icon: Icon(icono, color: Colors.white),
        label: Text(
          texto,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
