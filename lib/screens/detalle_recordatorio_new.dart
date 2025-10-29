import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reminder_new.dart';
import '../models/reminder_confirmation.dart';
import '../reminder_service_new.dart';

class DetalleRecordatorioNewScreen extends StatefulWidget {
  final ReminderNew reminder;

  const DetalleRecordatorioNewScreen({Key? key, required this.reminder}) : super(key: key);

  @override
  State<DetalleRecordatorioNewScreen> createState() => _DetalleRecordatorioNewScreenState();
}

class _DetalleRecordatorioNewScreenState extends State<DetalleRecordatorioNewScreen> {
  final ReminderServiceNew _reminderService = ReminderServiceNew();
  late ReminderNew _currentReminder;
  bool _isLoading = false;
  List<ReminderConfirmation> _confirmations = [];
  Map<String, dynamic>? _stats;

  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');
  final DateFormat _timeFormatter = DateFormat('HH:mm');
  final DateFormat _dayFormatter = DateFormat('EEEE d \'de\' MMMM', 'es');

  @override
  void initState() {
    super.initState();
    _currentReminder = widget.reminder;
    _loadConfirmations();
  }

  Future<void> _loadConfirmations() async {
    setState(() => _isLoading = true);
    
    try {
      // Cargar confirmaciones del recordatorio
      _confirmations = await _reminderService.getConfirmations(_currentReminder.id);
      
      // Cargar estadísticas
      _stats = await _reminderService.getReminderStats(_currentReminder.id);
      
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error cargando confirmaciones: $e');
      setState(() => _isLoading = false);
    }
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
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive, color: Colors.white),
            onPressed: () => _showArchiveDialog(),
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
                  // Título
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
                ],
              ),
            ),

            // Información del recordatorio
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Estadísticas si están disponibles
                  if (_stats != null) ...[
                    _buildStatsCard(),
                    const SizedBox(height: 16),
                  ],
                  
                  _buildInfoCard(
                    'Rango de fechas',
                    _currentReminder.dateRangeText,
                    Icons.calendar_today,
                    const Color(0xFF8E44AD),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    'Intervalo',
                    _currentReminder.intervalDisplayText,
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
                  
                  // Horarios diarios
                  _buildDailyScheduleCard(),
                  
                  const SizedBox(height: 16),
                  
                  // Historial de confirmaciones
                  _buildConfirmationsSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    final total = _stats!['total'] as int;
    final confirmed = _stats!['confirmed'] as int;
    final missed = _stats!['missed'] as int;
    final adherenceRate = _stats!['adherenceRate'] as String;
    
    Color adherenceColor = Colors.grey;
    if (double.tryParse(adherenceRate) != null) {
      final rate = double.parse(adherenceRate);
      if (rate >= 80) adherenceColor = Colors.green;
      else if (rate >= 60) adherenceColor = Colors.orange;
      else adherenceColor = Colors.red;
    }

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
      child: Column(
        children: [
          Text(
            'Estadísticas de Adherencia',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A5F),
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniStat('Total', '$total', Colors.blue),
              _buildMiniStat('Confirmados', '$confirmed', Colors.green),
              _buildMiniStat('Omitidos', '$missed', Colors.red),
            ],
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: adherenceColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: adherenceColor, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timeline, color: adherenceColor),
                SizedBox(width: 8),
                Text(
                  'Adherencia: $adherenceRate%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: adherenceColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDailyScheduleCard() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, color: Color(0xFF4A90E2)),
              SizedBox(width: 8),
              Text(
                'Horarios Diarios',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _currentReminder.dailyScheduleTimes.map((time) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Color(0xFF4A90E2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Color(0xFF4A90E2)),
                ),
                child: Text(
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A90E2),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationsSection() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_confirmations.isEmpty) {
      return Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.check_circle_outline, size: 48, color: Colors.grey[400]),
              SizedBox(height: 8),
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
        Text(
          'Historial de Confirmaciones',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A5F),
          ),
        ),
        SizedBox(height: 12),
        ..._confirmations.map((confirmation) => _buildConfirmationCard(confirmation)),
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
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 32),
          SizedBox(width: 12),
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
                    color: Color(0xFF1E3A5F),
                  ),
                ),
                if (confirmation.notes != null && confirmation.notes!.isNotEmpty) ...[
                  SizedBox(height: 4),
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

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'medication':
        return Icons.medication;
      case 'activity':
        return Icons.directions_run;
      default:
        return Icons.notifications;
    }
  }

  String _getTypeText(String type) {
    switch (type.toLowerCase()) {
      case 'medication':
        return 'Medicación';
      case 'activity':
        return 'Actividad';
      default:
        return type.isNotEmpty 
            ? '${type[0].toUpperCase()}${type.substring(1).toLowerCase()}'
            : 'Recordatorio';
    }
  }

  void _showArchiveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: const Row(
          children: [
            Icon(Icons.archive_outlined, color: Colors.blueGrey),
            SizedBox(width: 8),
            Text('Archivar Recordatorio'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Estás seguro de que deseas archivar "${_currentReminder.title}"?'),
            const SizedBox(height: 8),
            const Text(
              'El recordatorio ya no aparecerá en la lista principal.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deactivateReminder();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Archivar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deactivateReminder() async {
    setState(() => _isLoading = true);
    
    try {
      final success = await _reminderService.deactivateReminder(_currentReminder.id);
      
      if (success) {
        if (mounted) {
          Navigator.pop(context);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.archive, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${_currentReminder.title} archivado'),
                  ),
                ],
              ),
              backgroundColor: Colors.blueGrey,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
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
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Error al archivar: $e'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }
}
