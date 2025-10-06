import 'package:flutter/material.dart';

class EditarCuidadorScreen extends StatefulWidget {
  final Map<String, String> cuidador;
  
  const EditarCuidadorScreen({
    Key? key, 
    required this.cuidador,
  }) : super(key: key);

  @override
  State<EditarCuidadorScreen> createState() => _EditarCuidadorScreenState();
}

class _EditarCuidadorScreenState extends State<EditarCuidadorScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _emailController;
  late TextEditingController _telefonoController;
  late String _relacionSeleccionada;
  bool _isSaving = false;
  
  final List<String> _relaciones = [
    'Familiar',
    'Hijo/a',
    'Padre/Madre',
    'Esposo/a',
    'Cuidador profesional',
    'Amigo/a',
    'Enfermero/a',
    'Médico',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.cuidador['nombre']);
    _emailController = TextEditingController(text: widget.cuidador['email']);
    _telefonoController = TextEditingController(text: widget.cuidador['telefono']);
    _relacionSeleccionada = widget.cuidador['relacion'] ?? 'Familiar';
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    
    // Simular guardado
    await Future.delayed(Duration(milliseconds: 1500));
    
    setState(() => _isSaving = false);

    // Crear el cuidador actualizado
    final cuidadorActualizado = {
      'nombre': _nombreController.text.trim(),
      'email': _emailController.text.trim(),
      'telefono': _telefonoController.text.trim(),
      'relacion': _relacionSeleccionada,
    };

    // Debug output
    print('=== CUIDADOR ACTUALIZADO ===');
    print('Nombre: ${cuidadorActualizado['nombre']}');
    print('Email: ${cuidadorActualizado['email']}');
    print('Teléfono: ${cuidadorActualizado['telefono']}');
    print('Relación: ${cuidadorActualizado['relacion']}');

    // Retornar los datos actualizados
    Navigator.pop(context, cuidadorActualizado);

    // Mostrar éxito
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 12),
            Text('Cuidador actualizado exitosamente'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Color _getColorByRelacion(String relacion) {
    switch (relacion) {
      case 'Familiar':
      case 'Hijo/a':
      case 'Padre/Madre':
      case 'Esposo/a':
        return Colors.blue;
      case 'Cuidador profesional':
      case 'Enfermero/a':
      case 'Médico':
        return Colors.teal;
      case 'Amigo/a':
        return Colors.purple;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColorByRelacion(_relacionSeleccionada);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        title: const Text('Editar Cuidador', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: _isSaving 
                ? SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(Icons.save, color: Colors.white),
            onPressed: _isSaving ? null : _guardarCambios,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card de preview del cuidador
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withOpacity(0.8),
                            color,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _nombreController.text.isNotEmpty 
                              ? _nombreController.text[0].toUpperCase() 
                              : 'C',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Vista Previa',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _nombreController.text.isNotEmpty 
                          ? _nombreController.text 
                          : 'Nombre del cuidador',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Text(
                        _relacionSeleccionada,
                        style: TextStyle(
                          fontSize: 14,
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 24),
              
              // Formulario de edición
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color(0xFF4A90E2).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.edit,
                            color: Color(0xFF4A90E2),
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Información del Cuidador',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A5F),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    
                    // Nombre completo
                    _buildTextField(
                      controller: _nombreController,
                      label: 'Nombre completo',
                      hint: 'Ej: Juan Pérez',
                      icon: Icons.person,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor ingresa el nombre completo';
                        }
                        if (value.trim().length < 3) {
                          return 'El nombre debe tener al menos 3 caracteres';
                        }
                        return null;
                      },
                      onChanged: (value) => setState(() {}), // Para actualizar la vista previa
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Email
                    _buildTextField(
                      controller: _emailController,
                      label: 'Correo electrónico',
                      hint: 'ejemplo@correo.com',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor ingresa el correo electrónico';
                        }
                        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(value.trim())) {
                          return 'Ingresa un correo válido';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Teléfono
                    _buildTextField(
                      controller: _telefonoController,
                      label: 'Teléfono',
                      hint: '+591 12345678',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor ingresa el número de teléfono';
                        }
                        if (value.trim().length < 8) {
                          return 'Ingresa un número válido (mínimo 8 dígitos)';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Relación
                    _buildDropdownField(),
                  ],
                ),
              ),
              
              SizedBox(height: 24),
              
              // Información adicional
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFF4A90E2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFF4A90E2).withOpacity(0.3), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF4A90E2)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notificaciones automáticas',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A5F),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Este cuidador recibirá notificaciones según tus preferencias configuradas.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 80), // Espacio para el botón flotante
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _guardarCambios,
        backgroundColor: _isSaving ? Colors.grey : Color(0xFF4A90E2),
        icon: _isSaving 
            ? SizedBox(
                width: 20, 
                height: 20, 
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(Icons.save, color: Colors.white),
        label: Text(
          _isSaving ? 'Guardando...' : 'Guardar Cambios',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E3A5F),
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Color(0xFF4A90E2)),
            filled: true,
            fillColor: Color(0xFFF8F9FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFF4A90E2), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Relación con el paciente',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E3A5F),
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _relacionSeleccionada,
              isExpanded: true,
              items: _relaciones.map((String relacion) {
                return DropdownMenuItem<String>(
                  value: relacion,
                  child: Row(
                    children: [
                      Icon(Icons.people, color: Color(0xFF4A90E2)),
                      SizedBox(width: 12),
                      Text(relacion),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _relacionSeleccionada = newValue;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
