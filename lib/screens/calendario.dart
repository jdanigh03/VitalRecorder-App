import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/reminder_new.dart';
import '../reminder_service_new.dart';
import '../utils/export_utils.dart';
import 'detalle_recordatorio_new.dart';
import 'agregar_recordatorio.dart';

class CalendarioScreen extends StatefulWidget {
  const CalendarioScreen({Key? key}) : super(key: key);

  @override
  State<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends State<CalendarioScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ReminderServiceNew _reminderService = ReminderServiceNew();
  
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  
  List<ReminderNew> _allReminders = [];
  List<ReminderNew> _filteredReminders = [];
  String? _selectedMedicament;
  bool _isLoading = true;

  // Formatters
  final DateFormat _dayFormatter = DateFormat('d');
  final DateFormat _monthFormatter = DateFormat('MMM');
  final DateFormat _timeFormatter = DateFormat('HH:mm');
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadReminders();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recargar datos cuando la pantalla se hace visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadReminders();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReminders() async {
    try {
      setState(() => _isLoading = true);
      final reminders = await _reminderService.getAllReminders();
      setState(() {
        _allReminders = reminders;
        _filteredReminders = reminders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando recordatorios: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterReminders(String? medicament) {
    setState(() {
      _selectedMedicament = medicament;
      if (medicament == null || medicament.isEmpty) {
        _filteredReminders = _allReminders;
      } else {
        _filteredReminders = _allReminders
            .where((reminder) => reminder.title.toLowerCase().contains(medicament.toLowerCase()))
            .toList();
      }
    });
  }

  List<ReminderNew> _getRemindersForDay(DateTime day) {
    // Usar el nuevo método para verificar ocurrencias
    return _filteredReminders.where((reminder) {
      return reminder.hasOccurrencesOnDay(day);
    }).toList()..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  Color _getReminderStatusColor(ReminderNew reminder) {
    final nextOccurrence = reminder.getNextOccurrence();
    if (nextOccurrence == null) return Colors.grey; // Finalizado
    
    final now = DateTime.now();
    return nextOccurrence.isBefore(now) ? Colors.red : Colors.orange;
  }

  IconData _getReminderStatusIcon(ReminderNew reminder) {
    final nextOccurrence = reminder.getNextOccurrence();
    if (nextOccurrence == null) return Icons.check_circle; // Finalizado
    
    final now = DateTime.now();
    return nextOccurrence.isBefore(now) ? Icons.cancel : Icons.access_time;
  }

  String _getReminderStatusText(ReminderNew reminder) {
    final nextOccurrence = reminder.getNextOccurrence();
    if (nextOccurrence == null) return 'FINALIZADO';
    
    final now = DateTime.now();
    return nextOccurrence.isBefore(now) ? 'VENCIDO' : 'PENDIENTE';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        title: const Text(
          'Calendario',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Filtro dropdown
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list, color: Colors.white),
              onSelected: _filterReminders,
              itemBuilder: (context) {
                final medicaments = _allReminders
                    .map((r) => r.title)
                    .toSet()
                    .toList()..sort();
                
                return [
                  const PopupMenuItem<String>(
                    value: null,
                    child: Text('Todos los recordatorios'),
                  ),
                  ...medicaments.map((med) => PopupMenuItem<String>(
                    value: med,
                    child: Text(med),
                  )),
                ];
              },
            ),
          ),
          // Botón de exportación
          IconButton(
            onPressed: _showExportDialog,
            icon: const Icon(Icons.file_download, color: Colors.white),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'AGENDA'),
            Tab(text: 'SEMANAL'),
            Tab(text: 'MENSUAL'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF1E3A5F),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAgendaView(),
                _buildWeeklyView(),
                _buildMonthlyView(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AgregarRecordatorioScreen(),
            ),
          );
          _loadReminders(); // Recargar después de agregar
        },
        backgroundColor: const Color(0xFF1E3A5F),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildAgendaView() {
    return Column(
      children: [
        // Selector de fecha
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedDay = _selectedDay.subtract(const Duration(days: 1));
                    _focusedDay = _selectedDay;
                  });
                },
                icon: const Icon(Icons.chevron_left, color: Color(0xFF1E3A5F)),
              ),
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDay,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: Color(0xFF1E3A5F),
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (date != null) {
                    setState(() {
                      _selectedDay = date;
                      _focusedDay = date;
                    });
                  }
                },
                child: Column(
                  children: [
                    Text(
                      DateFormat('EEEE', 'es').format(_selectedDay),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF1E3A5F),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _dateFormatter.format(_selectedDay),
                      style: const TextStyle(
                        fontSize: 24,
                        color: Color(0xFF1E3A5F),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedDay = _selectedDay.add(const Duration(days: 1));
                    _focusedDay = _selectedDay;
                  });
                },
                icon: const Icon(Icons.chevron_right, color: Color(0xFF1E3A5F)),
              ),
            ],
          ),
        ),
        // Lista de recordatorios del día
        Expanded(
          child: _buildRemindersList(_getRemindersForDay(_selectedDay)),
        ),
      ],
    );
  }

  Widget _buildWeeklyView() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TableCalendar<Reminder>(
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.week,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getRemindersForDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            locale: 'es_ES',
            calendarStyle: const CalendarStyle(
              outsideDaysVisible: false,
              markersMaxCount: 3,
              markerDecoration: BoxDecoration(
                color: Color(0xFF1E3A5F),
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Color(0xFF4A90E2),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Color(0xFF1E3A5F),
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
          ),
        ),
        Expanded(
          child: _buildRemindersList(_getRemindersForDay(_selectedDay)),
        ),
      ],
    );
  }

  Widget _buildMonthlyView() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TableCalendar<Reminder>(
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getRemindersForDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            locale: 'es_ES',
            calendarStyle: const CalendarStyle(
              outsideDaysVisible: false,
              markersMaxCount: 3,
              markerDecoration: BoxDecoration(
                color: Color(0xFF1E3A5F),
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Color(0xFF4A90E2),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Color(0xFF1E3A5F),
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
            ),
            availableCalendarFormats: const {
              CalendarFormat.month: 'Mes',
              CalendarFormat.twoWeeks: '2 semanas',
              CalendarFormat.week: 'Semana',
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
          ),
        ),
        Expanded(
          child: _buildRemindersList(_getRemindersForDay(_selectedDay)),
        ),
      ],
    );
  }

  Widget _buildRemindersList(List<Reminder> reminders) {
    if (reminders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _selectedMedicament != null
                  ? 'No hay recordatorios de $_selectedMedicament para este día'
                  : 'No hay recordatorios para este día',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reminders.length,
      itemBuilder: (context, index) {
        final reminder = reminders[index];
        return _buildReminderCard(reminder);
      },
    );
  }

  Widget _buildReminderCard(Reminder reminder) {
    final statusColor = _getReminderStatusColor(reminder);
    final statusIcon = _getReminderStatusIcon(reminder);
    
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetalleRecordatorioScreen(reminder: reminder),
          ),
        );
        if (result != null) {
          _loadReminders(); // Recargar después de ver detalles
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border(
            left: BorderSide(
              width: 4,
              color: statusColor,
            ),
          ),
        ),
        child: Row(
          children: [
            // Icono del tipo
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getTypeIcon(reminder.type),
                color: const Color(0xFF1E3A5F),
                size: 24,
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  if (reminder.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      reminder.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _timeFormatter.format(reminder.dateTime),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.repeat,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        reminder.frequency,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Estado del recordatorio
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    statusIcon,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getReminderStatusText(reminder),
                  style: TextStyle(
                    fontSize: 10,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showExportDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ExportBottomSheet(
        onExport: _handleExport,
        reminders: _filteredReminders,
      ),
    );
  }

  Future<void> _handleExport({
    required String period,
    required String format,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // Filtrar recordatorios por el período seleccionado
      final filteredByDate = _filteredReminders.where((reminder) {
        return reminder.dateTime.isAfter(startDate.subtract(const Duration(days: 1))) &&
               reminder.dateTime.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();

      if (format == 'PDF') {
        await ExportUtils.generatePDF(
          reminders: filteredByDate,
          startDate: startDate,
          endDate: endDate,
        );
      } else {
        await ExportUtils.generateCSV(
          reminders: filteredByDate,
          startDate: startDate,
          endDate: endDate,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$format generado y compartido exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exportando: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _ExportBottomSheet extends StatefulWidget {
  final Function({
    required String period,
    required String format,
    required DateTime startDate,
    required DateTime endDate,
  }) onExport;
  final List<Reminder> reminders;

  const _ExportBottomSheet({
    required this.onExport,
    required this.reminders,
  });

  @override
  State<_ExportBottomSheet> createState() => _ExportBottomSheetState();
}

class _ExportBottomSheetState extends State<_ExportBottomSheet> {
  String _selectedPeriod = 'Última semana';
  String _selectedFormat = 'PDF';
  bool _isLoading = false;

  final Map<String, Map<String, DateTime>> _periods = {
    'Última semana': {
      'start': DateTime.now().subtract(const Duration(days: 7)),
      'end': DateTime.now(),
    },
    'Último mes': {
      'start': DateTime.now().subtract(const Duration(days: 30)),
      'end': DateTime.now(),
    },
    'Últimos 3 meses': {
      'start': DateTime.now().subtract(const Duration(days: 90)),
      'end': DateTime.now(),
    },
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Exportar Recordatorios',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A5F),
            ),
          ),
          const SizedBox(height: 24),
          // Selector de período
          const Text(
            'Período:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _periods.keys.map((period) {
              final isSelected = period == _selectedPeriod;
              return ChoiceChip(
                label: Text(period),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedPeriod = period);
                  }
                },
                selectedColor: const Color(0xFF1E3A5F),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF1E3A5F),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          // Selector de formato
          const Text(
            'Formato:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: ['PDF', 'CSV'].map((format) {
              final isSelected = format == _selectedFormat;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: format == 'PDF' ? 8 : 0),
                  child: ChoiceChip(
                    label: SizedBox(
                      width: double.infinity,
                      child: Text(
                        format,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedFormat = format);
                      }
                    },
                    selectedColor: const Color(0xFF1E3A5F),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF1E3A5F),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          // Botón de exportar
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _handleExport,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.file_download, color: Colors.white),
              label: Text(
                _isLoading ? 'Exportando...' : 'Exportar $_selectedFormat',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExport() async {
    setState(() => _isLoading = true);

    final period = _periods[_selectedPeriod]!;
    
    await widget.onExport(
      period: _selectedPeriod,
      format: _selectedFormat,
      startDate: period['start']!,
      endDate: period['end']!,
    );

    setState(() => _isLoading = false);
    
    if (mounted) {
      Navigator.pop(context);
    }
  }
}
