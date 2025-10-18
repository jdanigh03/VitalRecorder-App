import 'package:flutter/material.dart';
import '../models/reminder.dart';
import '../services/reminder_service.dart';
import 'detalle_recordatorio.dart';
import 'agregar_recordatorio.dart';
import 'welcome.dart'; 
import 'asignar_cuidador.dart';
import 'ajustes.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({Key? key}) : super(key: key);

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  int _selectedIndex = 2; // Historial es el índice 2
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
        automaticallyImplyLeading: false,
        title: const Text(
          'Historial de Recordatorios',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // Filtros
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filtrar por:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Todos'),
                      selected: _filterType == 'Todos',
                      onSelected: (bool selected) {
                        setState(() {
                          _filterType = 'Todos';
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Medicamentos'),
                      selected: _filterType == 'Medicamentos',
                      onSelected: (bool selected) {
                        setState(() {
                          _filterType = 'Medicamentos';
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Actividades'),
                      selected: _filterType == 'Actividades',
                      onSelected: (bool selected) {
                        setState(() {
                          _filterType = 'Actividades';
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Completados'),
                      selected: _filterType == 'Completados',
                      onSelected: (bool selected) {
                        setState(() {
                          _filterType = 'Completados';
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Pendientes'),
                      selected: _filterType == 'Pendientes',
                      onSelected: (bool selected) {
                        setState(() {
                          _filterType = 'Pendientes';
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedDate == null
                            ? 'Selecciona una fecha'
                            : 'Fecha: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = picked;
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A90E2),
                      ),
                      child: const Text(
                        'Seleccionar',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    if (_selectedDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _selectedDate = null;
                          });
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Lista de recordatorios
          Expanded(
            child: FutureBuilder<List<Reminder>>(
              future: _reminderService.getAllReminders(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final allReminders = snapshot.data ?? [];
                final filteredReminders = _filterReminders(allReminders);

                if (filteredReminders.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay recordatorios que coincidan con el filtro',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredReminders.length,
                  itemBuilder: (context, index) {
                    final reminder = filteredReminders[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Icon(
                          reminder.type == 'Medicación'
                              ? Icons.medication
                              : reminder.type == 'Cita'
                                  ? Icons.calendar_today
                                  : Icons.task,
                          color: reminder.isCompleted
                              ? Colors.green
                              : const Color(0xFF4A90E2),
                          size: 32,
                        ),
                        title: Text(
                          reminder.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: reminder.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '${reminder.dateTime.day}/${reminder.dateTime.month}/${reminder.dateTime.year} - '
                              '${reminder.dateTime.hour.toString().padLeft(2, '0')}:${reminder.dateTime.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            Text(
                              reminder.type,
                              style: const TextStyle(
                                color: Color(0xFF4A90E2),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: Icon(
                          reminder.isCompleted
                              ? Icons.check_circle
                              : Icons.pending,
                          color: reminder.isCompleted
                              ? Colors.green
                              : Colors.orange,
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DetalleRecordatorioScreen(
                                reminder: reminder,
                              ),
                            ),
                          );
                          setState(() {}); // Refrescar la lista
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF4A90E2),
        unselectedItemColor: Colors.grey,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Cuidadores',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historial',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Ajustes',
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

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AsignarCuidadorScreen()),
        );
        break;
      case 2:
        // Ya estamos en Historial
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AjustesScreen()),
        );
        break;
    }
  }
}
