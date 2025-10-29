import 'package:flutter/material.dart';
import '../models/reminder_new.dart';
import '../models/reminder_confirmation.dart';
import '../reminder_service_new.dart';
import 'package:intl/intl.dart';

class CuidadorAdherenciaScreen extends StatefulWidget {
  final String pacienteId;
  final String pacienteNombre;

  const CuidadorAdherenciaScreen({
    Key? key,
    required this.pacienteId,
    required this.pacienteNombre,
  }) : super(key: key);

  @override
  State<CuidadorAdherenciaScreen> createState() =>
      _CuidadorAdherenciaScreenState();
}

class _CuidadorAdherenciaScreenState extends State<CuidadorAdherenciaScreen> {
  final ReminderServiceNew _reminderService = ReminderServiceNew();
  bool _isLoading = true;
  List<ReminderNew> _reminders = [];
  Map<String, Map<String, dynamic>> _reminderStats = {};
  Map<String, dynamic> _globalStats = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Cargar recordatorios del paciente
      _reminders = await _reminderService.getRemindersByPatient(widget.pacienteId);

      // Cargar estadísticas de cada recordatorio
      int totalReminders = 0;
      int totalConfirmed = 0;
      int totalMissed = 0;
      int totalPending = 0;

      for (final reminder in _reminders) {
        final stats = await _reminderService.getReminderStats(reminder.id);
        _reminderStats[reminder.id] = stats;

        totalReminders += stats['total'] as int;
        totalConfirmed += stats['confirmed'] as int;
        totalMissed += stats['missed'] as int;
        totalPending += stats['pending'] as int;
      }

      // Calcular estadísticas globales
      _globalStats = {
        'total': totalReminders,
        'confirmed': totalConfirmed,
        'missed': totalMissed,
        'pending': totalPending,
        'adherenceRate': totalReminders > 0
            ? (totalConfirmed / totalReminders * 100).toStringAsFixed(1)
            : '0.0',
      };

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error cargando datos: $e');
      setState(() => _isLoading = false);
    }
  }

  Color _getAdherenceColor(String rateString) {
    final rate = double.tryParse(rateString) ?? 0;
    if (rate >= 80) return Colors.green;
    if (rate >= 60) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Adherencia',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            Text(
              widget.pacienteNombre,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _reminders.isEmpty
                ? _buildEmptyState()
                : _buildContent(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'Sin recordatorios',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A5F),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Este paciente no tiene recordatorios activos',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // Estadísticas globales
        _buildGlobalStatsCard(),
        SizedBox(height: 24),

        // Gráfico de adherencia
        _buildAdherenceChart(),
        SizedBox(height: 24),

        // Lista de recordatorios con estadísticas
        Text(
          'Recordatorios Activos',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A5F),
          ),
        ),
        SizedBox(height: 12),
        ..._reminders.map((reminder) => _buildReminderCard(reminder)),
      ],
    );
  }

  Widget _buildGlobalStatsCard() {
    final adherenceRate = _globalStats['adherenceRate'] as String;
    final color = _getAdherenceColor(adherenceRate);

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2D5082)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF1E3A5F).withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Título
          Text(
            'Adherencia General',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 12),

          // Porcentaje principal
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$adherenceRate',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  '%',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 32,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          // Estadísticas en fila
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  Icons.check_circle,
                  'Confirmados',
                  '${_globalStats['confirmed']}',
                  Colors.green,
                ),
              ),
              Expanded(
                child: _buildMiniStat(
                  Icons.cancel,
                  'Omitidos',
                  '${_globalStats['missed']}',
                  Colors.red,
                ),
              ),
              Expanded(
                child: _buildMiniStat(
                  Icons.pending,
                  'Pendientes',
                  '${_globalStats['pending']}',
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAdherenceChart() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, color: Color(0xFF4A90E2)),
              SizedBox(width: 12),
              Text(
                'Resumen de Cumplimiento',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Barra de progreso visual
          _buildProgressBar(),

          SizedBox(height: 20),

          // Leyenda
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem('Confirmados', Colors.green),
              _buildLegendItem('Omitidos', Colors.red),
              _buildLegendItem('Pendientes', Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final total = _globalStats['total'] as int;
    final confirmed = _globalStats['confirmed'] as int;
    final missed = _globalStats['missed'] as int;
    final pending = _globalStats['pending'] as int;

    final confirmedPercent = total > 0 ? (confirmed / total) : 0.0;
    final missedPercent = total > 0 ? (missed / total) : 0.0;
    final pendingPercent = total > 0 ? (pending / total) : 0.0;

    return Column(
      children: [
        Container(
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.grey[200],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Row(
              children: [
                if (confirmedPercent > 0)
                  Flexible(
                    flex: (confirmedPercent * 100).toInt(),
                    child: Container(color: Colors.green),
                  ),
                if (missedPercent > 0)
                  Flexible(
                    flex: (missedPercent * 100).toInt(),
                    child: Container(color: Colors.red),
                  ),
                if (pendingPercent > 0)
                  Flexible(
                    flex: (pendingPercent * 100).toInt(),
                    child: Container(color: Colors.orange),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: 12),
        Text(
          '$confirmed confirmados de $total total',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildReminderCard(ReminderNew reminder) {
    final stats = _reminderStats[reminder.id];
    if (stats == null) return SizedBox.shrink();

    final adherenceRate = stats['adherenceRate'] as String;
    final color = _getAdherenceColor(adherenceRate);
    final typeIcon =
        reminder.type == 'medication' ? Icons.medication : Icons.directions_run;
    final typeColor = reminder.type == 'medication' ? Colors.blue : Colors.green;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: typeColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 28),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        reminder.intervalDisplayText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Porcentaje
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Text(
                    '$adherenceRate%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Estadísticas
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total',
                    '${stats['total']}',
                    Icons.list,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Confirmados',
                    '${stats['confirmed']}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Omitidos',
                    '${stats['missed']}',
                    Icons.cancel,
                    Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Pendientes',
                    '${stats['pending']}',
                    Icons.pending,
                    Colors.orange,
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // Info del recordatorio
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Duración',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        reminder.dateRangeText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Horarios/día',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${reminder.dailyScheduleTimes.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A5F),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
