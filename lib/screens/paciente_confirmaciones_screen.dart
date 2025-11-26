import 'package:flutter/material.dart';
import '../models/reminder_new.dart';
import '../models/reminder_confirmation.dart';
import '../reminder_service_new.dart';
import 'package:intl/intl.dart';

class PacienteConfirmacionesScreen extends StatefulWidget {
  const PacienteConfirmacionesScreen({Key? key}) : super(key: key);

  @override
  State<PacienteConfirmacionesScreen> createState() =>
      _PacienteConfirmacionesScreenState();
}

class _PacienteConfirmacionesScreenState
    extends State<PacienteConfirmacionesScreen> {
  final ReminderServiceNew _reminderService = ReminderServiceNew();
  bool _isLoading = true;
  List<_ConfirmationWithReminder> _pendingConfirmations = [];

  @override
  void initState() {
    super.initState();
    _loadPendingConfirmations();
  }

  Future<void> _loadPendingConfirmations() async {
    setState(() => _isLoading = true);

    try {
      // Obtener confirmaciones pendientes de hoy
      final confirmations =
          await _reminderService.getPendingConfirmationsToday();

      // Obtener detalles de cada recordatorio
      final List<_ConfirmationWithReminder> items = [];

      for (final confirmation in confirmations) {
        final reminder =
            await _reminderService.getReminderById(confirmation.reminderId);
        if (reminder != null) {
          items.add(_ConfirmationWithReminder(
            confirmation: confirmation,
            reminder: reminder,
          ));
        }
      }

      // Ordenar por hora programada
      items.sort((a, b) =>
          a.confirmation.scheduledTime.compareTo(b.confirmation.scheduledTime));

      setState(() {
        _pendingConfirmations = items;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando confirmaciones: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmReminder(
    ReminderConfirmation confirmation,
    ReminderNew reminder,
  ) async {
    try {
      // Mostrar diálogo de confirmación
      final notes = await _showConfirmDialog(reminder);
      if (notes == null) return; // Usuario canceló

      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(color: Color(0xFF4A90E2)),
        ),
      );

      // Confirmar
      final success = await _reminderService.confirmReminder(
        reminderId: confirmation.reminderId,
        scheduledTime: confirmation.scheduledTime,
        notes: notes.isEmpty ? null : notes,
      );

      Navigator.pop(context); // Cerrar loading

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('¡Recordatorio confirmado!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Recargar lista
        _loadPendingConfirmations();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al confirmar'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Cerrar loading si hay error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _showConfirmDialog(ReminderNew reminder) async {
    final notesController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF4A90E2)),
            SizedBox(width: 12),
            Expanded(child: Text('Confirmar')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Confirmas que has ${reminder.type == 'medication' ? 'tomado' : 'completado'}:',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              reminder.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Notas opcionales...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, notesController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF4A90E2),
            ),
            child: Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        title: const Text(
          'Recordatorios de Hoy',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPendingConfirmations,
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _pendingConfirmations.isEmpty
                ? _buildEmptyState()
                : _buildConfirmationsList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            '¡Todo al día!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A5F),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'No tienes recordatorios pendientes',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationsList() {
    final now = DateTime.now();
    final upcoming = _pendingConfirmations
        .where((item) => item.confirmation.scheduledTime.isAfter(now))
        .toList();
    final overdue = _pendingConfirmations
        .where(
            (item) => item.confirmation.scheduledTime.isBefore(now) || item.confirmation.scheduledTime.isAtSameMomentAs(now))
        .toList();

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // Estadísticas del día
        _buildDailyStats(),
        SizedBox(height: 24),

        // Recordatorios vencidos
        if (overdue.isNotEmpty) ...[
          _buildSectionHeader('Pendientes', overdue.length, Colors.orange),
          SizedBox(height: 12),
          ...overdue
              .map((item) => _buildConfirmationCard(item, isOverdue: true)),
          SizedBox(height: 24),
        ],

        // Próximos recordatorios
        if (upcoming.isNotEmpty) ...[
          _buildSectionHeader('Próximos', upcoming.length, Colors.blue),
          SizedBox(height: 12),
          ...upcoming
              .map((item) => _buildConfirmationCard(item, isOverdue: false)),
        ],
      ],
    );
  }

  Widget _buildDailyStats() {
    final total = _pendingConfirmations.length;
    final now = DateTime.now();
    final overdue = _pendingConfirmations
        .where((item) => item.confirmation.scheduledTime.isBefore(now))
        .length;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4A90E2), Color(0xFF2D5082)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF4A90E2).withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              icon: Icons.pending_actions,
              label: 'Pendientes',
              value: '$total',
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          Expanded(
            child: _buildStatItem(
              icon: Icons.warning_amber_rounded,
              label: 'Atrasados',
              value: '$overdue',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 32),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A5F),
          ),
        ),
        SizedBox(width: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationCard(
    _ConfirmationWithReminder item, {
    required bool isOverdue,
  }) {
    final confirmation = item.confirmation;
    final reminder = item.reminder;
    final timeFormat = DateFormat('HH:mm');
    final now = DateTime.now();
    final minutesUntil =
        confirmation.scheduledTime.difference(now).inMinutes;

    final color = reminder.type == 'medication' ? Colors.blue : Colors.green;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue ? Colors.orange.shade200 : color.shade200,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _confirmReminder(confirmation, reminder),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Hora
                Container(
                  width: 70,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? Colors.orange.shade50
                        : color.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: isOverdue ? Colors.orange : color,
                        size: 24,
                      ),
                      SizedBox(height: 4),
                      Text(
                        timeFormat.format(confirmation.scheduledTime),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isOverdue ? Colors.orange : color,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            reminder.type == 'medication'
                                ? Icons.medication
                                : Icons.directions_run,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          SizedBox(width: 4),
                          Text(
                            reminder.type == 'medication'
                                ? 'Medicamento'
                                : 'Actividad',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        reminder.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      if (reminder.description.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          reminder.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      SizedBox(height: 8),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOverdue
                              ? Colors.orange.shade100
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isOverdue
                              ? '¡Atrasado ${-minutesUntil} min!'
                              : 'En $minutesUntil minutos',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isOverdue ? Colors.orange[700] : Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Botón confirmar
                Icon(
                  Icons.check_circle_outline,
                  color: isOverdue ? Colors.orange : color,
                  size: 32,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmationWithReminder {
  final ReminderConfirmation confirmation;
  final ReminderNew reminder;

  _ConfirmationWithReminder({
    required this.confirmation,
    required this.reminder,
  });
}
