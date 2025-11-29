import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reminder_new.dart';
import '../models/reminder_confirmation.dart';
import '../services/cuidador_service.dart';
import '../reminder_service_new.dart';

class CuidadorReminderDetailScreen extends StatefulWidget {
  final ReminderNew reminder;
  final dynamic paciente; // Puede ser UserModel o null
  final DateTime? initialDate;

  const CuidadorReminderDetailScreen({
    Key? key, 
    required this.reminder, 
    this.paciente,
    this.initialDate,
  }) : super(key: key);

  @override
  State<CuidadorReminderDetailScreen> createState() => _CuidadorReminderDetailScreenState();
}

class _CuidadorReminderDetailScreenState extends State<CuidadorReminderDetailScreen> {
  final CuidadorService _cuidadorService = CuidadorService();
  final ReminderServiceNew _reminderService = ReminderServiceNew();
  late ReminderNew _currentReminder;
  bool _isLoading = false;
  List<ReminderConfirmation> _confirmations = [];
  List<ReminderConfirmation> _filteredConfirmations = [];
  bool _showAllHistory = false;

  // Formatters
  final DateFormat _timeFormatter = DateFormat('HH:mm');
  final DateFormat _dayFormatter = DateFormat('EEEE d \'de\' MMMM', 'es');

  @override
  void initState() {
    super.initState();
    _currentReminder = widget.reminder;
    _showAllHistory = widget.initialDate == null;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _confirmations = await _reminderService.getConfirmations(_currentReminder.id);
      _filterConfirmations();
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading confirmations: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterConfirmations() {
    if (_showAllHistory || widget.initialDate == null) {
      _filteredConfirmations = List.from(_confirmations);
    } else {
      _filteredConfirmations = _confirmations.where((c) {
        return c.scheduledTime.year == widget.initialDate!.year &&
            c.scheduledTime.month == widget.initialDate!.month &&
            c.scheduledTime.day == widget.initialDate!.day;
      }).toList();
    }
    _filteredConfirmations.sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
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
          if (_currentReminder.isActive)
            IconButton(
              icon: const Icon(Icons.archive_outlined, color: Colors.white),
              onPressed: () => _showArchiveDialog(),
              tooltip: 'Archivar Recordatorio',
            ),
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoCard('Horario', _timeFormatter.format(_currentReminder.startDate), Icons.access_time, const Color(0xFF4A90E2)),
                  const SizedBox(height: 12),
                  _buildInfoCard('Fecha', _dayFormatter.format(_currentReminder.startDate), Icons.calendar_today, const Color(0xFF8E44AD)),
                  const SizedBox(height: 12),
                  _buildInfoCard('Frecuencia', _currentReminder.intervalDisplayText, Icons.repeat, const Color(0xFFE67E22)),
                  const SizedBox(height: 12),
                  _buildInfoCard('Tipo', _getTypeText(_currentReminder.type), _getTypeIcon(_currentReminder.type), const Color(0xFF27AE60)),
                  const SizedBox(height: 12),
                  _buildInfoCard('Estado', _getStatusText(_currentReminder), _getStatusIcon(_currentReminder), _getStatusColor(_currentReminder)),
                  const SizedBox(height: 24),
                  _buildConfirmationsSection(),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F))),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
        return type.isNotEmpty ? '${type[0].toUpperCase()}${type.substring(1).toLowerCase()}' : 'Recordatorio';
    }
  }

  String _getStatusText(ReminderNew reminder) {
    // Verificar si está pausado primero
    if (reminder.isPaused) return 'PAUSADO';
    if (!reminder.isActive) return 'ARCHIVADO';
    
    final nextOccurrence = reminder.getNextOccurrence();
    if (nextOccurrence == null) return 'FINALIZADO';
    
    final now = DateTime.now();
    return nextOccurrence.isBefore(now) ? 'VENCIDO' : 'PENDIENTE';
  }

  IconData _getStatusIcon(ReminderNew reminder) {
    // Verificar si está pausado primero
    if (reminder.isPaused) return Icons.pause_circle;
    if (!reminder.isActive) return Icons.archive;
    
    final nextOccurrence = reminder.getNextOccurrence();
    if (nextOccurrence == null) return Icons.check_circle;
    
    final now = DateTime.now();
    return nextOccurrence.isBefore(now) ? Icons.cancel : Icons.schedule;
  }

  Color _getStatusColor(ReminderNew reminder) {
    // Verificar si está pausado primero
    if (reminder.isPaused) return Colors.grey;
    if (!reminder.isActive) return Colors.blueGrey;
    
    final nextOccurrence = reminder.getNextOccurrence();
    if (nextOccurrence == null) return Colors.green;
    
    final now = DateTime.now();
    return nextOccurrence.isBefore(now) ? Colors.red : Colors.orange;
  }

  void _showArchiveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(children: [Icon(Icons.archive_outlined, color: Colors.blueGrey), SizedBox(width: 8), Text('Archivar Recordatorio')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Estás seguro de que deseas archivar "${_currentReminder.title}"?'),
            const SizedBox(height: 8),
            const Text('El recordatorio ya no aparecerá en las listas principales del paciente.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deactivateReminder();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Archivar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deactivateReminder() async {
    setState(() => _isLoading = true);
    try {
      final success = await _cuidadorService.desactivarRecordatorioPaciente(_currentReminder.userId!, _currentReminder.id);
      if (success) {
        if (mounted) {
          setState(() {
            _currentReminder = _currentReminder.copyWith(isActive: false);
            _isLoading = false;
          });
          Navigator.pop(context, 'deactivated');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(children: [const Icon(Icons.archive, color: Colors.white), const SizedBox(width: 8), Expanded(child: Text('"${_currentReminder.title}" archivado'))]),
              backgroundColor: Colors.blueGrey,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } else {
        throw Exception('No se pudo archivar el recordatorio');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [const Icon(Icons.error, color: Colors.white), const SizedBox(width: 8), Expanded(child: Text('Error al archivar: $e'))]),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _showCuidadorInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(children: [Icon(Icons.supervisor_account, color: Color(0xFF4A90E2)), SizedBox(width: 8), Text('Rol de Cuidador')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Como cuidador, puedes:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text('✓ Ver y archivar recordatorios de tus pacientes'),
            SizedBox(height: 8),
            Text('✓ Monitorear el cumplimiento de tratamientos'),
            SizedBox(height: 8),
            Text('✓ Identificar patrones de adherencia'),
            SizedBox(height: 16),
            const Text('Nota importante:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
            SizedBox(height: 8),
            Text('Solo los pacientes pueden marcar sus recordatorios como completados.', style: TextStyle(color: Colors.grey[700])),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Entendido'))],
      ),
    );
  }
  Widget _buildConfirmationsSection() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_confirmations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.check_circle_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'No hay confirmaciones registradas',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Historial de Confirmaciones',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ),
            if (!_showAllHistory && widget.initialDate != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    _showAllHistory = true;
                    _filterConfirmations();
                  });
                },
                child: const Text('Ver todo'), // Shortened text
              ),
          ],
        ),
        if (!_showAllHistory && widget.initialDate != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Mostrando solo: ${_dayFormatter.format(widget.initialDate!)}',
              style: TextStyle(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (_filteredConfirmations.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'No hay confirmaciones para esta fecha',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          )
        else
          ..._filteredConfirmations.map((confirmation) => _buildConfirmationCard(confirmation)),
      ],
    );
  }

  Widget _buildConfirmationCard(ReminderConfirmation confirmation) {
    Color statusColor;
    IconData statusIcon;
    
    switch (confirmation.status) {
      case ConfirmationStatus.CONFIRMED:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case ConfirmationStatus.MISSED:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case ConfirmationStatus.PENDING:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case ConfirmationStatus.PAUSED:
        statusColor = Colors.grey;
        statusIcon = Icons.pause_circle;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dayFormatter.format(confirmation.scheduledTime),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  _timeFormatter.format(confirmation.scheduledTime),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E3A5F),
                  ),
                ),
                if (confirmation.notes != null && confirmation.notes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    confirmation.notes!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            confirmation.status.displayName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}
