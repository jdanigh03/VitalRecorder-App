import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';           // generado por flutterfire configure
import 'splash_screen.dart';              // tu pantalla de splash (animación / logo)
import 'login_screen.dart';               // tu login actual
import 'register_screen.dart';            // el register que hicimos
// import 'home_screen.dart';             // tu pantalla principal autenticada

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vital Recorder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // Mientras carga el splash, montamos el AuthGate detrás
      home: const SplashWrapper(),

      // Rutas útiles para navegación pushNamed si quieres
      routes: {
        '/login': (_) => LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        // '/home': (_) => const HomeScreen(),
      },
    );
  }
}

/// Muestra tu SplashScreen unos instantes y luego entra al AuthGate.
/// Si tu Splash ya hace un delay/animación y luego navega, puedes
/// saltarte este wrapper y poner `home: const AuthGate()`.
class SplashWrapper extends StatefulWidget {
  const SplashWrapper({super.key});

  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper> {
  bool _showAuth = false;

  @override
  void initState() {
    super.initState();
    // Simula duración de splash; si tu SplashScreen ya navega por su cuenta, quítalo
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showAuth = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_showAuth) return SplashScreen(); // tu widget de splash
    return const AuthGate();
  }
}

/// Envía al Home si está logueado, si no al Login.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        // Cargando estado de auth
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Usuario autenticado
        if (snap.hasData) {
          // return const HomeScreen(); // tu pantalla para usuarios logueados
          return const _HomePlaceholder();
        }

        // No autenticado -> Login
        return LoginScreen();
      },
    );
  }
}

/// Placeholder temporal para el Home (borra cuando tengas tu Home real)
class _HomePlaceholder extends StatelessWidget {
  const _HomePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
          },
          child: const Text('Cerrar sesión'),
        ),
      ),
    );
  }
}
