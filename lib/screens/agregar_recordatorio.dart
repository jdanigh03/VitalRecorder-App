// ===============================================
// ARCHIVO: lib/screens/agregar_recordatorio.dart
// ===============================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/services.dart';

import '../models/reminder.dart';

class AgregarRecordatorioScreen extends StatefulWidget {
  const AgregarRecordatorioScreen({Key? key}) : super(key: key);

  @override
  State<AgregarRecordatorioScreen> createState() => _AgregarRecordatorioScreenState();
}

class _AgregarRecordatorioScreenState extends State<AgregarRecordatorioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime? _selectedDateTime;
  String _selectedFrequency = 'Una vez';
  String _selectedType = 'Medicación';

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // Inicialización de notificaciones + solicitud de permisos
  // ------------------------------------------------------------
  Future<void> _initializeNotifications() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(settings);

    // Pedir permisos necesarios en Android 12/13/14
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // Android 13+: permiso runtime para notificaciones
    await androidPlugin?.requestNotificationsPermission();

    // Android 12+: exact alarms (lleva al usuario al ajuste si hace falta)
    await androidPlugin?.requestExactAlarmsPermission();
  }

  // ------------------------------------------------------------
  // Programar notificación local
  // ------------------------------------------------------------
  Future<void> _scheduleNotification(Reminder reminder) async {
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

    final int notifId = reminder.dateTime.millisecondsSinceEpoch ~/ 1000;

    try {
      // Intento 1: exacta (recomendado)
      await _notificationsPlugin.zonedSchedule(
        notifId,
        reminder.title,
        reminder.description.isNotEmpty
            ? reminder.description
            : 'Tienes un recordatorio pendiente',
        fechaProgramada,
        notificationDetails,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } on PlatformException catch (e) {
      // Si el sistema no permite exactas, se intenta inexacta
      if (e.code == 'exact_alarms_not_permitted') {
        await _notificationsPlugin.zonedSchedule(
          notifId,
          reminder.title,
          reminder.description.isNotEmpty
              ? reminder.description
              : 'Tienes un recordatorio pendiente',
          fechaProgramada,
          notificationDetails,
          androidAllowWhileIdle: true,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'El sistema no permite alarmas exactas. Se programó como inexacta.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        rethrow;
      }
    }
  }

  // ------------------------------------------------------------
  // Guardar recordatorio en Firestore
  // ------------------------------------------------------------
  Future<void> _saveReminder() async {
    if (_formKey.currentState?.validate() != true || _selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa todos los campos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final reminderId =
        FirebaseFirestore.instance.collection('reminders').doc().id;

    final reminder = Reminder(
      id: reminderId,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      dateTime: _selectedDateTime!,
      frequency: _selectedFrequency,
      type: _selectedType,
    );

    // Mostrar cargando
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      await FirebaseFirestore.instance
          .collection('reminders')
          .doc(reminderId)
          .set({
        // Si tu Reminder.toMap() devuelve DateTime, lo forzamos a Timestamp aquí.
        ...reminder.toMap(),
        'dateTime': Timestamp.fromDate(reminder.dateTime),
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Programar notificación local
      await _scheduleNotification(reminder);

      if (mounted) {
        Navigator.of(context).pop(); // Cerrar loader
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recordatorio guardado y notificación programada'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Volver a la pantalla anterior
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ------------------------------------------------------------
  // Selector de fecha y hora
  // ------------------------------------------------------------
  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
      helpText: 'Selecciona una fecha',
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 5))),
    );
    if (time == null) return;

    setState(() {
      _selectedDateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  // ------------------------------------------------------------
  // Construcción visual
  // ------------------------------------------------------------
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Botón de volver
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 10),
                    const Center(
                      child: Text(
                        'Agregar Recordatorio',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    const Text('Título',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleCtrl,
                      style: const TextStyle(color: Color(0xFF1E3A5F)),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Campo requerido' : null,
                      decoration: _inputDecoration(
                        hint: 'Ej: Tomar medicamento',
                        icon: Icons.title_outlined,
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text('Descripción',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descCtrl,
                      style: const TextStyle(color: Color(0xFF1E3A5F)),
                      decoration: _inputDecoration(
                        hint: 'Detalle opcional',
                        icon: Icons.description_outlined,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),

                    const Text('Fecha y hora',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickDateTime,
                      child: AbsorbPointer(
                        child: TextFormField(
                          style: const TextStyle(color: Color(0xFF1E3A5F)),
                          decoration: _inputDecoration(
                            hint: _selectedDateTime == null
                                ? 'Seleccionar fecha y hora'
                                : DateFormat('dd/MM/yyyy HH:mm')
                                    .format(_selectedDateTime!),
                            icon: Icons.calendar_today_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text('Frecuencia',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedFrequency,
                      style: const TextStyle(color: Color(0xFF1E3A5F)),
                      decoration: _inputDecoration(
                        hint: 'Selecciona frecuencia',
                        icon: Icons.repeat_outlined,
                      ),
                      dropdownColor: Colors.white,
                      items: const [
                        DropdownMenuItem(value: 'Una vez', child: Text('Una vez')),
                        DropdownMenuItem(value: 'Diario', child: Text('Diario')),
                        DropdownMenuItem(value: 'Semanal', child: Text('Semanal')),
                      ],
                      onChanged: (v) => setState(() => _selectedFrequency = v!),
                    ),
                    const SizedBox(height: 20),

                    const Text('Tipo de recordatorio',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      style: const TextStyle(color: Color(0xFF1E3A5F)),
                      decoration: _inputDecoration(
                        hint: 'Tipo de recordatorio',
                        icon: Icons.category_outlined,
                      ),
                      dropdownColor: Colors.white,
                      items: const [
                        DropdownMenuItem(value: 'Medicación', child: Text('Medicación')),
                        DropdownMenuItem(value: 'Tarea', child: Text('Tarea')),
                        DropdownMenuItem(value: 'Cita', child: Text('Cita')),
                      ],
                      onChanged: (v) => setState(() => _selectedType = v!),
                    ),
                    const SizedBox(height: 40),

                    // Botón guardar
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4A90E2).withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _saveReminder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                        ),
                        child: const Text(
                          'Guardar Recordatorio',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400]),
      prefixIcon: Icon(icon, color: const Color(0xFF4A90E2)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    );
  }
}
