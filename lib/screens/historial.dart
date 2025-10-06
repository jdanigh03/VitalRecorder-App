// ======================================
// ARCHIVO: lib/screens/historial.dart
// ======================================
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/reminder.dart';
import 'agregar_recordatorio.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({Key? key}) : super(key: key);

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _notificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  // Inicializar notificaciones (para cancelar cuando se borre o complete)
  Future<void> _initializeNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);
    await _notificationsPlugin.initialize(settings);
  }

  // Usamos el mismo id con el que se programó: msSinceEpoch ~/ 1000
  Future<void> _cancelNotification(Reminder reminder) async {
    final int notifId = reminder.dateTime.millisecondsSinceEpoch ~/ 1000;
    await _notificationsPlugin.cancel(notifId);
  }

  // Marcar recordatorio como completado / pendiente
  Future<void> _toggleComplete(Reminder reminder) async {
    try {
      final newValue = !reminder.isCompleted;
      await _firestore.collection('reminders').doc(reminder.id).update({
        'isCompleted': newValue,
      });

      // Si ahora quedó "completado", cancelamos su notificación pendiente.
      if (newValue) {
        await _cancelNotification(reminder);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newValue
                ? 'Recordatorio marcado como completado'
                : 'Recordatorio marcado como pendiente'),
            backgroundColor: newValue ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Eliminar recordatorio
  Future<void> _deleteReminder(Reminder reminder) async {
    try {
      await _firestore.collection('reminders').doc(reminder.id).delete();
      await _cancelNotification(reminder);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recordatorio eliminado'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Stream en tiempo real de todos los recordatorios del usuario (más recientes primero)
  Stream<List<Reminder>> _getUserReminders() {
  final user = _auth.currentUser;
  if (user == null) return const Stream.empty();

  return _firestore
      .collection('reminders')
      .where('userId', isEqualTo: user.uid)
      .orderBy('dateTime', descending: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data();

      // Normaliza dateTime: puede venir como Timestamp o String
      DateTime parsedDate;
      final rawDt = data['dateTime'];
      if (rawDt is Timestamp) {
        parsedDate = rawDt.toDate();
      } else if (rawDt is String) {
        parsedDate = DateTime.tryParse(rawDt) ?? DateTime.now();
      } else {
        parsedDate = DateTime.now();
      }

      return Reminder(
        id: doc.id,
        title: (data['title'] ?? '').toString(),
        description: (data['description'] ?? '').toString(),
        dateTime: parsedDate,
        frequency: (data['frequency'] ?? 'Una vez').toString(),
        type: (data['type'] ?? 'General').toString(),
        isCompleted: (data['isCompleted'] ?? false) as bool,
      );
    }).toList();
  });
}

  // Interfaz visual
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
            child: Column(
              children: [
                const SizedBox(height: 10),
                const Text(
                  'Historial de Recordatorios',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Visualiza y administra tus recordatorios creados',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 20),

                Expanded(
                  child: StreamBuilder<List<Reminder>>(
                    stream: _getUserReminders(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }

                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Error al cargar: ${snapshot.error}\n'
                              'Si Firestore solicita índice, créalo en la consola (userId ASC, dateTime DESC).',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                          child: Text(
                            'No hay recordatorios aún',
                            style: TextStyle(color: Colors.white70, fontSize: 18),
                          ),
                        );
                      }

                      final reminders = snapshot.data!;
                      return ListView.builder(
                        itemCount: reminders.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        itemBuilder: (context, index) {
                          final reminder = reminders[index];
                          final fecha = reminder.dateTime;
                          final fechaFormateada =
                              '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')} '
                              '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: reminder.isCompleted ? Colors.green[100] : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ListTile(
                              leading: Icon(
                                reminder.isCompleted
                                    ? Icons.check_circle
                                    : Icons.notifications_active_outlined,
                                color: reminder.isCompleted
                                    ? Colors.green
                                    : const Color(0xFF4A90E2),
                                size: 32,
                              ),
                              title: Text(
                                reminder.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: reminder.isCompleted
                                      ? Colors.green[900]
                                      : const Color(0xFF1E3A5F),
                                  decoration:
                                      reminder.isCompleted ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              subtitle: Text(
                                '${reminder.description.isNotEmpty ? '${reminder.description}\n' : ''}'
                                'Fecha: $fechaFormateada\n'
                                'Frecuencia: ${reminder.frequency}\n'
                                'Tipo: ${reminder.type}',
                                style: const TextStyle(color: Colors.black87),
                              ),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'completar') {
                                    _toggleComplete(reminder);
                                  } else if (value == 'eliminar') {
                                    _deleteReminder(reminder);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'completar',
                                    child: Text(reminder.isCompleted
                                        ? 'Marcar como pendiente'
                                        : 'Marcar como completado'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'eliminar',
                                    child: Text('Eliminar'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Botón flotante para agregar nuevo recordatorio
          Positioned(
            bottom: 30,
            right: 30,
            child: FloatingActionButton(
              backgroundColor: const Color(0xFF4A90E2),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AgregarRecordatorioScreen()),
                );
              },
              child: const Icon(Icons.add, color: Colors.white, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}
