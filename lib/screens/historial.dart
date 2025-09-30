import 'package:flutter/material.dart';
import '../models/reminder.dart';
import 'detalle_recordatorio.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({Key? key}) : super(key: key);

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  String _filterType = 'Todos';
  DateTime? _selectedDate;

  final List<Reminder> _allReminders = [
    Reminder(
      id: '1',
      title: 'Amoxicilina 1g',
      description: 'Tomar 1 comprimido',
      dateTime: DateTime.now().subtract(Duration(days: 1)).copyWith(hour: 9),
      frequency: 'Diario',
      isCompleted: true,
    ),
    Reminder(
      id: '2',
      title: 'Ibuprofeno 400mg',
      description: 'Tomar con alimentos',
      dateTime: DateTime.now().subtract(Duration(days: 2)).copyWith(hour: 14),
      frequency: 'Cada 8 horas',
      isCompleted: true,
    ),
    Reminder(
      id: '3',
      title: 'Caminata',
      description: '30 minutos',
      dateTime: DateTime.now().subtract(Duration(days: 3)).copyWith(hour: 18),
      frequency: 'Diario',
      type: 'activity',
      isCompleted: false,
    ),
    Reminder(
      id: '4',
      title: 'Vitamina D',
      description: '1 cápsula',
      dateTime: DateTime.now().copyWith(hour: 8),
      frequency: 'Diario',
      isCompleted: true,
    ),
  ];

  List<Reminder> get _filteredReminders {
    List<Reminder> filtered = _allReminders;

    if (_filterType == 'Medicamentos') {
      filtered = filtered.where((r) => r.type == 'medication').toList();
    } else if (_filterType == 'Actividades') {
      filtered = filtered.where((r) => r.type == 'activity').toList();
    } else if (_filterType == 'Completados') {
      filtered = filtered.where((r) => r.isCompleted).toList();
    } else if (_filterType == 'Pendientes') {
      filtered = filtered.where((r) => !r.isCompleted).toList();
    }

    if (_selectedDate != null) {
      filtered = filtered.where((r) {
        return r.dateTime.year == _selectedDate!.year &&
            r.dateTime.month == _selectedDate!.month &&
            r.dateTime.day == _selectedDate!.day;
      }).toList();
    }

    filtered.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        title: const Text(
          'Historial de Recordatorios',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Todos'),
                      _buildFilterChip('Medicamentos'),
                      _buildFilterChip('Actividades'),
                      _buildFilterChip('Completados'),
                      _buildFilterChip('Pendientes'),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                InkWell(
                  onTap: _selectDate,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today, color: Color(0xFF4A90E2), size: 20),
                            SizedBox(width: 8),
                            Text(
                              _selectedDate == null
                                  ? 'Filtrar por fecha'
                                  : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        if (_selectedDate != null)
                          IconButton(
                            icon: Icon(Icons.close, size: 20),
                            onPressed: () {
                              setState(() {
                                _selectedDate = null;
                              });
                            },
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredReminders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No hay recordatorios',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _filteredReminders.length,
                    itemBuilder: (context, index) {
                      final reminder = _filteredReminders[index];
                      return _buildReminderCard(reminder);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filterType == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _filterType = label;
          });
        },
        backgroundColor: Colors.grey[200],
        selectedColor: Color(0xFF4A90E2),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildReminderCard(Reminder reminder) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetalleRecordatorioScreen(reminder: reminder),
          ),
        );
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
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: reminder.type == 'medication'
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                reminder.type == 'medication' ? Icons.medication : Icons.directions_run,
                color: reminder.type == 'medication' ? Colors.blue : Colors.green,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 4),
                  Text(
                    '${reminder.dateTime.day}/${reminder.dateTime.month}/${reminder.dateTime.year} - ${reminder.dateTime.hour}:${reminder.dateTime.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              reminder.isCompleted ? Icons.check_circle : Icons.cancel,
              color: reminder.isCompleted ? Colors.green : Colors.red,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF4A90E2),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
}