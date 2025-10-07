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
  final _familiarEmailController = TextEditingController();
  
  // Variables de estado
  DateTime? _fechaNacimiento;
  String? _sexoSeleccionado;
  int _intensidadVibracion = 2;
  bool _modoSilencio = false;
  bool _notificarAFamiliar = false;
  bool _isLoading = true;
  bool _isSaving = false;

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
    _familiarEmailController.dispose();
    super.dispose();
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
        _familiarEmailController.text = _currentUserData!.settings.familiarEmail ?? '';  // Usar familiarEmail
        _intensidadVibracion = _currentUserData!.settings.intensidadVibracion;
        _modoSilencio = _currentUserData!.settings.modoSilencio;
        _notificarAFamiliar = _currentUserData!.settings.notificarAFamiliar;
      } else {
        // Si no hay datos en Firestore, usar valores predeterminados
        _nombresController.text = userInfo['nombre'] ?? 'Usuario';
        _apellidosController.text = '';
        _fechaNacimiento = null;
        _sexoSeleccionado = null;
        _telefonoController.text = '';
        _familiarEmailController.text = '';
        _intensidadVibracion = 2;
        _modoSilencio = false;
        _notificarAFamiliar = false;
        
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
      // Validar email del familiar si se proporcionó
      if (_familiarEmailController.text.trim().isNotEmpty) {
        final emailValido = await _userService.validateFamiliarEmail(_familiarEmailController.text.trim());
        if (!emailValido) {
          setState(() => _isSaving = false);
          _showErrorSnackBar('El email del familiar no es válido o es el mismo que el tuyo');
          return;
        }
      }

      // Crear objeto UserModel con todos los datos
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
          familiarEmail: _familiarEmailController.text.trim().isNotEmpty   // Usar familiarEmail
              ? _familiarEmailController.text.trim() 
              : null,
          intensidadVibracion: _intensidadVibracion,
          modoSilencio: _modoSilencio,
          notificarAFamiliar: _notificarAFamiliar,
        ),
        createdAt: _currentUserData?.createdAt ?? DateTime.now(),
      );

      // Guardar en Firestore
      final success = await _userService.createOrUpdateUser(updatedUser);
      
      setState(() => _isSaving = false);
      
      if (success) {
        _currentUserData = updatedUser;
        _showSuccessSnackBar('Perfil actualizado exitosamente');
        
        // Log para debug
        print('=== PERFIL GUARDADO EN FIREBASE ===');
        print('Email: ${_userEmail}');
        print('Nombres: ${_nombresController.text}');
        print('Apellidos: ${_apellidosController.text}');
        print('Teléfono: ${_telefonoController.text}');
        print('Email familiar: ${_familiarEmailController.text}');
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
            onPressed: _isSaving ? null : _saveUserData,
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
                  _buildTextField(
                    controller: _familiarEmailController,
                    label: 'Email del familiar/cuidador',
                    hint: 'Email para notificaciones (opcional)',
                    icon: Icons.family_restroom,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value?.trim().isNotEmpty ?? false) {
                        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(value!)) {
                          return 'Ingresa un email válido';
                        }
                      }
                      return null;
                    },
                  ),
                ],
              ),
              SizedBox(height: 24),
              _buildSectionCard(
                'Configuraciones',
                Icons.settings,
                Color(0xFF9B59B6),
                [
                  _buildIntensidadVibracion(),
                  SizedBox(height: 16),
                  _buildSwitchTile(
                    title: 'Modo silencio',
                    subtitle: 'Desactivar sonidos de notificación',
                    icon: Icons.volume_off,
                    value: _modoSilencio,
                    onChanged: (value) => setState(() => _modoSilencio = value),
                  ),
                  SizedBox(height: 8),
                  _buildSwitchTile(
                    title: 'Notificar a familiar',
                    subtitle: 'Enviar copia de notificaciones al familiar',
                    icon: Icons.notifications_active,
                    value: _notificarAFamiliar,
                    onChanged: (value) => setState(() => _notificarAFamiliar = value),
                  ),
                ],
              ),
              SizedBox(height: 24),
              _buildInfoCard(),
              SizedBox(height: 80), // Espacio para el botón flotante
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
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
          onTap: _selectFechaNacimiento,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Color(0xFF4A90E2)),
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
            color: Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _sexoSeleccionado,
              hint: Row(
                children: [
                  Icon(Icons.person_outline, color: Color(0xFF4A90E2)),
                  SizedBox(width: 16),
                  Text('Seleccionar sexo', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              isExpanded: true,
              items: _opcionesSexo.map((String opcion) {
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
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _sexoSeleccionado = newValue;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIntensidadVibracion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.vibration, color: Color(0xFF9B59B6), size: 20),
            SizedBox(width: 8),
            Text(
              'Intensidad de vibración',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E3A5F),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          'Nivel $_intensidadVibracion',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Slider(
          value: _intensidadVibracion.toDouble(),
          min: 0,
          max: 5,
          divisions: 5,
          activeColor: Color(0xFF9B59B6),
          inactiveColor: Color(0xFF9B59B6).withOpacity(0.3),
          onChanged: (value) {
            setState(() {
              _intensidadVibracion = value.round();
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Desactivada', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            Text('Máxima', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: Color(0xFF9B59B6), size: 24),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Color(0xFF9B59B6),
          ),
        ],
      ),
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
