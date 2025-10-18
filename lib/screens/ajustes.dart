import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_wrapper.dart';
import 'asignar_cuidador.dart';
import 'perfil_usuario.dart';
import 'welcome.dart';
import 'historial.dart';

class AjustesScreen extends StatefulWidget {
  const AjustesScreen({Key? key}) : super(key: key);

  @override
  State<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends State<AjustesScreen> {
  int _selectedIndex = 3; // Ajustes es el índice 3
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  String _notificationTime = '5 minutos antes';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _soundEnabled = prefs.getBool('sound_enabled') ?? true;
        _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
        _notificationTime = prefs.getString('notification_time') ?? '5 minutos antes';
      });
    } catch (e) {
      print('Error cargando configuraciones: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', _notificationsEnabled);
      await prefs.setBool('sound_enabled', _soundEnabled);
      await prefs.setBool('vibration_enabled', _vibrationEnabled);
      await prefs.setString('notification_time', _notificationTime);
    } catch (e) {
      print('Error guardando configuraciones: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        automaticallyImplyLeading: false,
        title: const Text(
          'Ajustes',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Notificaciones'),
            _buildSettingCard(
              'Activar notificaciones',
              'Recibir alertas de recordatorios',
              Icons.notifications_active,
              Colors.blue,
                Switch(
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                  _saveSettings();
                },
                activeColor: Color(0xFF4A90E2),
              ),
            ),
            if (_notificationsEnabled) ...[
              _buildSettingCard(
                'Sonido',
                'Reproducir sonido en notificaciones',
                Icons.volume_up,
                Colors.orange,
                  Switch(
                  value: _soundEnabled,
                  onChanged: (value) {
                    setState(() {
                      _soundEnabled = value;
                    });
                    _saveSettings();
                  },
                  activeColor: Color(0xFF4A90E2),
                ),
              ),
              _buildSettingCard(
                'Vibración',
                'Vibrar al recibir notificaciones',
                Icons.vibration,
                Colors.purple,
                  Switch(
                  value: _vibrationEnabled,
                  onChanged: (value) {
                    setState(() {
                      _vibrationEnabled = value;
                    });
                    _saveSettings();
                  },
                  activeColor: Color(0xFF4A90E2),
                ),
              ),
              _buildDropdownCard(
                'Tiempo de anticipación',
                'Recibir notificación antes del recordatorio',
                Icons.access_time,
                Colors.green,
                _notificationTime,
                ['5 minutos antes', '10 minutos antes', '15 minutos antes', '30 minutos antes', '1 hora antes'],
                (value) {
                  setState(() {
                    _notificationTime = value!;
                  });
                  _saveSettings();
                },
              ),
            ],
            _buildSectionHeader('Cuenta y Perfil'),
            _buildNavigationCard(
              'Perfil de usuario',
              'Ver y editar información personal',
              Icons.person,
              Colors.blue,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PerfilUsuarioScreen()),
                );
              },
            ),
            _buildNavigationCard(
              'Asignar cuidador',
              'Configurar pariente o cuidador',
              Icons.people,
              Colors.teal,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AsignarCuidadorScreen()),
                );
              },
            ),
            _buildSectionHeader('Preferencias'),
            _buildNavigationCard(
              'Idioma',
              'Español',
              Icons.language,
              Colors.indigo,
              () {
                _showLanguageDialog(context);
              },
            ),
            _buildNavigationCard(
              'Tema',
              'Claro',
              Icons.palette,
              Colors.pink,
              () {
                _showThemeDialog(context);
              },
            ),
            _buildSectionHeader('Acerca de'),
            _buildNavigationCard(
              'Ayuda y soporte',
              'Centro de ayuda y preguntas frecuentes',
              Icons.help_outline,
              Colors.orange,
              () {
                _showHelpDialog(context);
              },
            ),
            _buildNavigationCard(
              'Términos y condiciones',
              'Leer términos de uso',
              Icons.description,
              Colors.blueGrey,
              () {
                _showTermsDialog(context);
              },
            ),
            _buildNavigationCard(
              'Política de privacidad',
              'Cómo manejamos tus datos',
              Icons.privacy_tip,
              Colors.cyan,
              () {
                _showPrivacyDialog(context);
              },
            ),
            _buildNavigationCard(
              'Acerca de la app',
              'Versión 1.0.0',
              Icons.info_outline,
              Colors.purple,
              () {
                _showAboutDialog(context);
              },
            ),
            _buildSectionHeader('Sesión'),
            _buildNavigationCard(
              'Cerrar sesión',
              'Salir de tu cuenta',
              Icons.logout,
              Colors.red,
              () {
                _showLogoutDialog(context);
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF4A90E2),
        unselectedItemColor: Colors.grey,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Cuidadores',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historial',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    Widget trailing,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
          trailing,
        ],
      ),
    );
  }

  Widget _buildDropdownCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    String value,
    List<String> options,
    Function(String?) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: value,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: options.map((option) {
                    return DropdownMenuItem(
                      value: option,
                      child: Text(option, style: TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Seleccionar Idioma'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile(
              title: Text('Español'),
              value: 'es',
              groupValue: 'es',
              onChanged: (value) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Idioma: Español')),
                );
              },
            ),
            RadioListTile(
              title: Text('English'),
              value: 'en',
              groupValue: 'es',
              onChanged: (value) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Language: English')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Seleccionar Tema'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile(
              title: Text('Claro'),
              value: 'light',
              groupValue: 'light',
              onChanged: (value) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Tema: Claro')),
                );
              },
            ),
            RadioListTile(
              title: Text('Oscuro'),
              value: 'dark',
              groupValue: 'light',
              onChanged: (value) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Tema: Oscuro')),
                );
              },
            ),
            RadioListTile(
              title: Text('Sistema'),
              value: 'system',
              groupValue: 'light',
              onChanged: (value) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Tema: Sistema')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.help_outline, color: Color(0xFF4A90E2)),
            SizedBox(width: 12),
            Text('Centro de Ayuda'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Preguntas Frecuentes:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text('• ¿Cómo agregar un recordatorio?'),
              Text('• ¿Cómo editar un recordatorio?'),
              Text('• ¿Cómo asignar un cuidador?'),
              Text('• ¿Cómo activar notificaciones?'),
              SizedBox(height: 16),
              Text(
                'Para más ayuda, contáctanos a: soporte@recordatorios.com',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Términos y Condiciones'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. Uso de la aplicación',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Esta aplicación está diseñada para ayudarte a recordar tus medicamentos y actividades de salud. No sustituye el consejo médico profesional.',
              ),
              SizedBox(height: 16),
              Text(
                '2. Responsabilidad',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'El usuario es responsable de verificar la información ingresada y seguir las indicaciones de su médico.',
              ),
              SizedBox(height: 16),
              Text(
                '3. Actualizaciones',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Nos reservamos el derecho de actualizar estos términos en cualquier momento.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Política de Privacidad'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recopilación de datos',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Recopilamos información necesaria para proporcionar nuestros servicios, incluyendo recordatorios de medicamentos y datos de salud.',
              ),
              SizedBox(height: 16),
              Text(
                'Uso de datos',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Tus datos se utilizan únicamente para mejorar tu experiencia y enviar notificaciones de recordatorios.',
              ),
              SizedBox(height: 16),
              Text(
                'Seguridad',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Implementamos medidas de seguridad para proteger tu información personal.',
              ),
              SizedBox(height: 16),
              Text(
                'Tus derechos',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Puedes solicitar acceso, corrección o eliminación de tus datos en cualquier momento.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.health_and_safety, color: Color(0xFF4A90E2)),
            SizedBox(width: 12),
            Text('Recordatorios de Salud'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Versión: 1.0.0',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Una aplicación diseñada para ayudarte a recordar tus medicamentos y actividades de salud de manera simple y efectiva.',
            ),
            SizedBox(height: 16),
            Text(
              'Características:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Recordatorios personalizables'),
            Text('• Notificaciones inteligentes'),
            Text('• Gestión de cuidadores'),
            Text('• Historial completo'),
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 8),
            Text(
              '© 2025 Todos los derechos reservados',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              'Desarrollado con ❤️ en Flutter',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cerrar Sesión'),
        content: Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Cerrar el diálogo
              try {
                await FirebaseAuth.instance.signOut();
                // Navegar a AuthWrapper limpiando toda la pila de navegación
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthWrapper()),
                  (route) => false,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Sesión cerrada exitosamente'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al cerrar sesión'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Cerrar Sesión', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AsignarCuidadorScreen()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HistorialScreen()),
        );
        break;
      case 3:
        // Ya estamos en Ajustes
        break;
    }
  }
}
