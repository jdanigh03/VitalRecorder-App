import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';
import 'welcome.dart';
import 'cuidador_dashboard.dart';
import 'login_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_recorder_app/background_polling_service.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Mostrar loading mientras se determina el estado de autenticación
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        // Si no hay usuario autenticado, mostrar login
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        // Si hay usuario autenticado, determinar la pantalla según el rol
        return RoleBasedNavigation(user: snapshot.data!);
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E3A5F), Color(0xFF2D5082), Color(0xFF4A90E2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(height: 20),
              Text(
                'Verificando usuario...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoleBasedNavigation extends StatefulWidget {
  final User user;

  const RoleBasedNavigation({Key? key, required this.user}) : super(key: key);

  @override
  State<RoleBasedNavigation> createState() => _RoleBasedNavigationState();
}

class _RoleBasedNavigationState extends State<RoleBasedNavigation> {
  final UserService _userService = UserService();
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _determineUserRole();
  }

  Future<void> _determineUserRole() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      // Intentar obtener el rol del usuario
      final userRole = await _userService.getUserRole();
      
      print('=== ROL DE USUARIO DETECTADO ===');
      print('UID: ${widget.user.uid}');
      print('Email: ${widget.user.email}');
      print('Rol: $userRole');

      // Guardar UID en SharedPreferences para Workmanager
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user_id', widget.user.uid);
        
        // Registrar tarea en segundo plano (Agresiva)
        await BackgroundPollingService.startAggressivePolling();
      } catch (e) {
        print('Error configurando servicio de fondo: $e');
      }

      setState(() => _isLoading = false);

      // Navegar según el rol
      if (mounted) {
        _navigateBasedOnRole(userRole);
      }
    } catch (e) {
      print('Error determinando rol del usuario: $e');
      setState(() {
        _isLoading = false;
        _error = 'Error al verificar el usuario';
      });
    }
  }

  void _navigateBasedOnRole(String role) {
    Widget destinationScreen;

    switch (role.toLowerCase()) {
      case 'cuidador':
        destinationScreen = CuidadorDashboard();
        break;
      case 'user':
      case 'patient':
      default:
        destinationScreen = const WelcomeScreen();
        break;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destinationScreen),
    );
  }

  void _retry() {
    _determineUserRole();
  }

  @override
  Widget build(BuildContext context) {
    if (_error.isNotEmpty) {
      return _buildErrorScreen();
    }

    if (_isLoading) {
      return _buildLoadingScreen();
    }

    // This should not be reached as navigation happens in _navigateBasedOnRole
    return const WelcomeScreen();
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E3A5F), Color(0xFF2D5082), Color(0xFF4A90E2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(height: 20),
              Text(
                'Configurando aplicación...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E3A5F), Color(0xFF2D5082), Color(0xFF4A90E2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 60,
                ),
                const SizedBox(height: 20),
                Text(
                  _error,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _retry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E3A5F),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  child: const Text(
                    'Reintentar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  child: const Text(
                    'Cerrar sesión',
                    style: TextStyle(
                      color: Colors.white70,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
