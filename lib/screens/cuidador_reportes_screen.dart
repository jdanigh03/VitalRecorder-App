import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/cuidador_service.dart';
import '../services/analytics_service.dart';
import '../services/reports_cache.dart';
import '../models/reminder_new.dart';
import '../models/user.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/chart_widgets.dart';
import '../utils/export_utils.dart';
import 'cuidador_recordatorios_paciente_detalle.dart';

class CuidadorReportesScreen extends StatefulWidget {
  @override
  _CuidadorReportesScreenState createState() => _CuidadorReportesScreenState();
}

class _CuidadorReportesScreenState extends State<CuidadorReportesScreen> with TickerProviderStateMixin {
  final CuidadorService _cuidadorService = CuidadorService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final ReportsCache _cache = ReportsCache();
  late TabController _tabController;
  
  bool _isLoading = false;
  Map<String, dynamic> _stats = {};
  List<UserModel> _pacientes = [];
  List<ReminderNew> _reminders = [];
  List<Map<String, dynamic>> _trendData = [];
  List<Map<String, dynamic>> _patientStats = [];
  Map<String, dynamic> _typeDistribution = {};
  
  // Filtros avanzados
  String? _selectedPatientId;
  String? _selectedType;
  bool _includeGraphs = true;
  bool _includeDetails = true;

  DateTime _startDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
      // Intentar usar cache primero
      var pacientes = _cache.getCachedPatients();
      var reminders = _cache.getCachedReminders();
      
      // Si no hay cache, cargar desde servidor
      if (pacientes == null || reminders == null) {
        final results = await Future.wait([
          _cuidadorService.getPacientes(),
          _cuidadorService.getAllRemindersFromPatients(),
        ]);
        pacientes = results[0] as List<UserModel>;
        reminders = results[1] as List<ReminderNew>;
        
        // Actualizar cache
        _cache.updateCache(pacientes, reminders);
      } else {
        print('Usando datos del cache para reportes');
      }

      // Cargar datos de análisis usando el nuevo servicio
      final analysisResults = await Future.wait([
        _analyticsService.calculateRealStats(
          startDate: _startDate,
          endDate: _endDate,
          allReminders: reminders,
          allPatients: pacientes,
          patientId: _selectedPatientId,
        ),
        _analyticsService.getTrendData(
          startDate: _startDate,
          endDate: _endDate,
          allReminders: reminders,
          patientId: _selectedPatientId,
        ),
        _analyticsService.getPatientStats(
          startDate: _startDate,
          endDate: _endDate,
          allReminders: reminders,
          allPatients: pacientes,
        ),
      ]);

      final stats = analysisResults[0] as Map<String, dynamic>;
      final trendData = analysisResults[1] as List<Map<String, dynamic>>;
      final patientStats = analysisResults[2] as List<Map<String, dynamic>>;
      
      // Filtrar recordatorios por período y filtros avanzados
      final filteredReminders = reminders.where((r) {
        // Filtro por período (usar startDate del recordatorio)
        if (!r.startDate.isAfter(_startDate.subtract(Duration(seconds: 1))) ||
            !r.startDate.isBefore(_endDate.add(Duration(days: 1)))) {
          return false;
        }
        
        // Filtro por paciente
        if (_selectedPatientId != null && r.userId != _selectedPatientId) {
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
      
      final periodReminders = filteredReminders;
      
      final typeDistribution = _analyticsService.getTypeDistribution(periodReminders);

      setState(() {
        _stats = stats;
        _pacientes = pacientes ?? [];
        _reminders = reminders ?? [];
        _trendData = trendData;
        _patientStats = patientStats;
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
          'Reportes y Análisis',
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
            Tab(text: 'Por Usuario', icon: Icon(Icons.person, size: 16)),
            Tab(text: 'Exportar', icon: Icon(Icons.file_download, size: 16)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.cached),
            onPressed: () {
              _cache.clearCache();
              _loadReportData();
            },
            tooltip: 'Limpiar cache y actualizar',
          ),
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
        _buildPorPacienteTab(),
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
          
          // Filtros avanzados
          _buildAdvancedFilters(),
          SizedBox(height: 20),
          
          // Métricas principales
          Text(
            'Métricas Principales',
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
          'Total Usuarios',
          '${_stats['totalPacientes'] ?? 0}',
          Icons.people,
          Colors.blue,
          '+${(_stats['totalPacientes'] ?? 0)} este período',
        ),
        _buildMetricCard(
          'Recordatorios Activos',
          '${_stats['recordatoriosActivos'] ?? 0}',
          Icons.schedule,
          Colors.orange,
          '${_stats['totalRecordatorios'] ?? 0} total',
        ),
        _buildMetricCard(
          'Adherencia Promedio',
          '${_stats['adherenciaGeneral'] ?? 0}%',
          Icons.trending_up,
          Colors.green,
          '${_stats['completadosHoy'] ?? 0} completados hoy',
        ),
        _buildMetricCard(
          'Alertas Críticas',
          '${_stats['alertasHoy'] ?? 0}',
          Icons.warning,
          Colors.red,
          'Requieren atención',
        ),
      ],
    );
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


  Widget _buildAdherenciaTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Análisis de Adherencia',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          
          // Métricas de adherencia
          _buildAdherenceMetrics(),
          SizedBox(height: 20),
          
          // Evolución de adherencia
          _buildAdherenceEvolution(),
          SizedBox(height: 20),
          
          // Ranking de usuarios
          _buildPatientRanking(),
          SizedBox(height: 20),
          
          // Gráfico de barras de adherencia
          AdherenceBarChart(patientStats: _patientStats),
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
                  Text('Adherencia General'),
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
      title: 'Evolución de Adherencia',
      primaryColor: Colors.green,
    );
  }

  Widget _buildPatientRanking() {
    // Usar los datos ya calculados del servicio de analytics
    final pacientesConAdherencia = _patientStats.map((stat) => {
      'paciente': stat['patient'],
      'adherencia': stat['adherencia'],
      'recordatorios': stat['totalRecordatorios'],
    }).toList();
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ranking de Usuarios por Adherencia',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: pacientesConAdherencia.take(5).length,
              itemBuilder: (context, index) {
                final item = pacientesConAdherencia[index];
                final paciente = item['paciente'] as UserModel;
                final adherencia = item['adherencia'] as int;
                final totalRecordatorios = item['recordatorios'] as int;
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getAdherenceColor(adherencia).withOpacity(0.2),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(paciente.nombreCompleto.isEmpty ? 'Usuario ${index + 1}' : paciente.nombreCompleto),
                  subtitle: Text('${paciente.email} • $totalRecordatorios recordatorios'),
                  trailing: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getAdherenceColor(adherencia).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$adherencia%',
                      style: TextStyle(
                        color: _getAdherenceColor(adherencia),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPorPacienteTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Análisis Individual por Usuario',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _pacientes.length,
            itemBuilder: (context, index) {
              final paciente = _pacientes[index];
              return _buildPatientAnalysisCard(paciente, index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPatientAnalysisCard(UserModel paciente, int index) {
    // Buscar las estadísticas del paciente en los datos ya calculados
    final patientStat = _patientStats.firstWhere(
      (stat) => stat['patient'].userId == paciente.userId,
      orElse: () => {
        'totalRecordatorios': 0,
        'completados': 0,
        'vencidos': 0,
        'pendientes': 0,
        'adherencia': 0,
      },
    );
    
    final totalReminders = patientStat['totalRecordatorios'] as int;
    final completedReminders = patientStat['completados'] as int;
    final overdueReminders = patientStat['vencidos'] as int;
    final pendingReminders = patientStat['pendientes'] as int;
    final adherence = patientStat['adherencia'] as int;

    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Color(0xFF4A90E2).withOpacity(0.1),
          child: Text(
            paciente.nombreCompleto.isNotEmpty ? paciente.nombreCompleto.substring(0, 1).toUpperCase() : 'P',
            style: TextStyle(color: Color(0xFF4A90E2), fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          paciente.nombreCompleto.isEmpty ? 'Usuario ${index + 1}' : paciente.nombreCompleto,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            Icon(Icons.email, size: 14, color: Colors.grey),
            SizedBox(width: 4),
            Text(paciente.email),
          ],
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getAdherenceColor(adherence).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$adherence%',
            style: TextStyle(
              color: _getAdherenceColor(adherence),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildPatientStat('Total', '$totalReminders', Colors.blue),
                    ),
                    Expanded(
                      child: _buildPatientStat('Completados', '$completedReminders', Colors.green),
                    ),
                    Expanded(
                      child: _buildPatientStat('Pendientes', '$pendingReminders', Colors.orange),
                    ),
                    Expanded(
                      child: _buildPatientStat('Vencidos', '$overdueReminders', Colors.red),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showPatientDetails(paciente),
                        icon: Icon(Icons.visibility, size: 16),
                        label: Text('Ver Detalles'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF4A90E2),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _exportPatientReport(paciente),
                        icon: Icon(Icons.download, size: 16),
                        label: Text('Exportar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientStat(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
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
            'Opciones de Exportación',
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
            'Incluye todas las métricas, gráficos y análisis del período seleccionado',
            Icons.picture_as_pdf,
            Colors.red,
            () => _exportCompletePDF(),
          ),
          
          _buildExportOption(
            'Datos Excel',
            'Tabla con todos los recordatorios y estadísticas',
            Icons.table_chart,
            Colors.green,
            () => _exportToExcel(),
          ),
          
          _buildExportOption(
            'Reporte por Paciente',
            'Análisis individual de cada paciente',
            Icons.person,
            Colors.blue,
            () => _exportPatientReports(),
          ),
          
          _buildExportOption(
            'Resumen Ejecutivo',
            'Métricas clave y tendencias principales',
            Icons.business,
            Color(0xFF1E3A5F),
            () => _exportExecutiveSummary(),
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
                    'Opciones Avanzadas',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          title: Text('Incluir gráficos'),
                          value: _includeGraphs,
                          onChanged: (value) {
                            setState(() {
                              _includeGraphs = value ?? true;
                            });
                          },
                          dense: true,
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          title: Text('Datos detallados'),
                          value: _includeDetails,
                          onChanged: (value) {
                            setState(() {
                              _includeDetails = value ?? true;
                            });
                          },
                          dense: true,
                        ),
                      ),
                    ],
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

  /// Aplica filtros avanzados a la lista de recordatorios
  List<ReminderNew> _applyAdvancedFilters(List<ReminderNew> reminders) {
    return reminders.where((r) {
      // Filtro por período - verificar si el rango del recordatorio intersecta con el período
      if (r.endDate.isBefore(_startDate) || r.startDate.isAfter(_endDate.add(Duration(days: 1)))) {
        return false;
      }
      
      // Filtro por paciente
      if (_selectedPatientId != null && r.userId != _selectedPatientId) {
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
  }

  Color _getAdherenceColor(int adherence) {
    if (adherence >= 80) return Colors.green;
    if (adherence >= 60) return Colors.orange;
    return Colors.red;
  }

  // Métodos de acción
  void _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: _endDate,
      locale: const Locale('es', 'ES'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF4A90E2),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _startDate = date;
        // Asegurarse de que la fecha final no sea anterior a la inicial
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF4A90E2),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
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

  Widget _buildAdvancedFilters() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtros Avanzados',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 12),
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Paciente:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          SizedBox(height: 4),
                          DropdownButtonFormField<String?>(
                            value: _selectedPatientId,
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              hintText: 'Todos',
                              hintStyle: TextStyle(fontSize: 12),
                            ),
                            isExpanded: true,
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Todos los pacientes', style: TextStyle(fontSize: 12)),
                              ),
                              ..._pacientes.map((patient) => DropdownMenuItem<String?>(
                                value: patient.userId,
                                child: Text(
                                  patient.nombreCompleto.isEmpty 
                                      ? 'Paciente ${_pacientes.indexOf(patient) + 1}' 
                                      : patient.nombreCompleto,
                                  style: TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedPatientId = value;
                              });
                              _loadReportData();
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tipo:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          SizedBox(height: 4),
                          DropdownButtonFormField<String?>(
                            value: _selectedType,
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              hintText: 'Todos',
                              hintStyle: TextStyle(fontSize: 12),
                            ),
                            isExpanded: true,
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Todos', style: TextStyle(fontSize: 12)),
                              ),
                              DropdownMenuItem<String?>(
                                value: 'Medicación',
                                child: Text('Medicación', style: TextStyle(fontSize: 12)),
                              ),
                              DropdownMenuItem<String?>(
                                value: 'Tarea',
                                child: Text('Tareas', style: TextStyle(fontSize: 12)),
                              ),
                              DropdownMenuItem<String?>(
                                value: 'Cita',
                                child: Text('Citas', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedType = value;
                              });
                              _loadReportData();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedPatientId = null;
                            _selectedType = null;
                          });
                          _loadReportData();
                        },
                        icon: Icon(Icons.clear, size: 16),
                        label: Text('Limpiar Filtros', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          foregroundColor: Colors.grey[700],
                          elevation: 0,
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPatientDetails(UserModel paciente) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CuidadorRecordatoriosPacienteDetalleScreen(
          paciente: paciente,
        ),
      ),
    ).then((_) {
      // Actualizar datos al regresar
      _loadReportData();
    });
  }

  Future<void> _exportPatientReport(UserModel paciente) async {
    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF4A90E2)),
              SizedBox(height: 16),
              Text('Generando reporte de ${paciente.nombreCompleto.isNotEmpty ? paciente.nombreCompleto : 'paciente'}...'),
            ],
          ),
        ),
      );

      // Filtrar recordatorios del paciente en el período
      final patientReminders = _reminders.where((r) => 
        r.userId == paciente.id &&
        !(r.endDate.isBefore(_startDate) || r.startDate.isAfter(_endDate.add(Duration(days: 1))))
      ).toList();

      // Buscar stats del paciente
      final patientStat = _patientStats.firstWhere(
        (s) => (s['patient'] as UserModel).userId == paciente.userId,
        orElse: () => <String, dynamic>{},
      );

      await ExportUtils.generateCuidadorPatientPDF(
        paciente: paciente,
        patientReminders: patientReminders,
        startDate: _startDate,
        endDate: _endDate,
        stats: patientStat,
      );

      Navigator.pop(context); // Cerrar diálogo de carga

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reporte de ${paciente.nombreCompleto.isNotEmpty ? paciente.nombreCompleto : 'paciente'} generado y compartido exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Cerrar diálogo de carga
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generando reporte: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportCompletePDF() async {
    try {
      // Mostrar indicador de carga con opciones
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF4A90E2)),
              SizedBox(height: 16),
              Text('Generando reporte completo en PDF...'),
              if (_includeGraphs) 
                Text('Incluyendo gráficos...', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              if (_includeDetails)
                Text('Incluyendo datos detallados...', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
      );

      // Filtrar datos según opciones seleccionadas
      final filteredReminders = _applyAdvancedFilters(_reminders);
      final filteredPatients = _selectedPatientId != null 
          ? _pacientes.where((p) => p.userId == _selectedPatientId).toList()
          : _pacientes;

      await ExportUtils.generateCuidadorCompletePDF(
        pacientes: filteredPatients,
        allReminders: filteredReminders,
        startDate: _startDate,
        endDate: _endDate,
        stats: _stats,
        options: {
          'includeGraphs': _includeGraphs,
          'includeDetails': _includeDetails,
          'selectedPatient': _selectedPatientId,
          'selectedType': _selectedType,
        },
      );

      Navigator.pop(context); // Cerrar diálogo de carga

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Reporte completo generado exitosamente'),
                    if (_includeGraphs || _includeDetails)
                      Text(
                        'Opciones: ${_includeGraphs ? "Gráficos " : ""}${_includeDetails ? "Detalles" : ""}',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Cerrar diálogo de carga
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generando reporte completo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportToExcel() async {
    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF4A90E2)),
              SizedBox(height: 16),
              Text('Exportando datos a Excel...'),
              if (_includeDetails)
                Text('Incluyendo datos detallados...', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
      );

      // Aplicar filtros
      final filteredReminders = _applyAdvancedFilters(_reminders);
      final filteredPatients = _selectedPatientId != null 
          ? _pacientes.where((p) => p.userId == _selectedPatientId).toList()
          : _pacientes;

      await ExportUtils.generateCuidadorExcel(
        pacientes: filteredPatients,
        allReminders: filteredReminders,
        startDate: _startDate,
        endDate: _endDate,
        patientStats: _patientStats,
        options: {
          'includeDetails': _includeDetails,
          'selectedPatient': _selectedPatientId,
          'selectedType': _selectedType,
        },
      );

      Navigator.pop(context); // Cerrar diálogo de carga

      final exportedCount = filteredReminders.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.table_chart, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Excel generado exitosamente'),
                    Text(
                      '$exportedCount recordatorios exportados',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Cerrar diálogo de carga
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exportando a Excel: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportPatientReports() async {
    if (_pacientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay pacientes para generar reportes'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Mostrar diálogo de selección
    final selectedPatients = await showDialog<List<UserModel>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Seleccionar Pacientes'),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Selecciona los pacientes para generar sus reportes:'),
              SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _pacientes.length,
                  itemBuilder: (context, index) {
                    final paciente = _pacientes[index];
                    return CheckboxListTile(
                      title: Text(paciente.nombreCompleto.isNotEmpty ? paciente.nombreCompleto : 'Paciente ${index + 1}'),
                      subtitle: Text(paciente.email),
                      value: true, // Por defecto seleccionados
                      onChanged: null, // Simplificado - todos seleccionados
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _pacientes),
            child: Text('Generar'),
          ),
        ],
      ),
    );

    if (selectedPatients == null) return;

    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF4A90E2)),
              SizedBox(height: 16),
              Text('Generando reportes de ${selectedPatients.length} pacientes...'),
            ],
          ),
        ),
      );

      // Generar un reporte por cada paciente seleccionado
      for (final paciente in selectedPatients) {
        final patientReminders = _reminders.where((r) => r.userId == paciente.id).toList();
        
        // Buscar stats del paciente
        final patientStat = _patientStats.firstWhere(
          (s) => (s['patient'] as UserModel).userId == paciente.userId,
          orElse: () => <String, dynamic>{},
        );

        if (patientReminders.isNotEmpty) {
          await ExportUtils.generateCuidadorPatientPDF(
            paciente: paciente,
            patientReminders: patientReminders,
            startDate: _startDate,
            endDate: _endDate,
            stats: patientStat,
          );
        }
      }

      Navigator.pop(context); // Cerrar diálogo de carga

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selectedPatients.length} reportes generados exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Cerrar diálogo de carga
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generando reportes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportExecutiveSummary() async {
    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF4A90E2)),
              SizedBox(height: 16),
              Text('Generando resumen ejecutivo...'),
            ],
          ),
        ),
      );

      await ExportUtils.generateCuidadorExecutiveSummary(
        pacientes: _pacientes,
        stats: _stats,
        startDate: _startDate,
        endDate: _endDate,
      );

      Navigator.pop(context); // Cerrar diálogo de carga

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Resumen ejecutivo generado y compartido exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Cerrar diálogo de carga
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generando resumen ejecutivo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
