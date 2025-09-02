import 'package:flutter/material.dart';
import 'login_screen.dart'; // importa tu pantalla de login

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _didNavigate = false;

  void _goToLogin() {
    if (_didNavigate) return;
    _didNavigate = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => LoginScreen(),
        transitionsBuilder: (_, animation, __, child) {
          // Transición sutil tipo fade + slide
          final offsetAnim = Tween<Offset>(
            begin: const Offset(0.1, 0), // leve desliz desde la derecha
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offsetAnim, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const swipeThreshold = 18.0; // píxeles mínimos para considerar “deslizar”
    return Scaffold(
      body: GestureDetector(
        onPanUpdate: (details) {
          // Deslizar a la izquierda
          if (details.delta.dx < -swipeThreshold) _goToLogin();
          // Deslizar hacia arriba
          if (details.delta.dy < -swipeThreshold) _goToLogin();
        },
        child: Stack(
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

            // Contenido centrado
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // Logo con efecto de resplandor
                  ShaderMask(
                    shaderCallback: (bounds) => const RadialGradient(
                      center: Alignment.center,
                      radius: 0.8,
                      colors: [Colors.white, Colors.transparent],
                      stops: [0.5, 1.0],
                    ).createShader(bounds),
                    child: Image.asset(
                      'assets/vital_recorder_nobg.png',
                      width: 200.0,
                      color: const Color(0xFF0D47A1),
                      colorBlendMode: BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Texto principal
                  const Text(
                    'VITAL\nRECORDER',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Texto secundario
                  const Text(
                    'Hecho Por VisualSystems',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Pista visual opcional
                  const Text(
                    'Desliza para continuar',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Botón de regreso (por si hay historial)
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
