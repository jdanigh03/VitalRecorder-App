import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';
import '../services/reminder_service.dart';
import 'agregar_recordatorio.dart';

class DetalleRecordatorioScreen extends StatefulWidget {
  final Reminder reminder;

  const DetalleRecordatorioScreen({Key? key, required this.reminder}) : super(key: key);

  @override
  State<DetalleRecordatorioScreen> createState() => _DetalleRecordatorioScreenState();
}

class _DetalleRecordatorioScreenState extends State<DetalleRecordatorioScreen> {
  final ReminderService _reminderService = ReminderService();
  late Reminder _currentReminder;
  bool _isLoading = false;

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
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AgregarRecordatorioScreen(reminder: _currentReminder),
                ),
              );
              if (result != null && result is Reminder) {
                setState(() {
                  _currentReminder = result;
                });
              }
            },
          ),
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
                  // Botón de completar (solo si no está completado)
                  if (!_currentReminder.isCompleted)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : () => _showCompleteDialog(),
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle, color: Colors.white),
                        label: Text(
                          _isLoading ? 'Marcando...' : 'Marcar como Completado',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    )
                  else
                    // Estado completado
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green, width: 2),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 24,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'COMPLETADO',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
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
    if (!reminder.isActive) return 'ARCHIVADO';
    if (reminder.isCompleted) return 'COMPLETADO';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dt = reminder.dateTime.toLocal();
    final ca = reminder.createdAt?.toLocal();
    final rd = DateTime(dt.year, dt.month, dt.day);
    final isToday = rd.isAtSameMomentAs(today);
    
    bool isVencido = false;
    bool isPendiente = false;
    
    if (isToday) {
      // Para hoy: vencido si la hora ya pasó, excepto si se creó después de la hora programada
      final createdAfterSchedule = ca != null && ca.isAfter(dt);
      isVencido = dt.isBefore(now) && !createdAfterSchedule;
      isPendiente = dt.isAfter(now) || createdAfterSchedule;
    } else if (rd.isBefore(today)) {
      // Para fechas pasadas: vencido solo si NO fue creado después de la hora programada
      final createdAfterSchedule = ca != null && ca.isAfter(dt);
      isVencido = !createdAfterSchedule;
      isPendiente = createdAfterSchedule;
    } else {
      // Fecha futura
      isPendiente = true;
      isVencido = false;
    }
    
    return isVencido ? 'OMITIDO' : 'PENDIENTE';
  }

  IconData _getStatusIcon(Reminder reminder) {
    if (!reminder.isActive) return Icons.archive;
    if (reminder.isCompleted) return Icons.check_circle;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dt = reminder.dateTime.toLocal();
    final ca = reminder.createdAt?.toLocal();
    final rd = DateTime(dt.year, dt.month, dt.day);
    final isToday = rd.isAtSameMomentAs(today);
    
    bool isVencido = false;
    
    if (isToday) {
      final createdAfterSchedule = ca != null && ca.isAfter(dt);
      isVencido = dt.isBefore(now) && !createdAfterSchedule;
    } else if (rd.isBefore(today)) {
      final createdAfterSchedule = ca != null && ca.isAfter(dt);
      isVencido = !createdAfterSchedule;
    }
    
    return isVencido ? Icons.cancel : Icons.schedule;
  }

  Color _getStatusColor(Reminder reminder) {
    if (!reminder.isActive) return Colors.grey;
    if (reminder.isCompleted) return Colors.green;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dt = reminder.dateTime.toLocal();
    final ca = reminder.createdAt?.toLocal();
    final rd = DateTime(dt.year, dt.month, dt.day);
    final isToday = rd.isAtSameMomentAs(today);
    
    bool isVencido = false;
    
    if (isToday) {
      final createdAfterSchedule = ca != null && ca.isAfter(dt);
      isVencido = dt.isBefore(now) && !createdAfterSchedule;
    } else if (rd.isBefore(today)) {
      final createdAfterSchedule = ca != null && ca.isAfter(dt);
      isVencido = !createdAfterSchedule;
    }
    
    return isVencido ? Colors.red : Colors.orange;
  }

  void _showCompleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 8),
            Text('Confirmar'),
          ],
        ),
        content: Text('¿Marcar "${_currentReminder.title}" como completado?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _markAsCompleted();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsCompleted() async {
    setState(() => _isLoading = true);
    
    try {
      final success = await _reminderService.markAsCompleted(_currentReminder.id, true);
      
      if (success) {
        setState(() {
          _currentReminder = _currentReminder.copyWith(isCompleted: true);
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${_currentReminder.title} marcado como completado'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } else {
        throw Exception('No se pudo marcar como completado');
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
                  child: Text('Error al completar recordatorio: $e'),
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
          // Actualizar el estado local para reflejar el cambio
          setState(() {
            _currentReminder = _currentReminder.copyWith(isActive: false);
            _isLoading = false;
          });

          Navigator.pop(context, _currentReminder); // Devolver el recordatorio actualizado
          
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
