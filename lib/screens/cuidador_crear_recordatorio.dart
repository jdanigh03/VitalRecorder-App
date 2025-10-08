import 'package:flutter/material.dart';
import '../models/reminder.dart';
import '../models/user.dart';
import '../services/reminder_service.dart';
import '../services/cuidador_service.dart';

class CuidadorCrearRecordatorioScreen extends StatefulWidget {
  final Reminder? reminder;
  final String? pacienteId; // ID del paciente preseleccionado

  const CuidadorCrearRecordatorioScreen({
    Key? key, 
    this.reminder,
    this.pacienteId,
  }) : super(key: key);

  @override
  State<CuidadorCrearRecordatorioScreen> createState() => _CuidadorCrearRecordatorioScreenState();
}

class _CuidadorCrearRecordatorioScreenState extends State<CuidadorCrearRecordatorioScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _selectedFrequency = 'Diario';
  String _selectedType = 'medication';
  bool _notificationsEnabled = true;
  
  List<UserModel> _pacientes = [];
  UserModel? _pacienteSeleccionado;
  bool _isLoadingPacientes = true;

  final CuidadorService _cuidadorService = CuidadorService();

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
    
    _cargarPacientes();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _cargarPacientes() async {
    try {
      setState(() => _isLoadingPacientes = true);
      
      final pacientes = await _cuidadorService.getPacientesAsignados();
      
      setState(() {
        _pacientes = pacientes;
        _isLoadingPacientes = false;
        
        // Si hay un paciente preseleccionado, encontrarlo
        if (widget.pacienteId != null) {
          _pacienteSeleccionado = pacientes.firstWhere(
            (p) => p.userId == widget.pacienteId,
            orElse: () => pacientes.isNotEmpty ? pacientes.first : pacientes.first,
          );
        } else if (pacientes.isNotEmpty) {
          _pacienteSeleccionado = pacientes.first;
        }
      });
    } catch (e) {
      print('Error cargando pacientes: $e');
      setState(() => _isLoadingPacientes = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar la lista de pacientes'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

  Future<void> _saveReminder() async {
    if (_formKey.currentState!.validate()) {
      if (_pacienteSeleccionado == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Por favor selecciona un paciente'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      try {
        // Mostrar loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: CircularProgressIndicator(
              color: Color(0xFF4A90E2),
            ),
          ),
        );

        // Combinar fecha y hora
        final combinedDateTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );

        // Crear objeto recordatorio
        final reminder = Reminder(
          id: widget.reminder?.id ?? '', // Vacío para nuevos
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          dateTime: combinedDateTime,
          frequency: _selectedFrequency,
          type: _selectedType,
          isCompleted: widget.reminder?.isCompleted ?? false,
        );

        // Crear recordatorio para el paciente seleccionado
        bool success = await _cuidadorService.crearRecordatorioParaPaciente(
          _pacienteSeleccionado!.userId!,
          reminder,
        );

        // Cerrar loading
        Navigator.pop(context);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.reminder == null 
                      ? 'Recordatorio creado exitosamente para ${_pacienteSeleccionado!.persona.nombres}' 
                      : 'Recordatorio actualizado exitosamente'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: Duration(seconds: 4),
            ),
          );
          Navigator.pop(context, true); // Retornar true para indicar que se guardó
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al guardar el recordatorio'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        // Cerrar loading si algo sale mal
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        title: Text(
          widget.reminder == null ? 'Crear Recordatorio para Paciente' : 'Editar Recordatorio',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingPacientes 
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFF4A90E2)),
                SizedBox(height: 16),
                Text(
                  'Cargando pacientes...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          )
        : _pacientes.isEmpty
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No tienes pacientes asignados',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Necesitas tener pacientes asignados para crear recordatorios',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selector de paciente
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person, color: Colors.blue[700], size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Seleccionar Paciente',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          DropdownButtonFormField<UserModel>(
                            value: _pacienteSeleccionado,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            items: _pacientes.map((paciente) {
                              return DropdownMenuItem<UserModel>(
                                value: paciente,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Color(0xFF4A90E2),
                                      radius: 16,
                                      child: Text(
                                        paciente.persona.nombres.isNotEmpty 
                                          ? paciente.persona.nombres[0].toUpperCase()
                                          : 'P',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            paciente.persona.nombres,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            paciente.email,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (UserModel? newValue) {
                              setState(() {
                                _pacienteSeleccionado = newValue;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Por favor selecciona un paciente';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Tipo de recordatorio
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
                        labelText: 'Nombre del recordatorio',
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
                        hintText: 'Instrucciones adicionales para el paciente...',
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
