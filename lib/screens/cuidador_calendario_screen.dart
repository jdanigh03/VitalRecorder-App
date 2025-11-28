import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/reminder_new.dart';
import '../models/user.dart';
import '../models/reminder_occurrence.dart';
import '../reminder_service_new.dart';
import '../services/cuidador_service.dart';
import 'cuidador_reminder_detail_screen.dart';

class CuidadorCalendarioScreen extends StatefulWidget {
  const CuidadorCalendarioScreen({Key? key}) : super(key: key);

  @override
  State<CuidadorCalendarioScreen> createState() => _CuidadorCalendarioScreenState();
}

class _CuidadorCalendarioScreenState extends State<CuidadorCalendarioScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ReminderServiceNew _reminderService = ReminderServiceNew();
  final CuidadorService _cuidadorService = CuidadorService();

  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  List<ReminderNew> _allReminders = [];
  List<ReminderNew> _filteredReminders = [];
  List<UserModel> _pacientes = [];
  UserModel? _selectedPaciente; // Null means "All patients"
  bool _isLoading = true;

  // Formatters
  final DateFormat _timeFormatter = DateFormat('HH:mm');
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // 1. Load Patients
      final pacientes = await _cuidadorService.getPacientes();
      _pacientes = pacientes;

      // 2. Load Reminders for ALL patients
      List<ReminderNew> allReminders = [];
      for (final paciente in pacientes) {
        final reminders = await _reminderService.getRemindersByPatient(paciente.userId!);
        allReminders.addAll(reminders);
      }

      setState(() {
        _allReminders = allReminders;
        _applyFilter(); // Initial filter (shows all)
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando datos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFilter() {
    setState(() {
      if (_selectedPaciente == null) {
        _filteredReminders = _allReminders;
      } else {
        _filteredReminders = _allReminders
            .where((r) => r.userId == _selectedPaciente!.userId)
            .toList();
      }
    });
  }

  List<ReminderOccurrence> _getRemindersForDay(DateTime day) {
    List<ReminderOccurrence> occurrences = [];
    
    for (var reminder in _filteredReminders) {
      final reminderOccurrences = reminder.calculateOccurrencesForDay(day);
      for (var date in reminderOccurrences) {
        occurrences.add(ReminderOccurrence(
          reminder: reminder,
          occurrenceDate: date,
        ));
      }
    }
    
    occurrences.sort((a, b) => a.occurrenceDate.compareTo(b.occurrenceDate));
    return occurrences;
  }

  Color _getReminderStatusColor(ReminderNew reminder) {
    if (reminder.isPaused) return Colors.grey;
    final nextOccurrence = reminder.getNextOccurrence();
    if (nextOccurrence == null) return Colors.grey;
    final now = DateTime.now();
    return nextOccurrence.isBefore(now) ? Colors.red : Colors.orange;
  }

  IconData _getReminderStatusIcon(ReminderNew reminder) {
    if (reminder.isPaused) return Icons.pause;
    final nextOccurrence = reminder.getNextOccurrence();
    if (nextOccurrence == null) return Icons.check_circle;
    final now = DateTime.now();
    return nextOccurrence.isBefore(now) ? Icons.cancel : Icons.access_time;
  }

  String _getReminderStatusText(ReminderNew reminder) {
    if (reminder.isPaused) return 'PAUSADO';
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

  String _getPatientName(String userId) {
    final paciente = _pacientes.firstWhere(
      (p) => p.userId == userId,
      orElse: () => UserModel(
        id: '',
        email: '',
        role: '',
        persona: UserPersona(nombres: 'Desconocido', apellidos: '', fechaNac: DateTime.now()),
        settings: UserSettings(telefono: ''),
        createdAt: DateTime.now(),
      ),
    );
    return paciente.persona.nombres;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        title: const Text(
          'Calendario General',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Patient Filter Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFF1E3A5F),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<UserModel?>(
                      value: _selectedPaciente,
                      dropdownColor: const Color(0xFF1E3A5F),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      isExpanded: true,
                      hint: const Text(
                        'Todos los pacientes',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: const TextStyle(color: Colors.white),
                      items: [
                        const DropdownMenuItem<UserModel?>(
                          value: null,
                          child: Text('Todos los pacientes'),
                        ),
                        ..._pacientes.map((paciente) {
                          return DropdownMenuItem<UserModel?>(
                            value: paciente,
                            child: Text(paciente.nombreCompleto),
                          );
                        }).toList(),
                      ],
                      onChanged: (UserModel? newValue) {
                        setState(() {
                          _selectedPaciente = newValue;
                          _applyFilter();
                        });
                      },
                    ),
                  ),
                ),
              ),
              TabBar(
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
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E3A5F)),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAgendaView(),
                _buildWeeklyView(),
                _buildMonthlyView(),
              ],
            ),
    );
  }

  Widget _buildAgendaView() {
    return Column(
      children: [
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
          child: TableCalendar<ReminderOccurrence>(
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.week,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: (day) {
              // TableCalendar expects a list of events. We can use the reminders directly here
              // just for the count (marker), or use the occurrences. 
              // Using reminders directly is safer for markers to avoid duplicates if we just want "dots".
              // But the user wants "number of activities". 
              // If a reminder has 3 occurrences in a day, should it show 3? 
              // The previous implementation used `_getRemindersForDay` which returned reminders.
              // If we want to show TOTAL occurrences, we should use the new logic.
              return _getRemindersForDay(day); 
            },
            startingDayOfWeek: StartingDayOfWeek.monday,
            locale: 'es_ES',
            calendarStyle: const CalendarStyle(
              outsideDaysVisible: false,
              markersMaxCount: 3,
              markerDecoration: BoxDecoration(color: Color(0xFF1E3A5F), shape: BoxShape.circle),
              todayDecoration: BoxDecoration(color: Color(0xFF4A90E2), shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(color: Color(0xFF1E3A5F), shape: BoxShape.circle),
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
            calendarBuilders: CalendarBuilders<ReminderOccurrence>(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return null;
                return Positioned(
                  bottom: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${events.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
          ),
        ),
        // Leyenda de indicadores
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFFF5F7FA),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Los números indican actividades programadas por día',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
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
          child: TableCalendar<ReminderOccurrence>(
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: (day) => _getRemindersForDay(day),
            startingDayOfWeek: StartingDayOfWeek.monday,
            locale: 'es_ES',
            calendarStyle: const CalendarStyle(
              outsideDaysVisible: false,
              markersMaxCount: 3,
              markerDecoration: BoxDecoration(color: Color(0xFF1E3A5F), shape: BoxShape.circle),
              todayDecoration: BoxDecoration(color: Color(0xFF4A90E2), shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(color: Color(0xFF1E3A5F), shape: BoxShape.circle),
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
            calendarBuilders: CalendarBuilders<ReminderOccurrence>(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return null;
                return Positioned(
                  bottom: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${events.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
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
        // Leyenda de indicadores
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFFF5F7FA),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Los números indican actividades programadas por día',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildRemindersList(_getRemindersForDay(_selectedDay)),
        ),
      ],
    );
  }

  Widget _buildRemindersList(List<ReminderOccurrence> occurrences) {
    if (occurrences.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No hay recordatorios para este día',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: occurrences.length,
      itemBuilder: (context, index) {
        final occurrence = occurrences[index];
        return _buildReminderCard(occurrence);
      },
    );
  }

  Widget _buildReminderCard(ReminderOccurrence occurrence) {
    final reminder = occurrence.reminder;
    final statusColor = _getReminderStatusColor(reminder);
    final statusIcon = _getReminderStatusIcon(reminder);
    final patientName = _getPatientName(reminder.userId ?? '');

    return GestureDetector(
      onTap: () async {
        // Find the patient object for this reminder
        final paciente = _pacientes.firstWhere(
          (p) => p.userId == reminder.userId,
          orElse: () => UserModel(
        id: '',
        email: '',
        role: '',
        persona: UserPersona(nombres: 'Desconocido', apellidos: '', fechaNac: DateTime.now()),
        settings: UserSettings(telefono: ''),
        createdAt: DateTime.now(),
          ),
        );

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CuidadorReminderDetailScreen(
              reminder: reminder,
              paciente: paciente,
              initialDate: occurrence.occurrenceDate,
            ),
          ),
        );
        _loadData(); // Reload when returning
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
            left: BorderSide(width: 4, color: statusColor),
          ),
        ),
        child: Row(
          children: [
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient Name Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      patientName,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
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
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        _timeFormatter.format(occurrence.occurrenceDate),
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 20),
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
}
