import 'package:flutter/material.dart';
import '../models/reminder_new.dart';
import '../reminder_schedule_calculator.dart';
import '../widgets/reminder_creation_widgets.dart';

class AgregarRecordatorioNewScreen extends StatefulWidget {
  final ReminderNew? reminder; // Para editar

  const AgregarRecordatorioNewScreen({
    Key? key,
    this.reminder,
  }) : super(key: key);

  @override
  State<AgregarRecordatorioNewScreen> createState() =>
      _AgregarRecordatorioNewScreenState();
}

class _AgregarRecordatorioNewScreenState
    extends State<AgregarRecordatorioNewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pageController = PageController();

  int _currentStep = 0;
  String _selectedType = 'medication';
  late DateTime _startDate;
  late DateTime _endDate;
  TimeOfDay _startTime = TimeOfDay(hour: 8, minute: 0);
  IntervalType _intervalType = IntervalType.HOURS;
  int _intervalValue = 8;
  List<TimeOfDay> _dailyTimes = [];

  @override
  void initState() {
    super.initState();

    // Inicializar valores
    if (widget.reminder != null) {
      _titleController.text = widget.reminder!.title;
      _descriptionController.text = widget.reminder!.description;
      _selectedType = widget.reminder!.type;
      _startDate = widget.reminder!.startDate;
      _endDate = widget.reminder!.endDate;
      _intervalType = widget.reminder!.intervalType;
      _intervalValue = widget.reminder!.intervalValue;
      _dailyTimes = List.from(widget.reminder!.dailyScheduleTimes);
      _startTime = TimeOfDay(
        hour: _startDate.hour,
        minute: _startDate.minute,
      );
    } else {
      _startDate = DateTime.now();
      _endDate = DurationPreset.ONE_WEEK.calculateEndDate(_startDate);
      _calculateInitialSchedule();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _calculateInitialSchedule() {
    if (_intervalType == IntervalType.HOURS) {
      _dailyTimes = ReminderScheduleCalculator.calculateDailySchedule(
        startTime: _startTime,
        intervalHours: _intervalValue,
      );
    } else {
      _dailyTimes = [_startTime];
    }
  }

  void _nextStep() {
    if (_currentStep < 4) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _saveReminder();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );

    if (picked != null) {
      setState(() {
        _startTime = picked;
        _calculateInitialSchedule();
      });
    }
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor completa todos los campos requeridos'),
          backgroundColor: Colors.orange,
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
          child: CircularProgressIndicator(color: Color(0xFF4A90E2)),
        ),
      );

      // Combinar fecha y hora de inicio
      final combinedStartDate = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      // Combinar fecha de fin con última hora del día
      final combinedEndDate = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        23,
        59,
      );

      // Crear el recordatorio
      final reminder = ReminderNew(
        id: widget.reminder?.id ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        startDate: combinedStartDate,
        endDate: combinedEndDate,
        intervalType: _intervalType,
        intervalValue: _intervalValue,
        dailyScheduleTimes: _dailyTimes,
        createdAt: widget.reminder?.createdAt ?? DateTime.now(),
      );

      // TODO: Aquí llamarías al service para guardar
      // await reminderServiceNew.createReminderWithConfirmations(reminder);

      // Cerrar loading
      Navigator.pop(context);

      // Mostrar éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.reminder == null
                      ? 'Recordatorio creado exitosamente'
                      : 'Recordatorio actualizado exitosamente',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: Duration(seconds: 4),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      Navigator.pop(context); // Cerrar loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        title: Text(
          widget.reminder == null
              ? 'Nuevo Recordatorio'
              : 'Editar Recordatorio',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Indicador de progreso
          _buildProgressIndicator(),

          // Contenido
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(), // Tipo + Info básica
                _buildStep2(), // Rango de fechas
                _buildStep3(), // Intervalo
                _buildStep4(), // Horarios personalizables
                _buildStep5(), // Resumen
              ],
            ),
          ),

          // Botones de navegación
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      color: Colors.white,
      child: Row(
        children: List.generate(5, (index) {
          final isActive = index <= _currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Color(0xFF4A90E2)
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (index < 4) SizedBox(width: 4),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader(
              'Paso 1 de 5',
              'Información básica',
              'Selecciona el tipo y nombre del recordatorio',
            ),
            SizedBox(height: 24),

            // Tipo de recordatorio
            Text(
              'Tipo de recordatorio',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
            ),
            SizedBox(height: 12),
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
                SizedBox(width: 12),
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

            SizedBox(height: 24),

            // Nombre
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Nombre *',
                hintText: _selectedType == 'medication'
                    ? 'Ej: Amoxicilina 500mg'
                    : 'Ej: Caminar 30 min',
                prefixIcon: Icon(
                  _selectedType == 'medication'
                      ? Icons.medication
                      : Icons.directions_run,
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

            SizedBox(height: 16),

            // Descripción
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText: 'Notas adicionales...',
                prefixIcon: Icon(Icons.notes, color: Color(0xFF4A90E2)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),

            SizedBox(height: 24),

            // Hora inicial
            InkWell(
              onTap: _selectStartTime,
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
                          'Hora de inicio',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        Text(
                          ReminderScheduleCalculator.formatTimeOfDay(_startTime),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Spacer(),
                    Icon(Icons.edit, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            'Paso 2 de 5',
            'Duración',
            'Define cuánto tiempo durará el recordatorio',
          ),
          SizedBox(height: 24),
          DateRangeSelector(
            initialStartDate: _startDate,
            initialEndDate: _endDate,
            onChanged: (start, end) {
              setState(() {
                _startDate = start;
                _endDate = end;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            'Paso 3 de 5',
            'Frecuencia',
            'Define cada cuánto se repetirá el recordatorio',
          ),
          SizedBox(height: 24),
          IntervalSelector(
            initialType: _intervalType,
            initialValue: _intervalValue,
            onChanged: (type, value) {
              setState(() {
                _intervalType = type;
                _intervalValue = value;
                _calculateInitialSchedule();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            'Paso 4 de 5',
            'Horarios del día',
            'Ajusta los horarios según tus necesidades',
          ),
          SizedBox(height: 24),
          DailyScheduleEditor(
            initialTimes: _dailyTimes,
            onChanged: (times) {
              setState(() {
                _dailyTimes = times;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep5() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            'Paso 5 de 5',
            'Resumen',
            'Revisa todos los detalles antes de guardar',
          ),
          SizedBox(height: 24),
          ReminderSummaryCard(
            title: _titleController.text.isNotEmpty
                ? _titleController.text
                : 'Sin nombre',
            type: _selectedType,
            startDate: _startDate,
            endDate: _endDate,
            dailyTimes: _dailyTimes,
          ),
        ],
      ),
    );
  }

  Widget _buildStepHeader(String step, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          step,
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF4A90E2),
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A5F),
          ),
        ),
        SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
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

  Widget _buildNavigationButtons() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Color(0xFF4A90E2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Anterior',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A90E2),
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Color(0xFF4A90E2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _currentStep == 4 ? 'Crear Recordatorio' : 'Siguiente',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
