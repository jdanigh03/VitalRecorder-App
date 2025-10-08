import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';

class CuidadorReminderDetailScreen extends StatefulWidget {
  final Reminder reminder;

  const CuidadorReminderDetailScreen({Key? key, required this.reminder}) : super(key: key);

  @override
  State<CuidadorReminderDetailScreen> createState() => _CuidadorReminderDetailScreenState();
}

class _CuidadorReminderDetailScreenState extends State<CuidadorReminderDetailScreen> {
  late Reminder _currentReminder;

  // Formatters
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');
  final DateFormat _timeFormatter = DateFormat('HH:mm');
  final DateFormat _dayFormatter = DateFormat('EEEE d \'de\' MMMM', 'es');

  @override
  void initState() {
    super.initState();
    _currentReminder = widget.reminder;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        title: const Text(
          'Detalle del Recordatorio',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context, _currentReminder),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () => _showCuidadorInfo(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con gradiente
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1E3A5F),
                    Color(0xFF2D5082),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Icono grande
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getTypeIcon(_currentReminder.type),
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Título y descripción
                  Text(
                    _currentReminder.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_currentReminder.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _currentReminder.description,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  
                  // Información para cuidadores
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.5), width: 1),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.supervisor_account,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'VISTA DE CUIDADOR',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Este recordatorio pertenece a uno de tus pacientes asignados',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Cards de información
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoCard(
                    'Horario',
                    _timeFormatter.format(_currentReminder.dateTime),
                    Icons.access_time,
                    const Color(0xFF4A90E2),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    'Fecha',
                    _dayFormatter.format(_currentReminder.dateTime),
                    Icons.calendar_today,
                    const Color(0xFF8E44AD),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    'Frecuencia',
                    _currentReminder.frequency,
                    Icons.repeat,
                    const Color(0xFFE67E22),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    'Tipo',
                    _getTypeText(_currentReminder.type),
                    _getTypeIcon(_currentReminder.type),
                    const Color(0xFF27AE60),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    'Estado',
                    _getStatusText(_currentReminder),
                    _getStatusIcon(_currentReminder),
                    _getStatusColor(_currentReminder),
                  ),
                  const SizedBox(height: 24),
                  
                  // Información adicional para cuidadores
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Color(0xFF4A90E2),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Información para Cuidadores',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A5F),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          '• Solo el paciente puede marcar este recordatorio como completado.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• Puedes usar esta información para hacer seguimiento y brindar apoyo.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• Si notas patrones de incumplimiento, considera comunicarte con el paciente.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Métodos auxiliares para iconos y textos
  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'medicación':
      case 'medication':
        return Icons.medication;
      case 'cita':
      case 'appointment':
        return Icons.event;
      case 'tarea':
      case 'activity':
        return Icons.task;
      default:
        return Icons.notifications;
    }
  }

  String _getTypeText(String type) {
    switch (type.toLowerCase()) {
      case 'medicación':
      case 'medication':
        return 'Medicación';
      case 'cita':
      case 'appointment':
        return 'Cita Médica';
      case 'tarea':
      case 'activity':
        return 'Actividad';
      default:
        // Si viene un tipo que no reconocemos, lo capitalizamos
        return type.isNotEmpty 
            ? '${type[0].toUpperCase()}${type.substring(1).toLowerCase()}'
            : 'Recordatorio';
    }
  }

  String _getStatusText(Reminder reminder) {
    if (reminder.isCompleted) {
      return 'COMPLETADO';
    } else if (reminder.dateTime.isBefore(DateTime.now())) {
      return 'OMITIDO';
    } else {
      return 'PENDIENTE';
    }
  }

  IconData _getStatusIcon(Reminder reminder) {
    if (reminder.isCompleted) {
      return Icons.check_circle;
    } else if (reminder.dateTime.isBefore(DateTime.now())) {
      return Icons.cancel;
    } else {
      return Icons.schedule;
    }
  }

  Color _getStatusColor(Reminder reminder) {
    if (reminder.isCompleted) {
      return Colors.green;
    } else if (reminder.dateTime.isBefore(DateTime.now())) {
      return Colors.red;
    } else {
      return Colors.orange;
    }
  }

  void _showCuidadorInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: const Row(
          children: [
            Icon(Icons.supervisor_account, color: Color(0xFF4A90E2)),
            SizedBox(width: 8),
            Text('Rol de Cuidador'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Como cuidador, puedes:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('✓ Ver detalles de recordatorios de tus pacientes'),
            SizedBox(height: 8),
            Text('✓ Monitorear el cumplimiento de tratamientos'),
            SizedBox(height: 8),
            Text('✓ Identificar patrones de adherencia'),
            SizedBox(height: 16),
            Text(
              'Nota importante:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[700]),
            ),
            SizedBox(height: 8),
            Text(
              'Solo los pacientes pueden marcar sus recordatorios como completados. Tu rol es de supervisión y apoyo.',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Entendido'),
          ),
        ],
      ),
    );
  }
}
