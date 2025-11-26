// ========================================
// ARCHIVO: lib/screens/register_screen.dart
// ========================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_wrapper.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _birthCtrl = TextEditingController();

  bool _obscure = true;
  DateTime? _birthDate;
  String _selectedRole = 'user'; // 'user' para paciente, 'cuidador' para cuidador

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    _birthCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 100, now.month, now.day);
    final last = DateTime(now.year - 10, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: first,
      lastDate: last,
      helpText: 'Fecha de Nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
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
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _onRegister() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Selecciona tu fecha de nacimiento')),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      final uid = cred.user!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': _emailCtrl.text.trim(),
        'role': _selectedRole, // Usar el rol seleccionado por el usuario
        'persona': {
          'nombres': _nameCtrl.text.trim(),
          'apellidos': '',
          'fecha_nac': Timestamp.fromDate(_birthDate!),
          'sexo': null,
        },
        'telefono': _phoneCtrl.text.trim(),
        'settings': {
          'intensidad_vibracion': 2,
          'modo_silencio': false,
          'notificar_a_familiar': false,
          'familiar_emails': [],
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      Navigator.of(context).pop();

      final roleMessage = _selectedRole == 'cuidador'
          ? 'Cuenta de cuidador creada correctamente'
          : 'Cuenta de paciente creada correctamente';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text(roleMessage),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      // Navegar directamente según el rol seleccionado
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );

    } on FirebaseAuthException catch (e) {
      Navigator.of(context).pop();

      String msg = 'No se pudo registrar';
      if (e.code == 'email-already-in-use') msg = 'Ese correo ya está en uso';
      if (e.code == 'weak-password') msg = 'La contraseña es muy débil';
      if (e.code == 'invalid-email') msg = 'Correo inválido';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text(msg)),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Ocurrió un problema inesperado'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo con gradiente
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
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 60),

                    // Logo
                    Center(
                      child: Image.asset(
                        'assets/vital_recorder_nobg.png',
                        height: 100,
                        width: 100,
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Registrarse',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('¿Ya tienes una cuenta?',
                            style: TextStyle(color: Colors.white70)),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Iniciar Sesión',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Nombre Completo',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameCtrl,
                      keyboardType: TextInputType.name,
                      style: TextStyle(color: Color(0xFF1E3A5F)),
                      validator: (v) =>
                          (v == null || v.trim().length < 3) ? 'Ingresa tu nombre' : null,
                      decoration: _inputDecoration(
                        hint: 'Nombre Apellidos',
                        icon: Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Correo Electrónico',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: Color(0xFF1E3A5F)),
                      validator: (v) {
                        final email = v?.trim() ?? '';
                        final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
                        return ok ? null : 'Correo inválido';
                      },
                      decoration: _inputDecoration(
                        hint: 'ejemplo@correo.com',
                        icon: Icons.email_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Contraseña',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      style: TextStyle(color: Color(0xFF1E3A5F)),
                      validator: (v) {
                        if (v == null || v.length < 6) return 'Mínimo 6 caracteres';
                        return null;
                      },
                      decoration: _inputDecoration(
                        hint: '••••••••••••',
                        icon: Icons.lock_outline,
                        suffix: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Número Celular',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: Color(0xFF1E3A5F)),
                      validator: (v) =>
                          (v == null || v.trim().length < 6) ? 'Celular inválido' : null,
                      decoration: _inputDecoration(
                        hint: '88888888',
                        icon: Icons.phone_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Fecha de Nacimiento',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickBirthDate,
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller: _birthCtrl,
                          style: TextStyle(color: Color(0xFF1E3A5F)),
                          validator: (v) =>
                              (_birthDate == null) ? 'Selecciona tu fecha' : null,
                          decoration: _inputDecoration(
                            hint: 'DD/MM/AAAA',
                            icon: Icons.calendar_today_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
                        ),
                        borderRadius: BorderRadius.circular(12.0),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF4A90E2).withOpacity(0.4),
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _onRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Registrarse',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            top: 40,
            left: 10,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400]),
      prefixIcon: Icon(icon, color: Color(0xFF4A90E2)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Color(0xFF4A90E2), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red[300]!, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      suffixIcon: suffix,
    );
  }
}