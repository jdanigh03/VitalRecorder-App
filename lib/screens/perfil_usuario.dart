import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';
import '../models/user.dart';

class PerfilUsuarioScreen extends StatefulWidget {
  const PerfilUsuarioScreen({Key? key}) : super(key: key);

  @override
  State<PerfilUsuarioScreen> createState() => _PerfilUsuarioScreenState();
}

class _PerfilUsuarioScreenState extends State<PerfilUsuarioScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores para los campos del formulario
  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _telefonoController = TextEditingController();
  List<TextEditingController> _familiarEmailControllers = [];
  List<String> _familiarEmails = [];
  
  // Variables de estado
  DateTime? _fechaNacimiento;
  String? _sexoSeleccionado;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditMode = false; // Controla si está en modo edición

  final List<String> _opcionesSexo = ['Masculino', 'Femenino', 'Otro', 'Prefiero no decir'];

  // Servicios de Firebase
  final UserService _userService = UserService();
  
  // Datos dinámicos de Firebase
  String _userEmail = '';
  DateTime? _accountCreated;
  UserModel? _currentUserData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nombresController.dispose();
    _apellidosController.dispose();
    _telefonoController.dispose();
    for (var controller in _familiarEmailControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _loadFamiliarEmails(List<String> emails) {
    _familiarEmails = List.from(emails);
    
    // Limpiar controladores existentes
    for (var controller in _familiarEmailControllers) {
      controller.dispose();
    }
    _familiarEmailControllers.clear();
    
    // Crear controladores para cada email existente
    for (String email in _familiarEmails) {
      final controller = TextEditingController(text: email);
      _familiarEmailControllers.add(controller);
    }
    
    // Si no hay emails, agregar al menos uno vacío
    if (_familiarEmails.isEmpty) {
      _addEmailField();
    }
  }
  
  void _addEmailField() {
    setState(() {
      _familiarEmails.add('');
      _familiarEmailControllers.add(TextEditingController());
    });
  }
  
  void _removeEmailField(int index) {
    if (_familiarEmailControllers.length > 1) {
      setState(() {
        _familiarEmailControllers[index].dispose();
        _familiarEmailControllers.removeAt(index);
        _familiarEmails.removeAt(index);
      });
    }
  }
  
  List<String> _getFamiliarEmailsList() {
    List<String> emails = [];
    for (var controller in _familiarEmailControllers) {
      final email = controller.text.trim();
      if (email.isNotEmpty) {
        emails.add(email);
      }
    }
    return emails;
  }

  Future<void> _loadUserData() async {
    try {
      // Obtener información básica del usuario
      final userInfo = await _userService.getUserDisplayInfo();
      _userEmail = userInfo['email'] ?? 'Sin email';
      
      // Obtener datos completos del usuario desde Firestore
      _currentUserData = await _userService.getCurrentUserData();
      
      // Obtener usuario de Firebase Auth para fecha de creación
      final firebaseUser = _userService.currentUser;
      if (firebaseUser != null && firebaseUser.metadata.creationTime != null) {
        _accountCreated = firebaseUser.metadata.creationTime;
      }
      
      if (_currentUserData != null) {
        // Cargar datos desde Firestore
        _nombresController.text = _currentUserData!.persona.nombres;
        _apellidosController.text = _currentUserData!.persona.apellidos;
        _fechaNacimiento = _currentUserData!.persona.fechaNac;  // Usar fechaNac
        _sexoSeleccionado = _currentUserData!.persona.sexo?.isNotEmpty == true 
            ? _currentUserData!.persona.sexo 
            : null;
        _telefonoController.text = _currentUserData!.settings.telefono;
        _loadFamiliarEmails(_currentUserData!.settings.familiarEmails);
      } else {
        // Si no hay datos en Firestore, usar valores predeterminados
        _nombresController.text = userInfo['nombre'] ?? 'Usuario';
        _apellidosController.text = '';
        _fechaNacimiento = null;
        _sexoSeleccionado = null;
        _telefonoController.text = '';
        _loadFamiliarEmails([]);
        
        // Crear usuario inicial si no existe
        await _userService.createInitialUser();
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando datos del usuario: \$e');
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error al cargar los datos del perfil');
    }
  }

  Future<void> _saveUserData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    
    try {
      // Obtener lista de emails familiares y validar
      final familiarEmailsList = _getFamiliarEmailsList();
      
      if (familiarEmailsList.isNotEmpty) {
        final validationResult = await _userService.validateFamiliarEmails(familiarEmailsList);
        if (!validationResult['isValid']) {
          setState(() => _isSaving = false);
          final invalidEmails = validationResult['invalid'] as List<String>;
          _showErrorSnackBar('Emails inválidos: ${invalidEmails.join(', ')}');
          return;
        }
      }

      // Crear objeto UserModel con todos los datos
      // Mantener las configuraciones existentes del usuario
      final currentSettings = _currentUserData?.settings ?? UserSettings(telefono: '');
      
      final updatedUser = UserModel(
        email: _userEmail,
        persona: UserPersona(
          nombres: _nombresController.text.trim(),
          apellidos: _apellidosController.text.trim(),
          fechaNac: _fechaNacimiento,  // Usar fechaNac
          sexo: _sexoSeleccionado,
        ),
        settings: UserSettings(
          telefono: _telefonoController.text.trim(),
          familiarEmails: familiarEmailsList,
          // Mantener las configuraciones existentes
          intensidadVibracion: currentSettings.intensidadVibracion,
          modoSilencio: currentSettings.modoSilencio,
          notificarAFamiliar: currentSettings.notificarAFamiliar,
        ),
        createdAt: _currentUserData?.createdAt ?? DateTime.now(),
      );

      // Guardar en Firestore
      final success = await _userService.createOrUpdateUser(updatedUser);
      
      setState(() {
        _isSaving = false;
        if (success) {
          _isEditMode = false; // Salir del modo edición al guardar
        }
      });
      
      if (success) {
        _currentUserData = updatedUser;
        _showSuccessSnackBar('Perfil actualizado exitosamente');
        
        // Log para debug
        print('=== PERFIL GUARDADO EN FIREBASE ===');
        print('Email: ${_userEmail}');
        print('Nombres: ${_nombresController.text}');
        print('Apellidos: ${_apellidosController.text}');
        print('Teléfono: ${_telefonoController.text}');
        print('Emails familiares: ${familiarEmailsList.join(', ')}');
        print('Guardado exitoso en Firestore');
      } else {
        _showErrorSnackBar('Error al guardar el perfil. Intenta nuevamente.');
      }
    } catch (e) {
      setState(() => _isSaving = false);
      print('Error guardando perfil: \$e');
      _showErrorSnackBar('Error inesperado al guardar el perfil');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _selectFechaNacimiento() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
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
    if (picked != null && picked != _fechaNacimiento) {
      setState(() {
        _fechaNacimiento = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E3A5F),
          title: const Text('Perfil de Usuario', style: TextStyle(color: Colors.white)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        title: const Text('Perfil de Usuario', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: _isEditMode ? [
          // Botón cancelar en modo edición
          TextButton(
            onPressed: _isSaving ? null : () {
              setState(() {
                _isEditMode = false;
                _loadUserData(); // Recargar datos originales
              });
            },
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          // Botón guardar en modo edición
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
            onPressed: _isSaving ? null : _saveUserData,
            tooltip: 'Guardar cambios',
          ),
        ] : null,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionCard(
                'Información Personal',
                Icons.person,
                Color(0xFF4A90E2),
                [
                  _buildTextField(
                    controller: _nombresController,
                    label: 'Nombres',
                    hint: 'Ingresa tu(s) nombre(s)',
                    icon: Icons.badge,
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return 'Los nombres son requeridos';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    controller: _apellidosController,
                    label: 'Apellidos',
                    hint: 'Ingresa tu(s) apellido(s)',
                    icon: Icons.badge_outlined,
                  ),
                  SizedBox(height: 16),
                  _buildDateField(),
                  SizedBox(height: 16),
                  _buildDropdownField(),
                ],
              ),
              SizedBox(height: 24),
              _buildSectionCard(
                'Información de Contacto',
                Icons.contact_phone,
                Color(0xFF2ECC71),
                [
                  _buildTextField(
                    controller: _telefonoController,
                    label: 'Teléfono',
                    hint: 'Número de teléfono',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return 'El teléfono es requerido';
                      }
                      if (value!.length < 8) {
                        return 'El teléfono debe tener al menos 8 dígitos';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  _buildFamiliarEmailsSection(),
                ],
              ),
              SizedBox(height: 24),
              _buildInfoCard(),
              SizedBox(height: 80), // Espacio para el botón flotante
            ],
          ),
        ),
      ),
      floatingActionButton: _isEditMode ? FloatingActionButton.extended(
        onPressed: _isSaving ? null : _saveUserData,
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
      ) : FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            _isEditMode = true;
          });
        },
        backgroundColor: Color(0xFF4A90E2),
        icon: Icon(Icons.edit, color: Colors.white),
        label: Text(
          'Editar Información',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, Color color, List<Widget> children) {
    return Container(
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
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          ...children,
        ],
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
          enabled: _isEditMode,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: _isEditMode ? Color(0xFF4A90E2) : Colors.grey),
            filled: true,
            fillColor: _isEditMode ? Color(0xFFF8F9FA) : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
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

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fecha de nacimiento',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E3A5F),
          ),
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: _isEditMode ? _selectFechaNacimiento : null,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: _isEditMode ? Color(0xFFF8F9FA) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[_isEditMode ? 300 : 200]!, width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: _isEditMode ? Color(0xFF4A90E2) : Colors.grey),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _fechaNacimiento != null 
                        ? DateFormat('dd/MM/yyyy').format(_fechaNacimiento!)
                        : 'Seleccionar fecha de nacimiento',
                    style: TextStyle(
                      fontSize: 16,
                      color: _fechaNacimiento != null 
                          ? Color(0xFF1E3A5F) 
                          : Colors.grey[600],
                    ),
                  ),
                ),
                if (_isEditMode)
                  Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
              ],
            ),
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
          'Sexo',
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
            color: _isEditMode ? Color(0xFFF8F9FA) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[_isEditMode ? 300 : 200]!, width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _sexoSeleccionado,
              hint: Row(
                children: [
                  Icon(Icons.person_outline, color: _isEditMode ? Color(0xFF4A90E2) : Colors.grey),
                  SizedBox(width: 16),
                  Text('Seleccionar sexo', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              isExpanded: true,
              items: _isEditMode ? _opcionesSexo.map((String opcion) {
                return DropdownMenuItem<String>(
                  value: opcion,
                  child: Row(
                    children: [
                      if (_sexoSeleccionado == null) ...[
                        Icon(Icons.person_outline, color: Color(0xFF4A90E2)),
                        SizedBox(width: 16),
                      ],
                      Text(opcion),
                    ],
                  ),
                );
              }).toList() : null,
              onChanged: _isEditMode ? (String? newValue) {
                setState(() {
                  _sexoSeleccionado = newValue;
                });
              } : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFamiliarEmailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Emails de familiares/cuidadores',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E3A5F),
              ),
            ),
            Spacer(),
            if (_isEditMode)
              IconButton(
                icon: Icon(Icons.add_circle_outline, color: Color(0xFF2ECC71)),
                onPressed: _addEmailField,
                tooltip: 'Agregar email',
              ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          'Emails para notificaciones de emergencia (opcional)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 12),
        ...List.generate(_familiarEmailControllers.length, (index) {
          return Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _familiarEmailControllers[index],
                    keyboardType: TextInputType.emailAddress,
                    enabled: _isEditMode,
                    validator: (value) {
                      if (value?.trim().isNotEmpty ?? false) {
                        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(value!.trim())) {
                          return 'Formato de email inválido';
                        }
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: 'ejemplo@correo.com',
                      prefixIcon: Icon(Icons.family_restroom, color: _isEditMode ? Color(0xFF2ECC71) : Colors.grey),
                      filled: true,
                      fillColor: _isEditMode ? Color(0xFFF8F9FA) : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Color(0xFF2ECC71), width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.red, width: 2),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
                if (_isEditMode && _familiarEmailControllers.length > 1)
                  Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: IconButton(
                      icon: Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: () => _removeEmailField(index),
                      tooltip: 'Eliminar email',
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
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
                  'Información de cuenta',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Email: $_userEmail',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Cuenta creada: ${_accountCreated != null ? DateFormat('dd/MM/yyyy').format(_accountCreated!) : 'No disponible'}',
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
    );
  }
}
