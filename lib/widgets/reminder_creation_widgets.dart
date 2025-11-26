import 'package:flutter/material.dart';
import '../models/reminder_new.dart';
import '../reminder_schedule_calculator.dart';

/// Widget para seleccionar rango de fechas con presets
class DateRangeSelector extends StatefulWidget {
  final DateTime initialStartDate;
  final DateTime initialEndDate;
  final Function(DateTime startDate, DateTime endDate) onChanged;

  const DateRangeSelector({
    Key? key,
    required this.initialStartDate,
    required this.initialEndDate,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<DateRangeSelector> createState() => _DateRangeSelectorState();
}

class _DateRangeSelectorState extends State<DateRangeSelector> {
  late DateTime _startDate;
  late DateTime _endDate;
  DurationPreset _selectedPreset = DurationPreset.ONE_WEEK;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
  }

  void _updatePreset(DurationPreset preset) {
    setState(() {
      _selectedPreset = preset;
      if (preset != DurationPreset.CUSTOM) {
        _endDate = preset.calculateEndDate(_startDate);
        widget.onChanged(_startDate, _endDate);
      }
    });
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked;
        // Recalcular endDate si no es custom
        if (_selectedPreset != DurationPreset.CUSTOM) {
          _endDate = _selectedPreset.calculateEndDate(_startDate);
        }
        widget.onChanged(_startDate, _endDate);
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _selectedPreset = DurationPreset.CUSTOM;
        widget.onChanged(_startDate, _endDate);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Duración del recordatorio',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A5F),
          ),
        ),
        SizedBox(height: 12),
        
        // Presets
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DurationPreset.values.map((preset) {
            final isSelected = _selectedPreset == preset;
            return ChoiceChip(
              label: Text(preset.displayName),
              selected: isSelected,
              onSelected: (_) => _updatePreset(preset),
              selectedColor: Color(0xFF4A90E2),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
        
        SizedBox(height: 16),
        
        // Selectores de fecha
        Row(
          children: [
            Expanded(
              child: _buildDateCard(
                'Inicio',
                _startDate,
                Icons.calendar_today,
                _selectStartDate,
              ),
            ),
            SizedBox(width: 12),
            Icon(Icons.arrow_forward, color: Colors.grey),
            SizedBox(width: 12),
            Expanded(
              child: _buildDateCard(
                'Fin',
                _endDate,
                Icons.event,
                _selectEndDate,
              ),
            ),
          ],
        ),
        
        // Info de duración
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
              SizedBox(width: 8),
              Text(
                'Duración: ${_endDate.difference(_startDate).inDays + 1} días',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateCard(String label, DateTime date, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: Color(0xFF4A90E2)),
                SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              '${date.day}/${date.month}/${date.year}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget para seleccionar intervalo entre recordatorios
class IntervalSelector extends StatefulWidget {
  final IntervalType initialType;
  final int initialValue;
  final Function(IntervalType type, int value) onChanged;

  const IntervalSelector({
    Key? key,
    required this.initialType,
    required this.initialValue,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<IntervalSelector> createState() => _IntervalSelectorState();
}

class _IntervalSelectorState extends State<IntervalSelector> {
  late IntervalType _type;
  late int _value;
  bool _isCustom = false;
  final _customController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _value = widget.initialValue;
    
    // Verificar si es un valor personalizado
    final commonOptions = [4, 6, 8, 12];
    _isCustom = !commonOptions.contains(_value);
    if (_isCustom) {
      _customController.text = _value.toString();
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _updateInterval(int value) {
    setState(() {
      _value = value;
      _isCustom = false;
      _type = IntervalType.HOURS; // Forzar horas al seleccionar preset
      widget.onChanged(_type, _value);
    });
  }

  void _toggleCustom() {
    setState(() {
      _isCustom = !_isCustom;
      if (!_isCustom && _value == 0) {
        _value = 8;
        widget.onChanged(_type, _value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Frecuencia (Horas)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A5F),
          ),
        ),
        SizedBox(height: 16),
        
        // Opciones predefinidas (solo para HOURS)
        if (!_isCustom) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [4, 6, 8, 12].map((hours) {
              final isSelected = _value == hours && _type == IntervalType.HOURS;
              return ChoiceChip(
                label: Text(ReminderScheduleCalculator.getIntervalDisplayName(hours)),
                selected: isSelected,
                onSelected: (_) => _updateInterval(hours),
                selectedColor: Color(0xFF4A90E2),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
        ],
        
        // Opción personalizada
        SizedBox(height: 12),
        Row(
          children: [
            Checkbox(
              value: _isCustom,
              onChanged: (_) => _toggleCustom(),
              activeColor: Color(0xFF4A90E2),
            ),
            Text('Personalizado'),
            if (_isCustom) ...[
              SizedBox(width: 12),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _customController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    suffix: Text('h'),
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null && parsed > 0) {
                      _value = parsed;
                      // Forzamos tipo HOURS
                      if (_type != IntervalType.HOURS) {
                        _type = IntervalType.HOURS;
                      }
                      widget.onChanged(_type, _value);
                    }
                  },
                ),
              ),
            ],
          ],
        ),
        
        // Info de recordatorios por día
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_active, size: 16, color: Colors.green[700]),
              SizedBox(width: 8),
              Text(
                '${ReminderScheduleCalculator.calculateRemindersPerDay(_value)} recordatorios por día',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Widget para editar horarios diarios
class DailyScheduleEditor extends StatefulWidget {
  final List<TimeOfDay> initialTimes;
  final Function(List<TimeOfDay>) onChanged;

  const DailyScheduleEditor({
    Key? key,
    required this.initialTimes,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<DailyScheduleEditor> createState() => _DailyScheduleEditorState();
}

class _DailyScheduleEditorState extends State<DailyScheduleEditor> {
  late List<TimeOfDay> _times;

  @override
  void initState() {
    super.initState();
    _times = List.from(widget.initialTimes);
  }

  Future<void> _editTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _times[index],
    );
    
    if (picked != null) {
      setState(() {
        _times[index] = picked;
        _times = ReminderScheduleCalculator.sortSchedule(_times);
        widget.onChanged(_times);
      });
    }
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    
    if (picked != null) {
      setState(() {
        _times.add(picked);
        _times = ReminderScheduleCalculator.sortSchedule(_times);
        widget.onChanged(_times);
      });
    }
  }

  void _removeTime(int index) {
    if (_times.length > 1) {
      setState(() {
        _times.removeAt(index);
        widget.onChanged(_times);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Debe haber al menos un horario')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Horarios del día',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
            ),
            TextButton.icon(
              onPressed: _addTime,
              icon: Icon(Icons.add_circle_outline),
              label: Text('Agregar'),
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFF4A90E2),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        
        // Lista de horarios
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _times.length,
            separatorBuilder: (context, index) => Divider(height: 1),
            itemBuilder: (context, index) {
              final time = _times[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(0xFF4A90E2).withOpacity(0.1),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Color(0xFF4A90E2),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  ReminderScheduleCalculator.formatTimeOfDay(time),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(_getTimeOfDayLabel(time)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: Color(0xFF4A90E2)),
                      onPressed: () => _editTime(index),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeTime(index),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _getTimeOfDayLabel(TimeOfDay time) {
    if (time.hour >= 5 && time.hour < 12) return 'Mañana';
    if (time.hour >= 12 && time.hour < 18) return 'Tarde';
    return 'Noche';
  }
}

/// Widget de resumen del recordatorio
class ReminderSummaryCard extends StatelessWidget {
  final String title;
  final String type;
  final DateTime startDate;
  final DateTime endDate;
  final List<TimeOfDay> dailyTimes;

  const ReminderSummaryCard({
    Key? key,
    required this.title,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.dailyTimes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final days = endDate.difference(startDate).inDays + 1;
    final totalReminders = ReminderScheduleCalculator.calculateTotalReminders(
      startDate: startDate,
      endDate: endDate,
      dailyTimes: dailyTimes,
    );
    final typeText = type == 'medication' ? 'Medicamento' : 'Actividad';
    final icon = type == 'medication' ? Icons.medication : Icons.directions_run;
    final color = type == 'medication' ? Colors.blue : Colors.green;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color.shade700, size: 28),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      typeText,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          Divider(),
          SizedBox(height: 16),
          
          // Detalles
          _buildInfoRow(
            Icons.calendar_today,
            'Duración',
            '$days días (${_formatDate(startDate)} - ${_formatDate(endDate)})',
          ),
          SizedBox(height: 12),
          _buildInfoRow(
            Icons.notifications_active,
            'Horarios diarios',
            '${dailyTimes.length} veces al día',
          ),
          SizedBox(height: 12),
          
          // Lista de horarios
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: dailyTimes.map((time) {
                return Chip(
                  label: Text(
                    ReminderScheduleCalculator.formatTimeOfDay(time),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: color.shade50,
                  side: BorderSide(color: color.shade200),
                );
              }).toList(),
            ),
          ),
          
          SizedBox(height: 16),
          Divider(),
          SizedBox(height: 12),
          
          // Total
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.shade700,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Total: $totalReminders recordatorios',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Color(0xFF4A90E2)),
        SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
