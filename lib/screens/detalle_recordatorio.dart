// ========================================
// ARCHIVO: lib/screens/agregar_recordatorio.dart
// ========================================
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AgregarRecordatorioScreen extends StatefulWidget {
  const AgregarRecordatorioScreen({Key? key}) : super(key: key);

  @override
  State<AgregarRecordatorioScreen> createState() => _AgregarRecordatorioScreenState();
}

class _AgregarRecordatorioScreenState extends State<AgregarRecordatorioScreen> {
  final _formKey = GlobalKey<FormState>();

  final _tituloCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();

  DateTime? _fechaSeleccionada;
  TimeOfDay? _horaSeleccionada;

  String _frecuenciaSeleccionada = 'Una vez';
  String _tipoSeleccionado = 'Medicamento';

  bool _guardando = false;

  final List<String> _frecuencias = ['Una vez', 'Diario', 'Semanal', 'Mensual'];
  final List<String> _tipos = ['Medicamento', 'Cita médica', 'Ejercicio', 'Otro'];

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  // ------------------ SELECCIONAR FECHA ------------------
  Future<void> _seleccionarFecha() async {
    final hoy = DateTime.now();
    final seleccion = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada ?? hoy,
      firstDate: hoy,
      lastDate: DateTime(hoy.year + 2),
      helpText: 'Seleccionar fecha',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4A90E2),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E3A5F),
            ),
          ),
          child: child!,
        );
      },
    );

    if (seleccion != null) {
      setState(() {
        _fechaSeleccionada = seleccion;
      });
    }
  }

  // ------------------ SELECCIONAR HORA ------------------
  Future<void> _seleccionarHora() async {
    final seleccion = await showTimePicker(
      context: context,
      initialTime: _horaSeleccionada ?? TimeOfDay.now(),
      helpText: 'Seleccionar hora',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4A90E2),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E3A5F),
            ),
          ),
          child: child!,
        );
      },
    );

    if (seleccion != null) {
      setState(() {
        _horaSeleccionada = seleccion;
      });
    }
  }

  // ------------------ GUARDAR EN FIRESTORE ------------------
  Future<void> _guardarRecordatorio() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fechaSeleccionada == null || _horaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona fecha y hora'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final fechaFinal = DateTime(
        _fechaSeleccionada!.year,
        _fechaSeleccionada!.month,
        _fechaSeleccionada!.day,
        _horaSeleccionada!.hour,
        _horaSeleccionada!.minute,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reminders')
          .add({
        'title': _tituloCtrl.text.trim(),
        'description': _descripcionCtrl.text.trim(),
        'dateTime': Timestamp.fromDate(fechaFinal),
        'frequency': _frecuenciaSeleccionada,
        'type': _tipoSeleccionado,
        'isCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text('Recordatorio guardado correctamente'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
          ),
        );
        Navigator.pop(context); // Volver atrás
      }
    } catch (e) {
      debugPrint("Error al guardar recordatorio: $e");
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al guardar el recordatorio'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ------------------ INTERFAZ DE USUARIO ------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo gradiente
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E3A5F), Color(0xFF2D5082), Color(0xFF4A90E2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Botón volver
                    Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Título
                    const Text(
                      'Nuevo Recordatorio',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Campo Título
                    _campoTexto(
                      label: 'Título',
                      controller: _tituloCtrl,
                      hint: 'Ej. Tomar medicamento',
                      icon: Icons.title_outlined,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
                    ),
                    const SizedBox(height: 16),

                    // Descripción
                    _campoTexto(
                      label: 'Descripción',
                      controller: _descripcionCtrl,
                      hint: 'Detalles del recordatorio',
                      icon: Icons.description_outlined,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Fecha
                    _campoSelector(
                      label: 'Fecha',
                      icon: Icons.calendar_today_outlined,
                      value: _fechaSeleccionada != null
                          ? DateFormat('dd/MM/yyyy').format(_fechaSeleccionada!)
                          : 'Seleccionar fecha',
                      onTap: _seleccionarFecha,
                    ),
                    const SizedBox(height: 16),

                    // Hora
                    _campoSelector(
                      label: 'Hora',
                      icon: Icons.access_time_outlined,
                      value: _horaSeleccionada != null
                          ? _horaSeleccionada!.format(context)
                          : 'Seleccionar hora',
                      onTap: _seleccionarHora,
                    ),
                    const SizedBox(height: 16),

                    // Frecuencia
                    _campoDropdown(
                      label: 'Frecuencia',
                      value: _frecuenciaSeleccionada,
                      items: _frecuencias,
                      onChanged: (v) => setState(() => _frecuenciaSeleccionada = v!),
                    ),
                    const SizedBox(height: 16),

                    // Tipo
                    _campoDropdown(
                      label: 'Tipo',
                      value: _tipoSeleccionado,
                      items: _tipos,
                      onChanged: (v) => setState(() => _tipoSeleccionado = v!),
                    ),
                    const SizedBox(height: 30),

                    // Botón guardar
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4A90E2).withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _guardando ? null : _guardarRecordatorio,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _guardando
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'Guardar Recordatorio',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------ WIDGETS REUTILIZABLES ------------------
  Widget _campoTexto({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          style: const TextStyle(color: Color(0xFF1E3A5F)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: Icon(icon, color: const Color(0xFF4A90E2)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          ),
        ),
      ],
    );
  }

  Widget _campoSelector({
    required String label,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF4A90E2)),
                const SizedBox(width: 12),
                Text(
                  value,
                  style: const TextStyle(color: Color(0xFF1E3A5F), fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _campoDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            items: items
                .map((item) => DropdownMenuItem(
                      value: item,
                      child: Text(item, style: const TextStyle(color: Color(0xFF1E3A5F))),
                    ))
                .toList(),
            onChanged: onChanged,
            decoration: const InputDecoration(border: InputBorder.none),
          ),
        ),
      ],
    );
  }
}
