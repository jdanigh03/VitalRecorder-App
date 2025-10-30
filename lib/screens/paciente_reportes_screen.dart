import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/analytics_service.dart';
import '../models/reminder_new.dart';
import '../models/user.dart';
import '../reminder_service_new.dart';
import '../services/user_service.dart';
import '../widgets/chart_widgets.dart';
import '../utils/export_utils.dart';
import 'detalle_recordatorio_new.dart';

class PacienteReportesScreen extends StatefulWidget {
  @override
  _PacienteReportesScreenState createState() => _PacienteReportesScreenState();
}

class _PacienteReportesScreenState extends State<PacienteReportesScreen> with TickerProviderStateMixin {
  final ReminderServiceNew _reminderService = ReminderServiceNew();
  final AnalyticsService _analyticsService = AnalyticsService();
  final UserService _userService = UserService();
  late TabController _tabController;
  
  bool _isLoading = false;
  Map<String, dynamic> _stats = {};
  List<ReminderNew> _reminders = [];
  List<Map<String, dynamic>> _trendData = [];
  Map<String, dynamic> _typeDistribution = {};
  UserModel? _currentUser;
  
  // Filtros
  String? _selectedType;
  bool _includeGraphs = true;
  bool _includeDetails = true;

  DateTime _startDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadReportData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    try {
      // Cargar datos del usuario actual
      _currentUser = await _userService.getCurrentUserData();
      
      // Cargar recordatorios del paciente
      final reminders = await _reminderService.getAllReminders();
      
      // Cargar datos de análisis
      final analysisResults = await Future.wait([
        _analyticsService.calculateRealStats(
          startDate: _startDate,
          endDate: _endDate,
          allReminders: reminders,
          allPatients: _currentUser != null ? [_currentUser!] : [],
        ),
        _analyticsService.getTrendData(
          startDate: _startDate,
          endDate: _endDate,
          allReminders: reminders,
        ),
      ]);

      final stats = analysisResults[0] as Map<String, dynamic>;
      final trendData = analysisResults[1] as List<Map<String, dynamic>>;
      
      // Filtrar recordatorios por período y tipo
      final filteredReminders = reminders.where((r) {
        // Filtro por período
        if (!r.startDate.isAfter(_startDate.subtract(Duration(seconds: 1))) ||
            !r.startDate.isBefore(_endDate.add(Duration(days: 1)))) {
          return false;
        }
        
        // Filtro por tipo
        if (_selectedType != null) {
          final matchesType = r.type.toLowerCase().contains(_selectedType!.toLowerCase()) ||
                             (_selectedType == 'Medicación' && r.type.toLowerCase().contains('medic')) ||
                             (_selectedType == 'Tarea' && r.type.toLowerCase().contains('tarea')) ||
                             (_selectedType == 'Cita' && r.type.toLowerCase().contains('cita'));
          if (!matchesType) return false;
        }
        
        return true;
      }).toList();
      
      final typeDistribution = _analyticsService.getTypeDistribution(filteredReminders);

      setState(() {
        _stats = stats;
        _reminders = reminders;
        _trendData = trendData;
        _typeDistribution = typeDistribution;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando datos de reportes: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando datos: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        title: Text(
          'Mis Reportes',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Resumen', icon: Icon(Icons.dashboard, size: 16)),
            Tab(text: 'Adherencia', icon: Icon(Icons.trending_up, size: 16)),
            Tab(text: 'Exportar', icon: Icon(Icons.file_download, size: 16)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadReportData,
            tooltip: 'Actualizar datos',
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingView() : _buildTabContent(),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF4A90E2)),
          SizedBox(height: 16),
          Text(
            'Generando reportes...',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildResumenTab(),
        _buildAdherenciaTab(),
        _buildExportarTab(),
      ],
    );
  }

  Widget _buildResumenTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selector de período
          _buildPeriodSelector(),
          SizedBox(height: 16),
          
          // Filtros
          _buildFilters(),
          SizedBox(height: 20),
          
          // Métricas principales
          Text(
            'Mis Métricas',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          _buildMainMetrics(),
          SizedBox(height: 20),
          
          // Gráfico de tendencias
          Text(
            'Tendencias del Período',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          _buildTrendChart(),
          SizedBox(height: 20),
          
          // Distribución por tipos
          Text(
            'Distribución por Tipos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          _buildTypeDistribution(),
          SizedBox(height: 20),
          
          // Lista de recordatorios
          Text(
            'Mis Recordatorios',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          _buildRemindersList(),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Período del Reporte',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectStartDate,
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today, color: Color(0xFF4A90E2), size: 16),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              DateFormat('dd/MM/yyyy').format(_startDate),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Text('hasta'),
                SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: _selectEndDate,
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today, color: Color(0xFF4A90E2), size: 16),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              DateFormat('dd/MM/yyyy').format(_endDate),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                _buildPeriodButton('7 días', 7),
                SizedBox(width: 8),
                _buildPeriodButton('30 días', 30),
                SizedBox(width: 8),
                _buildPeriodButton('90 días', 90),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String label, int days) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () => _setPeriod(days),
        style: OutlinedButton.styleFrom(
          foregroundColor: Color(0xFF4A90E2),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtros',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _selectedType,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                labelText: 'Tipo de recordatorio',
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Todos los tipos'),
                ),
                DropdownMenuItem<String?>(
                  value: 'Medicación',
                  child: Text('Medicación'),
                ),
                DropdownMenuItem<String?>(
                  value: 'Tarea',
                  child: Text('Tareas'),
                ),
                DropdownMenuItem<String?>(
                  value: 'Cita',
                  child: Text('Citas'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedType = value;
                });
                _loadReportData();
              },
            ),
            if (_selectedType != null) ...[
              SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedType = null;
                  });
                  _loadReportData();
                },
                icon: Icon(Icons.clear, size: 16),
                label: Text('Limpiar Filtro'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[100],
                  foregroundColor: Colors.grey[700],
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMainMetrics() {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          'Total Recordatorios',
          '${_stats['totalRecordatorios'] ?? 0}',
          Icons.notifications,
          Colors.blue,
          '${_stats['recordatoriosActivos'] ?? 0} activos',
        ),
        _buildMetricCard(
          'Mi Adherencia',
          '${_stats['adherenciaGeneral'] ?? 0}%',
          Icons.trending_up,
          Colors.green,
          '${_stats['completadosHoy'] ?? 0} completados hoy',
        ),
        _buildMetricCard(
          'Completados',
          '${_calculateCompletedCount()}',
          Icons.check_circle,
          Colors.teal,
          'En este período',
        ),
        _buildMetricCard(
          'Pendientes',
          '${_stats['alertasHoy'] ?? 0}',
          Icons.schedule,
          Colors.orange,
          'Requieren atención',
        ),
      ],
    );
  }

  int _calculateCompletedCount() {
    // Aquí podrías calcular el total de recordatorios completados
    // basándote en las confirmaciones en el período
    return _stats['completadosHoy'] ?? 0;
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Flexible(
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChart() {
    return TrendChart(
      trendData: _trendData,
      title: 'Evolución de Adherencia (${DateFormat('dd/MM').format(_startDate)} - ${DateFormat('dd/MM').format(_endDate)})',
    );
  }

  Widget _buildTypeDistribution() {
    return TypeDistributionChart(
      distribution: _typeDistribution,
      title: 'Distribución por Tipos (${DateFormat('dd/MM').format(_startDate)} - ${DateFormat('dd/MM').format(_endDate)})',
    );
  }

  Widget _buildRemindersList() {
    final filteredReminders = _reminders.where((r) {
      if (!r.startDate.isAfter(_startDate.subtract(Duration(seconds: 1))) ||
          !r.startDate.isBefore(_endDate.add(Duration(days: 1)))) {
        return false;
      }
      
      if (_selectedType != null) {
        final matchesType = r.type.toLowerCase().contains(_selectedType!.toLowerCase()) ||
                           (_selectedType == 'Medicación' && r.type.toLowerCase().contains('medic')) ||
                           (_selectedType == 'Tarea' && r.type.toLowerCase().contains('tarea')) ||
                           (_selectedType == 'Cita' && r.type.toLowerCase().contains('cita'));
        if (!matchesType) return false;
      }
      
      return true;
    }).toList();

    if (filteredReminders.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text(
              'No hay recordatorios en este período',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    return Column(
      children: filteredReminders.map((reminder) {
        final nextOccurrence = reminder.getNextOccurrence();
        final isActive = nextOccurrence != null;
        
        return Card(
          margin: EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: ListTile(
            leading: Icon(
              reminder.type == 'medication' ? Icons.medication : Icons.directions_run,
              color: isActive ? Color(0xFF4A90E2) : Colors.grey,
              size: 32,
            ),
            title: Text(
              reminder.title,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text(reminder.dateRangeText),
                Text(
                  reminder.intervalDisplayText,
                  style: TextStyle(color: Color(0xFF4A90E2), fontSize: 12),
                ),
              ],
            ),
            trailing: Icon(
              isActive ? Icons.schedule : Icons.check_circle,
              color: isActive ? Colors.orange : Colors.grey,
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetalleRecordatorioNewScreen(
                    reminder: reminder,
                  ),
                ),
              );
              _loadReportData();
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAdherenciaTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mi Análisis de Adherencia',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          
          // Métricas de adherencia
          _buildAdherenceMetrics(),
          SizedBox(height: 20),
          
          // Evolución de adherencia
          _buildAdherenceEvolution(),
          SizedBox(height: 20),
          
          // Mensaje motivacional
          _buildMotivationalMessage(),
        ],
      ),
    );
  }

  Widget _buildAdherenceMetrics() {
    return Row(
      children: [
        Expanded(
          child: Card(
            elevation: 2,
            color: Colors.green[50],
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.trending_up, color: Colors.green, size: 32),
                  SizedBox(height: 8),
                  Text(
                    '${_stats['adherenciaGeneral'] ?? 0}%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text('Mi Adherencia'),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Card(
            elevation: 2,
            color: Colors.blue[50],
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.check_circle, color: Colors.blue, size: 32),
                  SizedBox(height: 8),
                  Text(
                    '${_stats['completadosHoy'] ?? 0}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  Text('Completados Hoy'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdherenceEvolution() {
    return TrendChart(
      trendData: _trendData,
      title: 'Evolución de Mi Adherencia',
      primaryColor: Colors.green,
    );
  }

  Widget _buildMotivationalMessage() {
    final adherence = _stats['adherenciaGeneral'] ?? 0;
    String message;
    Color color;
    IconData icon;

    if (adherence >= 80) {
      message = '¡Excelente trabajo! Tu adherencia es muy buena. ¡Sigue así!';
      color = Colors.green;
      icon = Icons.emoji_events;
    } else if (adherence >= 60) {
      message = '¡Buen trabajo! Estás en el camino correcto. Intenta mejorar un poco más.';
      color = Colors.orange;
      icon = Icons.thumb_up;
    } else {
      message = 'Puedes mejorar. Recuerda que seguir tus recordatorios es importante para tu salud.';
      color = Colors.red;
      icon = Icons.favorite;
    }

    return Card(
      elevation: 2,
      color: color.withOpacity(0.1),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 40),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportarTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Exportar Mis Reportes',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Período: ${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          SizedBox(height: 16),
          
          // Opciones de exportación
          _buildExportOption(
            'Reporte Completo PDF',
            'Incluye todas mis métricas, gráficos y análisis',
            Icons.picture_as_pdf,
            Colors.red,
            () => _exportCompletePDF(),
          ),
          
          _buildExportOption(
            'Datos Excel',
            'Tabla con todos mis recordatorios',
            Icons.table_chart,
            Colors.green,
            () => _exportToExcel(),
          ),
          
          _buildExportOption(
            'Resumen de Adherencia',
            'Métricas clave de mi adherencia',
            Icons.assessment,
            Color(0xFF1E3A5F),
            () => _exportAdherenceSummary(),
          ),
          
          SizedBox(height: 20),
          
          // Opciones avanzadas
          Card(
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Opciones de Exportación',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 16),
                  CheckboxListTile(
                    title: Text('Incluir gráficos'),
                    value: _includeGraphs,
                    onChanged: (value) {
                      setState(() {
                        _includeGraphs = value ?? true;
                      });
                    },
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: Text('Incluir datos detallados'),
                    value: _includeDetails,
                    onChanged: (value) {
                      setState(() {
                        _includeDetails = value ?? true;
                      });
                    },
                    dense: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportOption(String title, String description, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(description),
        trailing: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
          ),
          child: Text('Exportar'),
        ),
      ),
    );
  }

  // Métodos de acción
  void _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: _endDate,
      locale: const Locale('es', 'ES'),
    );
    if (date != null) {
      setState(() {
        _startDate = date;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
      _loadReportData();
    }
  }

  void _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
      locale: const Locale('es', 'ES'),
    );
    if (date != null) {
      setState(() {
        _endDate = date;
      });
      _loadReportData();
    }
  }

  void _setPeriod(int days) {
    setState(() {
      _endDate = DateTime.now();
      _startDate = _endDate.subtract(Duration(days: days));
    });
    _loadReportData();
  }

  Future<void> _exportCompletePDF() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF4A90E2)),
              SizedBox(height: 16),
              Text('Generando mi reporte en PDF...'),
            ],
          ),
        ),
      );

      if (_currentUser != null) {
        await ExportUtils.generateCuidadorPatientPDF(
          paciente: _currentUser!,
          patientReminders: _reminders,
          startDate: _startDate,
          endDate: _endDate,
        );
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reporte generado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generando reporte: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportToExcel() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF4A90E2)),
              SizedBox(height: 16),
              Text('Exportando mis datos a Excel...'),
            ],
          ),
        ),
      );

      if (_currentUser != null) {
        await ExportUtils.generateCuidadorExcel(
          pacientes: [_currentUser!],
          allReminders: _reminders,
          startDate: _startDate,
          endDate: _endDate,
          options: {
            'includeDetails': _includeDetails,
          },
        );
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Excel generado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exportando a Excel: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportAdherenceSummary() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF4A90E2)),
              SizedBox(height: 16),
              Text('Generando resumen de adherencia...'),
            ],
          ),
        ),
      );

      if (_currentUser != null) {
        await ExportUtils.generateCuidadorExecutiveSummary(
          pacientes: [_currentUser!],
          stats: _stats,
          startDate: _startDate,
          endDate: _endDate,
        );
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Resumen de adherencia generado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generando resumen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
