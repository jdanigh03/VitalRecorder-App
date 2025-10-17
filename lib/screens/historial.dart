import 'package:flutter/material.dart';
import '../models/reminder.dart';
import '../services/reminder_service.dart';
import 'detalle_recordatorio.dart';
import 'agregar_recordatorio.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({Key? key}) : super(key: key);

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  String _filterType = 'Todos';
  DateTime? _selectedDate;
  final ReminderService _reminderService = ReminderService();

  List<Reminder> _filterReminders(List<Reminder> allReminders) {
    List<Reminder> filtered = List.from(allReminders);

    if (_filterType == 'Medicamentos') {
      filtered = filtered.where((r) => r.type == 'Medicación').toList();
    } else if (_filterType == 'Actividades') {
      filtered = filtered.where((r) => r.type == 'Tarea' || r.type == 'Cita').toList();
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
            child: FutureBuilder<List<Reminder>>(
              future: _reminderService.getReminderHistory(), // Usar el nuevo método para el historial
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF4A90E2),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 80,
                          color: Colors.red[300],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Error al cargar recordatorios',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.red[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Intenta nuevamente',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final allReminders = snapshot.data ?? [];
                final filteredReminders = _filterReminders(allReminders);

                if (filteredReminders.isEmpty) {
                  return Center(
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
                          allReminders.isEmpty 
                            ? 'No hay recordatorios'
                            : 'No hay recordatorios que coincidan con el filtro',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (allReminders.isEmpty) ...[
                          SizedBox(height: 8),
                          Text(
                            'Crea tu primer recordatorio',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                          SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AgregarRecordatorioScreen(),
                                ),
                              );
                              setState(() {}); // Forzar recarga del FutureBuilder
                            },
                            icon: Icon(Icons.add),
                            label: Text('Agregar Recordatorio'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF4A90E2),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: filteredReminders.length,
                  itemBuilder: (context, index) {
                    final reminder = filteredReminders[index];
                    return _buildReminderCard(reminder);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AgregarRecordatorioScreen(),
            ),
          );
          setState(() {}); // Forzar recarga del FutureBuilder
        },
        backgroundColor: Color(0xFF4A90E2),
        child: Icon(Icons.add, color: Colors.white),
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
                color: reminder.type == 'Medicación' ? Colors.blue.withOpacity(0.1) : 
                       reminder.type == 'Cita' ? Colors.purple.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                reminder.type == 'Medicación' ? Icons.medication : 
                reminder.type == 'Cita' ? Icons.event : Icons.task,
                color: reminder.type == 'Medicación' ? Colors.blue : 
                       reminder.type == 'Cita' ? Colors.purple : Colors.green,
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