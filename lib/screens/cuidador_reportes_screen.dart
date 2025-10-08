import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/cuidador_service.dart';
import '../models/reminder.dart';
import '../models/user.dart';
import '../widgets/dashboard_widgets.dart';

class CuidadorReportesScreen extends StatefulWidget {
  @override
  _CuidadorReportesScreenState createState() => _CuidadorReportesScreenState();
}

class _CuidadorReportesScreenState extends State<CuidadorReportesScreen> with TickerProviderStateMixin {
  final CuidadorService _cuidadorService = CuidadorService();
  late TabController _tabController;
  
  bool _isLoading = false;
  Map<String, dynamic> _stats = {};
  List<UserModel> _pacientes = [];
  List<Reminder> _reminders = [];

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
      final results = await Future.wait([
        _cuidadorService.getCuidadorStats(),
        _cuidadorService.getPacientes(),
        _cuidadorService.getAllRemindersFromPatients(),
      ]);

      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _pacientes = results[1] as List<UserModel>;
        _reminders = results[2] as List<Reminder>;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando datos de reportes: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando datos'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.purple,
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
            Tab(text: 'Por Paciente', icon: Icon(Icons.person, size: 16)),
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
          CircularProgressIndicator(color: Colors.purple),
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
                        children: [
                          Icon(Icons.calendar_today, color: Colors.purple),
                          SizedBox(width: 8),
                          Text(DateFormat('dd/MM/yyyy').format(_startDate)),
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
                        children: [
                          Icon(Icons.calendar_today, color: Colors.purple),
                          SizedBox(width: 8),
                          Text(DateFormat('dd/MM/yyyy').format(_endDate)),
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
          foregroundColor: Colors.purple,
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
          'Total Pacientes',
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
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChart() {
    return Card(
      elevation: 2,
      child: Container(
        height: 200,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Evolución de Recordatorios Completados',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.trending_up, size: 48, color: Colors.purple),
                      SizedBox(height: 8),
                      Text(
                        'Gráfico de Tendencias',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      Text(
                        'Mostrando evolución en el tiempo',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeDistribution() {
    final medicacion = _stats['recordatoriosPorTipo']?['medicacion'] ?? 0;
    final tareas = _stats['recordatoriosPorTipo']?['tareas'] ?? 0;
    final citas = _stats['recordatoriosPorTipo']?['citas'] ?? 0;
    final total = medicacion + tareas + citas;

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Distribución por Tipos de Recordatorio',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTypeBar('Medicación', medicacion, total, Colors.red),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildTypeBar('Tareas', tareas, total, Colors.blue),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildTypeBar('Citas', citas, total, Colors.green),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBar(String label, int value, int total, Color color) {
    final percentage = total > 0 ? (value / total * 100).round() : 0;
    return Column(
      children: [
        Container(
          height: 80,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                ),
              ),
              SizedBox(height: 8),
            ],
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
          
          // Ranking de pacientes
          _buildPatientRanking(),
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
    return Card(
      elevation: 2,
      child: Container(
        height: 150,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Evolución de Adherencia (30 días)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.show_chart, size: 32, color: Colors.green),
                      Text(
                        'Gráfico de Evolución',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientRanking() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ranking de Pacientes por Adherencia',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _pacientes.take(5).length,
              itemBuilder: (context, index) {
                final paciente = _pacientes[index];
                final adherence = 85 - (index * 10); // Simulado
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getAdherenceColor(adherence).withOpacity(0.2),
                    child: Text('${index + 1}'),
                  ),
                  title: Text(paciente.nombreCompleto.isEmpty ? 'Paciente ${index + 1}' : paciente.nombreCompleto),
                  subtitle: Text(paciente.email),
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
            'Análisis Individual por Paciente',
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
    final adherence = 90 - (index * 5); // Simulado
    final totalReminders = 20 + index * 3; // Simulado
    final completedReminders = (totalReminders * adherence / 100).round();

    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal.withOpacity(0.1),
          child: Text(
            paciente.nombreCompleto.isNotEmpty ? paciente.nombreCompleto.substring(0, 1).toUpperCase() : 'P',
            style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          paciente.nombreCompleto.isEmpty ? 'Paciente ${index + 1}' : paciente.nombreCompleto,
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
                      child: _buildPatientStat('Pendientes', '${totalReminders - completedReminders}', Colors.orange),
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
                          backgroundColor: Colors.teal,
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
          SizedBox(height: 16),
          
          // Opciones de exportación
          _buildExportOption(
            'Reporte Completo PDF',
            'Incluye todas las métricas, gráficos y análisis',
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
            Colors.purple,
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
                          value: true,
                          onChanged: (value) {},
                          dense: true,
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          title: Text('Datos detallados'),
                          value: true,
                          onChanged: (value) {},
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                  
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          title: Text('Incluir comentarios'),
                          value: false,
                          onChanged: (value) {},
                          dense: true,
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          title: Text('Enviar por email'),
                          value: false,
                          onChanged: (value) {},
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
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _startDate = date;
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

  void _showPatientDetails(UserModel paciente) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('Detalles de ${paciente.nombreCompleto}'),
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: Text('Análisis detallado del paciente'),
          ),
        ),
      ),
    );
  }

  void _exportPatientReport(UserModel paciente) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generando reporte de ${paciente.nombreCompleto}...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _exportCompletePDF() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generando reporte completo en PDF...'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _exportToExcel() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exportando datos a Excel...'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _exportPatientReports() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generando reportes por paciente...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _exportExecutiveSummary() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generando resumen ejecutivo...'),
        backgroundColor: Colors.purple,
      ),
    );
  }
}
