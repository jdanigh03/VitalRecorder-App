// ============================================
// ARCHIVO: lib/screens/asignar_cuidador.dart
// ============================================
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AsignarCuidadorScreen extends StatefulWidget {
  const AsignarCuidadorScreen({Key? key}) : super(key: key);

  @override
  State<AsignarCuidadorScreen> createState() => _AsignarCuidadorScreenState();
}

class _AsignarCuidadorScreenState extends State<AsignarCuidadorScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _relacionCtrl = TextEditingController();
  bool _notificar = false;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _relacionCtrl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // Cargar los datos actuales del cuidador (si existen)
  // ------------------------------------------------------------
  Future<void> _loadCurrentSettings() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data()?['settings'] ?? {};
      setState(() {
        _notificar = data['notificar_a_familiar'] ?? false;
        _emailCtrl.text = data['familiar_email'] ?? '';
        _nombreCtrl.text = data['familiar_nombre'] ?? '';
        _relacionCtrl.text = data['familiar_relacion'] ?? '';
      });
    }
  }

  // ------------------------------------------------------------
  // Guardar datos del cuidador en Firestore
  // ------------------------------------------------------------
  Future<void> _saveCuidador() async {
    if (_formKey.currentState?.validate() != true) return;

    final user = _auth.currentUser;
    if (user == null) return;

    // Mostrar loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'settings': {
          'notificar_a_familiar': _notificar,
          'familiar_email': _emailCtrl.text.trim(),
          'familiar_nombre': _nombreCtrl.text.trim(),
          'familiar_relacion': _relacionCtrl.text.trim(),
        }
      });

      Navigator.pop(context); // Cerrar loader

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Datos del cuidador actualizados'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar los datos: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ------------------------------------------------------------
  // Interfaz visual
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo degradado azul
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
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Botón volver
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 10),

                    const Center(
                      child: Text(
                        'Asignar Cuidador',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Agrega un pariente o persona responsable para recibir notificaciones.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 40),

                    const Text(
                      'Nombre completo',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nombreCtrl,
                      style: const TextStyle(color: Color(0xFF1E3A5F)),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
                      decoration: _inputDecoration(
                        hint: 'Ej. Juan Pérez',
                        icon: Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Correo electrónico del cuidador',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Color(0xFF1E3A5F)),
                      validator: (v) {
                        final email = v?.trim() ?? '';
                        final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
                        return ok ? null : 'Correo inválido';
                      },
                      decoration: _inputDecoration(
                        hint: 'correo@ejemplo.com',
                        icon: Icons.email_outlined,
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Relación con el usuario',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _relacionCtrl,
                      style: const TextStyle(color: Color(0xFF1E3A5F)),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
                      decoration: _inputDecoration(
                        hint: 'Ej. Madre, Hijo, Enfermero...',
                        icon: Icons.people_outline,
                      ),
                    ),
                    const SizedBox(height: 20),

                    SwitchListTile(
                      title: const Text(
                        'Notificar al cuidador cuando se genere un recordatorio',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      activeColor: Colors.greenAccent,
                      value: _notificar,
                      onChanged: (v) => setState(() => _notificar = v),
                    ),
                    const SizedBox(height: 30),

                    // Botón guardar
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4A90E2).withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _saveCuidador,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                        ),
                        child: const Text(
                          'Guardar Información',
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
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
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
    );
  }
}
