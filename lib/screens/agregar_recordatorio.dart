import 'package:flutter/material.dart';
import '../models/reminder.dart';

class AgregarRecordatorioScreen extends StatefulWidget {
  final Reminder? reminder;

  const AgregarRecordatorioScreen({Key? key, this.reminder}) : super(key: key);

  @override
  State<AgregarRecordatorioScreen> createState() => _AgregarRecordatorioScreenState();
}

class _AgregarRecordatorioScreenState extends State<AgregarRecordatorioScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _selectedFrequency = 'Diario';
  String _selectedType = 'medication';
  bool _notificationsEnabled = true;

  final List<String> _frequencies = [
    'Diario',
    'Cada 8 horas',
    'Cada 12 horas',
    'Semanal',
    'Mensual',
    'Personalizado'
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.reminder?.title ?? '');
    _descriptionController = TextEditingController(text: widget.reminder?.description ?? '');
    if (widget.reminder != null) {
      _selectedDate = widget.reminder!.dateTime;
      _selectedTime = TimeOfDay.fromDateTime(widget.reminder!.dateTime);
      _selectedFrequency = widget.reminder!.frequency;
      _selectedType = widget.reminder!.type;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
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
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
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
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _saveReminder() {
    if (_formKey.currentState!.validate()) {
      // Aquí guardarías el recordatorio en tu base de datos o estado global
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.reminder == null 
            ? 'Recordatorio creado exitosamente' 
            : 'Recordatorio actualizado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        title: Text(
          widget.reminder == null ? 'Nuevo Recordatorio' : 'Editar Recordatorio',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tipo de recordatorio',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTypeCard(
                      'medication',
                      'Medicamento',
                      Icons.medication,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTypeCard(
                      'activity',
                      'Actividad',
                      Icons.directions_run,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  hintText: _selectedType == 'medication' 
                    ? 'Ej: Amoxicilina 500mg' 
                    : 'Ej: Caminar 30 min',
                  prefixIcon: Icon(
                    _selectedType == 'medication' ? Icons.medication : Icons.directions_run,
                    color: Color(0xFF4A90E2),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa un nombre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Notas adicionales...',
                  prefixIcon: Icon(Icons.notes, color: Color(0xFF4A90E2)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectDate,
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: Color(0xFF4A90E2)),
                            SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fecha',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _selectTime,
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time, color: Color(0xFF4A90E2)),
                            SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hora',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '${_selectedTime.hour}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedFrequency,
                decoration: InputDecoration(
                  labelText: 'Frecuencia',
                  prefixIcon: Icon(Icons.repeat, color: Color(0xFF4A90E2)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _frequencies.map((String frequency) {
                  return DropdownMenuItem<String>(
                    value: frequency,
                    child: Text(frequency),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedFrequency = newValue!;
                  });
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notifications_active, color: Color(0xFF4A90E2)),
                        SizedBox(width: 12),
                        Text(
                          'Activar notificaciones',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _notificationsEnabled,
                      onChanged: (value) {
                        setState(() {
                          _notificationsEnabled = value;
                        });
                      },
                      activeColor: Color(0xFF4A90E2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveReminder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF4A90E2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.reminder == null ? 'Crear Recordatorio' : 'Guardar Cambios',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeCard(String type, String label, IconData icon, Color color) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
        });
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey,
              size: 32,
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}