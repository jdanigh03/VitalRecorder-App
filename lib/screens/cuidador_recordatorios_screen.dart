import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/cuidador_service.dart';
import '../models/reminder_new.dart';
import '../models/user.dart';
import '../widgets/dashboard_widgets.dart';
import 'detalle_recordatorio_new.dart';
import 'cuidador_crear_recordatorio_new.dart';
import 'cuidador_pacientes_recordatorios.dart';
import 'cuidador_dashboard.dart';
import 'ajustes.dart';

class CuidadorRecordatoriosScreen extends StatefulWidget {
  @override
  _CuidadorRecordatoriosScreenState createState() => _CuidadorRecordatoriosScreenState();
}

class _CuidadorRecordatoriosScreenState extends State<CuidadorRecordatoriosScreen> with TickerProviderStateMixin {
  final CuidadorService _cuidadorService = CuidadorService();
  late TabController _tabController;
  
  bool _isLoading = true;
  List<ReminderNew> _allReminders = [];
  List<ReminderNew> _filteredReminders = [];
  String _searchQuery = '';
  String _selectedFilter = 'Todos';
  String _selectedStatus = 'Todos';

  final List<String> _filterOptions = ['Todos', 'Medicación', 'Tarea', 'Cita'];
  final List<String> _statusOptions = ['Todos', 'Pendientes', 'Completados', 'Vencidos', 'Pausados'];

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
    List<ReminderNew> filtered = List.from(_allReminders);
    
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
    
    // Filtrar por estado (simplificado - usar recordatorios activos)
    if (_selectedStatus != 'Todos') {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      switch (_selectedStatus) {
        case 'Pendientes':
          // Mostrar recordatorios activos no pausados con ocurrencias
          filtered = filtered.where((r) => 
            !r.isPaused && (r.hasOccurrencesOnDay(today) || r.startDate.isAfter(today))
          ).toList();
          break;
        case 'Pausados':
          // Mostrar solo recordatorios pausados
          filtered = filtered.where((r) => r.isPaused).toList();
          break;
        case 'Completados':
        case 'Vencidos':
          // Estos estados requieren consultar confirmaciones individualmente
          // Por simplicidad, mostrar todos para estos filtros
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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        automaticallyImplyLeading: false,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: CircleAvatar(
                backgroundColor: Colors.white24,
                radius: 18,
                child: Icon(Icons.schedule, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recordatorios',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${_filteredReminders.length} encontrados',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAllReminders,
            tooltip: 'Actualizar',
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onSelected: _showExportOptions,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download, color: Color(0xFF4A90E2)),
                    SizedBox(width: 8),
                    Text('Exportar'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingView() : _buildRecordatoriosContent(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showPatientSelectionForCreate();
        },
        backgroundColor: Color(0xFF4A90E2),
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          'Crear Recordatorio',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 4,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: 2,
          onTap: (i) {
            if (i == 0) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CuidadorDashboard()),
              );
              return;
            }
            if (i == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CuidadorPacientesRecordatoriosScreen()),
              );
              return;
            }
            if (i == 2) return; // Recordatorios
            if (i == 3) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AjustesScreen()),
              );
              return;
            }
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF4A90E2),
          unselectedItemColor: Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          backgroundColor: Colors.white,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Pacientes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'Recordatorios',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Ajustes',
            ),
          ],
        ),
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
    // Estadísticas simplificadas - requieren consultar confirmaciones
    final completed = 0; // TODO: implementar con confirmaciones
    final pending = _allReminders.where((r) => r.isActive).length;
    final overdue = 0; // TODO: implementar con confirmaciones

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
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            CircularProgressIndicator(
              color: Color(0xFF4A90E2),
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              'Cargando recordatorios de pacientes...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordatoriosContent() {
    // Estadísticas simplificadas - requieren consultar confirmaciones
    final pendingCount = _allReminders.where((r) => r.isActive).length;
    final completedCount = 0; // TODO: implementar con confirmaciones
    final now = DateTime.now();
    final overdueCount = 0; // TODO: implementar con confirmaciones
    
    return RefreshIndicator(
      onRefresh: _loadAllReminders,
      color: Color(0xFF4A90E2),
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con gradiente
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E3A5F),
                    Color(0xFF2D5082),
                    Color(0xFF4A90E2),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getFormattedDate(DateTime.now()),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _allReminders.isEmpty
                        ? 'Sin recordatorios de pacientes'
                        : '${_allReminders.length} ${_allReminders.length == 1 ? 'recordatorio' : 'recordatorios'} de pacientes',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: Colors.grey[600]),
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                  _applyFilters();
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatCard(
                        'Total',
                        '${_allReminders.length}',
                        Icons.calendar_today,
                        Colors.white24,
                      ),
                      SizedBox(width: 12),
                      _buildStatCard(
                        'Completados',
                        '$completedCount',
                        Icons.check_circle,
                        Colors.green.withOpacity(0.3),
                      ),
                      SizedBox(width: 12),
                      _buildStatCard(
                        'Vencidos',
                        '$overdueCount',
                        Icons.error,
                        Colors.red.withOpacity(0.3),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Contenido principal
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              color: Color(0xFF1E3A5F),
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Recordatorios de Pacientes',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A5F),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Botones de acción
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CuidadorPacientesRecordatoriosScreen(),
                                ),
                              ).then((_) => _loadAllReminders());
                            },
                            icon: Icon(Icons.folder_shared, size: 16),
                            label: Text('Por Pacientes'),
                            style: TextButton.styleFrom(
                              foregroundColor: Color(0xFF4A90E2),
                              backgroundColor: Color(0xFF4A90E2).withOpacity(0.1),
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          DropdownButton<String>(
                            value: _selectedStatus,
                            items: _statusOptions.map((status) {
                              return DropdownMenuItem(
                                value: status,
                                child: Text(status, style: TextStyle(fontSize: 12)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedStatus = value!;
                                _applyFilters();
                              });
                            },
                            underline: Container(),
                            style: TextStyle(color: Color(0xFF4A90E2)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Lista de recordatorios
                  if (_filteredReminders.isEmpty)
                    _buildEmptyState()
                  else
                    ..._filteredReminders.map((reminder) => _buildReminderCard(reminder)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.schedule_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _searchQuery.isNotEmpty ? 'Sin resultados' : 'Sin recordatorios',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty 
                  ? 'No se encontraron recordatorios que coincidan con la búsqueda'
                  : 'Los recordatorios de tus pacientes aparecerán aquí',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isNotEmpty || _selectedStatus != 'Todos') ...[  
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _selectedStatus = 'Todos';
                    _selectedFilter = 'Todos';
                    _applyFilters();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Limpiar filtros'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(ReminderNew reminder) {
    final now = DateTime.now();
    final isPast = reminder.endDate.isBefore(now);
    
    return GestureDetector(
      onTap: () {
        _showReminderDetails(reminder);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: reminder.isPaused
              ? Colors.grey.withOpacity(0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: reminder.isPaused
                ? Colors.grey.withOpacity(0.5)
                : isPast 
                    ? Colors.red.withOpacity(0.3) 
                    : Colors.transparent,
            width: reminder.isPaused || isPast ? 2 : 0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icono del tipo
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: reminder.type == 'medication'
                            ? [Colors.blue[400]!, Colors.blue[600]!]
                            : [Colors.green[400]!, Colors.green[600]!],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: (reminder.type == 'medication' 
                              ? Colors.blue 
                              : Colors.green).withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      reminder.type == 'medication' 
                          ? Icons.medication 
                          : Icons.directions_run,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Información del recordatorio
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
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          reminder.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time, 
                                  size: 14, 
                                  color: isPast ? Colors.red : Colors.grey[500],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  reminder.dateRangeText,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isPast ? Colors.red : Color(0xFF4A90E2),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.repeat, size: 14, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text(
                                  reminder.intervalDisplayText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Estado del recordatorio
                  const SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: reminder.isPaused
                          ? Colors.grey.withOpacity(0.1)
                          : isPast 
                              ? Colors.red.withOpacity(0.1)
                              : reminder.isActive
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      reminder.isPaused
                          ? Icons.pause_circle
                          : isPast 
                              ? Icons.error
                              : reminder.isActive
                                  ? Icons.schedule
                                  : Icons.check_circle,
                      color: reminder.isPaused
                          ? Colors.grey
                          : isPast 
                              ? Colors.red
                              : reminder.isActive
                                  ? Colors.orange
                                  : Colors.grey,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            
            // Indicador de estado
            if (reminder.isPaused)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pause, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Pausado',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (isPast)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Vencido',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getFormattedDate(DateTime date) {
    const months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    const days = [
      'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
    ];
    
    final dayName = days[date.weekday - 1];
    final day = date.day;
    final month = months[date.month - 1];
    final year = date.year;
    
    return '$dayName, $day de $month de $year';
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

  List<ReminderNew> _getTodayReminders() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return _filteredReminders.where((reminder) {
      return reminder.hasOccurrencesOnDay(today);
    }).toList();
  }

  List<ReminderNew> _getUpcomingReminders() {
    final now = DateTime.now();
    return _filteredReminders.where((reminder) {
      return reminder.startDate.isAfter(now);
    }).toList();
  }

  List<ReminderNew> _getOverdueReminders() {
    final now = DateTime.now();
    return _filteredReminders.where((reminder) {
      return reminder.endDate.isBefore(now);
    }).toList();
  }

  Widget _buildRemindersList(List<ReminderNew> reminders) {
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
          return _buildReminderCard(reminder);
        },
      ),
    );
  }

  void _showReminderDetails(ReminderNew reminder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetalleRecordatorioNewScreen(reminder: reminder),
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

  void _toggleReminderStatus(ReminderNew reminder) {
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

  void _editReminder(ReminderNew reminder) {
    // Esta función necesitaría el pacienteId que no está disponible aquí
    // Por ahora, mostrar mensaje de que no se puede editar desde esta pantalla
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Para editar un recordatorio, ve a "Por Pacientes" y selecciona el paciente específico'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 4),
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
    _showPatientSelectionForCreate();
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

  Future<void> _showPatientSelectionForCreate() async {
    try {
      final pacientes = await _cuidadorService.getPacientesAsignados();
      
      if (pacientes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No tienes pacientes asignados para crear recordatorios'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Seleccionar Paciente',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A5F),
            ),
          ),
          content: Container(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: pacientes.length,
              separatorBuilder: (context, index) => Divider(),
              itemBuilder: (context, index) {
                final paciente = pacientes[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(0xFF4A90E2),
                    child: Text(
                      paciente.persona.nombres.isNotEmpty
                          ? paciente.persona.nombres[0].toUpperCase()
                          : 'P',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    paciente.persona.nombres,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    paciente.email,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CuidadorCrearRecordatorioNewScreen(
                          pacienteId: paciente.userId!,
                          paciente: paciente,
                        ),
                      ),
                    ).then((result) {
                      if (result == true) {
                        _loadAllReminders();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('¡Recordatorio creado exitosamente!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error cargando pacientes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar la lista de pacientes'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
