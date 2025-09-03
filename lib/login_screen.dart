import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Para usar Firebase Auth
import 'welcome_page.dart'; // Importa la página de bienvenida
import 'register_screen.dart'; 

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Iniciar sesión con Firebase Auth
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      // Si se autentica, navega a la página de bienvenida
      Navigator.pop(context); // Cierra el loader

      // Verifica si el usuario se autenticó correctamente antes de redirigir
      if (userCredential.user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WelcomePage()), // Navega a la página de bienvenida
        );
      } else {
        // Si no se autentica, muestra un mensaje
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo iniciar sesión')));
      }
    } on FirebaseAuthException catch (e) {
      Navigator.pop(context); // Cierra el loader
      String msg = 'Error al iniciar sesión';
      if (e.code == 'invalid-email') msg = 'Correo inválido';
      if (e.code == 'user-not-found') msg = 'Usuario no encontrado';
      if (e.code == 'wrong-password') msg = 'Contraseña incorrecta';
      if (e.code == 'user-disabled') msg = 'Usuario deshabilitado';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      Navigator.pop(context); // Cierra el loader
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
          // FONDO GRADIENTE
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: 80.0),

                    const Text(
                      'Iniciar Sesión',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 36.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 1.0),

                    // OPCIÓN PARA REGISTRARSE
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '¿Aún no tienes cuenta?',
                          style: TextStyle(color: Colors.white),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const RegisterScreen()),
                            );
                          },
                          child: const Text(
                            'Regístrarse',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // E-mail
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('E-mail: *', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                    const SizedBox(height: 4.0),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'tucorreo@gmail.com',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                      ),
                    ),
                    const SizedBox(height: 15.0),

                    // Contraseña
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Contraseña: *', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                    const SizedBox(height: 4.0),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        hintText: '••••••••••••',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8.0),

                    // BOTÓN INICIAR SESIÓN
                    ElevatedButton(
                      onPressed: _signIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                      ),
                      child: const Text(
                        'Iniciar Sesión',
                        style: TextStyle(fontSize: 18.0, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 20.0), 

                   /* // SEPARADOR PARA INICIO DE SESIÓN SOCIAL
                    const Text(
                      'O conéctate con:',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 20.0), 

                    // BOTONES DE GOOGLE Y FACEBOOK
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
                  ],
                ),
              ),
            ),
          ),
          // BOTÓN DE REGRESO
          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// WIDGET REUTILIZABLE PARA LOS BOTONES SOCIALES
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
