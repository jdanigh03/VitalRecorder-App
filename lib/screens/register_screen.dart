import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final _birthCtrl = TextEditingController(); // solo para mostrar el texto

  bool _obscure = true;
  DateTime? _birthDate;

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
    final last = DateTime(now.year - 10, now.month, now.day); // mínimo 10 años
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: first,
      lastDate: last,
      helpText: 'Fecha de Nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  // El método _onRegister va aquí
  Future<void> _onRegister() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona tu fecha de nacimiento')),
      );
      return;
    }

    // Loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1) Crear cuenta en Auth
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      // 2) Guardar perfil en Firestore
      final uid = cred.user!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': _emailCtrl.text.trim(),
        'role': 'user',
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
          'familiar_email': null,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      Navigator.of(context).pop(); // cierra loader

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuenta creada correctamente')),
      );

      // Vuelve al login
      Navigator.pop(context);

    } on FirebaseAuthException catch (e) {
      Navigator.of(context).pop(); // cierra loader

      String msg = 'No se pudo registrar';
      if (e.code == 'email-already-in-use') msg = 'Ese correo ya está en uso';
      if (e.code == 'weak-password') msg = 'La contraseña es muy débil';
      if (e.code == 'invalid-email') msg = 'Correo inválido';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ocurrió un problema inesperado')),
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
                colors: [Color(0xFF00E5FF), Color(0xFF1A237E)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
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
                    const SizedBox(height: 40),

                    const Text(
                      'Registrarse',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('¿Ya tienes una cuenta?',
                            style: TextStyle(color: Colors.white)),
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

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Nombre Completo:',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                    const SizedBox(height: 4),
                    _RoundedField(
                      controller: _nameCtrl,
                      hint: 'Nombre Apellidos',
                      keyboard: TextInputType.name,
                      validator: (v) =>
                          (v == null || v.trim().length < 3) ? 'Ingresa tu nombre' : null,
                    ),
                    const SizedBox(height: 12),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Contraseña:',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      validator: (v) {
                        if (v == null || v.length < 6) return 'Mínimo 6 caracteres';
                        return null;
                      },
                      decoration: _inputDecoration(
                        hint: '••••••••••••',
                        suffix: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Correo Electrónico:',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                    const SizedBox(height: 4),
                    _RoundedField(
                      controller: _emailCtrl,
                      hint: 'ejemplo@correo.com',
                      keyboard: TextInputType.emailAddress,
                      validator: (v) {
                        final email = v?.trim() ?? '';
                        final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
                        return ok ? null : 'Correo inválido';
                      },
                    ),
                    const SizedBox(height: 12),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Número Celular:',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                    const SizedBox(height: 4),
                    _RoundedField(
                      controller: _phoneCtrl,
                      hint: '88888888',
                      keyboard: TextInputType.phone,
                      validator: (v) =>
                          (v == null || v.trim().length < 6) ? 'Celular inválido' : null,
                    ),
                    const SizedBox(height: 12),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Fecha de Nacimiento:',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: _pickBirthDate,
                      child: AbsorbPointer(
                        child: _RoundedField(
                          controller: _birthCtrl,
                          hint: 'DD/MM/AAAA',
                          keyboard: TextInputType.datetime,
                          validator: (v) =>
                              (_birthDate == null) ? 'Selecciona tu fecha' : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    ElevatedButton(
                      onPressed: _onRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Registrarse',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 24),
/*
                    const Text(
                      'O Regístrate Con',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SocialButton(
                          imagePath: 'assets/Google__G__logo.svg.png',
                          onTap: () {
                            // Implementar Google Sign-In si lo usarás
                          },
                        ),
                        const SizedBox(width: 20),
                        _SocialButton(
                          imagePath: 'assets/2023_Facebook_icon.svg.png',
                          onTap: () {
                            // Implementar Facebook Login si lo usarás
                          },
                        ),
                      ],
                    ),*/
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      suffixIcon: suffix,
    );
  }
}

class _RoundedField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboard;
  final String? Function(String?)? validator;

  const _RoundedField({
    required this.controller,
    required this.hint,
    required this.keyboard,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String imagePath;
  final VoidCallback onTap;

  const _SocialButton({required this.imagePath, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Image.asset(imagePath, height: 40.0),
      ),
    );
  }
}
