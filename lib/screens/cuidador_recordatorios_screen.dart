import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/cuidador_service.dart';
import '../models/reminder.dart';
import '../models/user.dart';
import '../widgets/dashboard_widgets.dart';

class CuidadorRecordatoriosScreen extends StatefulWidget {
  @override
  _CuidadorRecordatoriosScreenState createState() => _CuidadorRecordatoriosScreenState();
}

class _CuidadorRecordatoriosScreenState extends State<CuidadorRecordatoriosScreen> with TickerProviderStateMixin {
  final CuidadorService _cuidadorService = CuidadorService();
  late TabController _tabController;
  
  bool _isLoading = true;
  List<Reminder> _allReminders = [];
  List<Reminder> _filteredReminders = [];
  String _searchQuery = '';
  String _selectedFilter = 'Todos';
  String _selectedStatus = 'Todos';

  final List<String> _filterOptions = ['Todos', 'Medicación', 'Tarea', 'Cita'];
  final List<String> _statusOptions = ['Todos', 'Pendientes', 'Completados', 'Vencidos'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllReminders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllReminders() async {
    setState(() => _isLoading = true);
    try {
      final reminders = await _cuidadorService.getAllRemindersFromPatients();
      setState(() {
        _allReminders = reminders;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando recordatorios: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando recordatorios'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _applyFilters() {
    List<Reminder> filtered = List.from(_allReminders);
    
    // Filtrar por búsqueda
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((reminder) {
        return reminder.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               reminder.description.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    // Filtrar por tipo
    if (_selectedFilter != 'Todos') {
      filtered = filtered.where((reminder) => reminder.type == _selectedFilter).toList();
    }
    
    // Filtrar por estado
    if (_selectedStatus != 'Todos') {
      final now = DateTime.now();
      switch (_selectedStatus) {
        case 'Pendientes':
          filtered = filtered.where((r) => !r.isCompleted && r.dateTime.isAfter(now)).toList();
          break;
        case 'Completados':
          filtered = filtered.where((r) => r.isCompleted).toList();
          break;
        case 'Vencidos':
          filtered = filtered.where((r) => !r.isCompleted && r.dateTime.isBefore(now)).toList();
          break;
      }
    }
    
    setState(() {
      _filteredReminders = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        title: Text(
          'Todos los Recordatorios',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Todos'),
            Tab(text: 'Hoy'),
            Tab(text: 'Próximos'),
            Tab(text: 'Vencidos'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAllReminders,
            tooltip: 'Actualizar',
          ),
          PopupMenuButton<String>(
            onSelected: _showExportOptions,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('Exportar'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda y filtros
          _buildSearchAndFilters(),
          
          // Estadísticas rápidas
          _buildQuickStats(),
          
          // Lista de recordatorios por tabs
          Expanded(
            child: _isLoading ? _buildLoadingView() : _buildTabContent(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showReminderActions,
        backgroundColor: Colors.teal,
        child: Icon(Icons.add),
        tooltip: 'Acciones de recordatorios',
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // Barra de búsqueda
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _applyFilters();
              });
            },
            decoration: InputDecoration(
              hintText: 'Buscar recordatorios...',
              prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.teal),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          SizedBox(height: 12),
          
          // Filtros
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedFilter,
                  decoration: InputDecoration(
                    labelText: 'Tipo',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _filterOptions.map((filter) {
                    return DropdownMenuItem(
                      value: filter,
                      child: Text(filter),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedFilter = value!;
                      _applyFilters();
                    });
                  },
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: InputDecoration(
                    labelText: 'Estado',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _statusOptions.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(status),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value!;
                      _applyFilters();
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final total = _allReminders.length;
    final completed = _allReminders.where((r) => r.isCompleted).length;
    final pending = _allReminders.where((r) => !r.isCompleted).length;
    final overdue = _allReminders.where((r) => !r.isCompleted && r.dateTime.isBefore(DateTime.now())).length;

    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: _buildStatChip('Total', '$total', Colors.blue)),
          SizedBox(width: 8),
          Expanded(child: _buildStatChip('Completados', '$completed', Colors.green)),
          SizedBox(width: 8),
          Expanded(child: _buildStatChip('Pendientes', '$pending', Colors.orange)),
          SizedBox(width: 8),
          Expanded(child: _buildStatChip('Vencidos', '$overdue', Colors.red)),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.teal),
          SizedBox(height: 16),
          Text(
            'Cargando recordatorios...',
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
        _buildRemindersList(_filteredReminders),
        _buildRemindersList(_getTodayReminders()),
        _buildRemindersList(_getUpcomingReminders()),
        _buildRemindersList(_getOverdueReminders()),
      ],
    );
  }

  List<Reminder> _getTodayReminders() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    return _filteredReminders.where((reminder) {
      final reminderDate = reminder.dateTime;
      return reminderDate.isAfter(startOfDay) && reminderDate.isBefore(endOfDay);
    }).toList();
  }

  List<Reminder> _getUpcomingReminders() {
    final now = DateTime.now();
    return _filteredReminders.where((reminder) {
      return !reminder.isCompleted && reminder.dateTime.isAfter(now);
    }).toList();
  }

  List<Reminder> _getOverdueReminders() {
    final now = DateTime.now();
    return _filteredReminders.where((reminder) {
      return !reminder.isCompleted && reminder.dateTime.isBefore(now);
    }).toList();
  }

  Widget _buildRemindersList(List<Reminder> reminders) {
    if (reminders.isEmpty) {
      return Center(
        child: EmptyStateCard(
          title: 'Sin recordatorios',
          message: 'No hay recordatorios que coincidan con los filtros seleccionados',
          icon: Icons.schedule_outlined,
          actionText: 'Limpiar filtros',
          onAction: () {
            setState(() {
              _selectedFilter = 'Todos';
              _selectedStatus = 'Todos';
              _searchQuery = '';
              _applyFilters();
            });
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllReminders,
      color: Colors.teal,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: reminders.length,
        itemBuilder: (context, index) {
          final reminder = reminders[index];
          return Card(
            elevation: 2,
            margin: EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ReminderListTile(
              title: reminder.title,
              subtitle: reminder.description,
              dateTime: reminder.dateTime,
              isCompleted: reminder.isCompleted,
              type: reminder.type,
              onTap: () => _showReminderDetails(reminder),
            ),
          );
        },
      ),
    );
  }

  void _showReminderDetails(Reminder reminder) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: EdgeInsets.all(20),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                
                // Título
                Text(
                  reminder.title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                
                // Estado
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: reminder.isCompleted ? Colors.green.withOpacity(0.1) : 
                           reminder.dateTime.isBefore(DateTime.now()) ?
                           Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    reminder.isCompleted ? 'Completado' :
                    reminder.dateTime.isBefore(DateTime.now()) ? 'Vencido' : 'Pendiente',
                    style: TextStyle(
                      color: reminder.isCompleted ? Colors.green : 
                             reminder.dateTime.isBefore(DateTime.now()) ?
                             Colors.red : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                
                // Detalles
                _buildDetailRow('Descripción', reminder.description),
                _buildDetailRow('Tipo', reminder.type),
                _buildDetailRow('Fecha', DateFormat('dd/MM/yyyy HH:mm').format(reminder.dateTime)),
                _buildDetailRow('Frecuencia', reminder.frequency),
                
                SizedBox(height: 30),
                
                // Acciones
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _toggleReminderStatus(reminder),
                        icon: Icon(reminder.isCompleted ? Icons.undo : Icons.check),
                        label: Text(reminder.isCompleted ? 'Marcar Pendiente' : 'Marcar Completado'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: reminder.isCompleted ? Colors.orange : Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _editReminder(reminder),
                        icon: Icon(Icons.edit),
                        label: Text('Editar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleReminderStatus(Reminder reminder) {
    // Aquí implementarías la lógica para cambiar el estado del recordatorio
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Estado del recordatorio actualizado'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
    _loadAllReminders();
  }

  void _editReminder(Reminder reminder) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Función de edición en desarrollo'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showReminderActions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.add_alert, color: Colors.teal),
              title: Text('Crear Recordatorio'),
              subtitle: Text('Agregar un nuevo recordatorio para pacientes'),
              onTap: () {
                Navigator.pop(context);
                _createReminder();
              },
            ),
            ListTile(
              leading: Icon(Icons.batch_prediction, color: Colors.blue),
              title: Text('Operaciones en Lote'),
              subtitle: Text('Marcar múltiples recordatorios'),
              onTap: () {
                Navigator.pop(context);
                _showBatchOperations();
              },
            ),
            ListTile(
              leading: Icon(Icons.notifications, color: Colors.orange),
              title: Text('Enviar Notificaciones'),
              subtitle: Text('Notificar a pacientes sobre recordatorios'),
              onTap: () {
                Navigator.pop(context);
                _sendNotifications();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showExportOptions(String option) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Exportar Recordatorios'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.picture_as_pdf, color: Colors.red),
              title: Text('Exportar a PDF'),
              onTap: () {
                Navigator.pop(context);
                _exportToPDF();
              },
            ),
            ListTile(
              leading: Icon(Icons.table_chart, color: Colors.green),
              title: Text('Exportar a Excel'),
              onTap: () {
                Navigator.pop(context);
                _exportToExcel();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _createReminder() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Redirigiendo a crear recordatorio...'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  void _showBatchOperations() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Operaciones en lote disponibles próximamente'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _sendNotifications() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Enviando notificaciones a pacientes...'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _exportToPDF() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generando reporte PDF...'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _exportToExcel() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generando archivo Excel...'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
