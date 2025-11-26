// ========================================
// ARCHIVO: lib/screens/bracelet_control_screen.dart
// ========================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bracelet_device.dart';
import '../services/bracelet_service.dart';
import 'bracelet_debug_screen.dart';

class BraceletControlScreen extends StatefulWidget {
  const BraceletControlScreen({Key? key}) : super(key: key);

  @override
  State<BraceletControlScreen> createState() => _BraceletControlScreenState();
}

class _BraceletControlScreenState extends State<BraceletControlScreen> {
  final BraceletService _braceletService = BraceletService();
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _lastSyncTime = DateTime.now(); // Asumimos que se sincronizó al conectar o recientemente
  }

  Future<void> _syncReminders() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 16),
              Text('Sincronizando recordatorios...'),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 10), // Duración larga, se quitará al terminar
        ),
      );
      
      await _braceletService.syncRemindersToBracelet();
      
      if (mounted) {
        setState(() {
          _lastSyncTime = DateTime.now();
        });
        
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('¡Sincronización completada!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al sincronizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        elevation: 0,
        title: Text(
          'Mi Manilla',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Botón oculto/discreto para debug
          IconButton(
            icon: Icon(Icons.build_circle_outlined, color: Colors.white.withOpacity(0.5)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => BraceletDebugScreen()),
              );
            },
            tooltip: 'Opciones avanzadas',
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _braceletService,
        builder: (context, child) {
          final device = _braceletService.connectedDevice;
          
          if (device == null) {
            return _buildDisconnectedState();
          }

          final isConnected = device.connectionStatus == BraceletConnectionStatus.connected;

          return SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Imagen de manilla (icono grande por ahora)
                Container(
                  padding: EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.watch,
                    size: 80,
                    color: isConnected ? Color(0xFF4A90E2) : Colors.grey,
                  ),
                ),
                
                SizedBox(height: 24),
                
                Text(
                  device.name,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
                
                SizedBox(height: 8),
                
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isConnected ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isConnected ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        isConnected ? 'Conectado' : 'Desconectado',
                        style: TextStyle(
                          color: isConnected ? Colors.green[700] : Colors.red[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 40),

                // Tarjeta de Sincronización
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Sincronización',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _lastSyncTime != null 
                            ? 'Última vez: ${DateFormat('HH:mm a').format(_lastSyncTime!)}'
                            : 'No sincronizado recientemente',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: (isConnected && !_braceletService.isSyncing) 
                              ? _syncReminders 
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF4A90E2),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            disabledBackgroundColor: Colors.grey[300],
                          ),
                          child: _braceletService.isSyncing
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.sync),
                                    SizedBox(width: 12),
                                    Text(
                                      'Sincronizar Ahora',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // Información útil
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFF4A90E2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF4A90E2)),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Mantén la manilla cerca de tu teléfono para asegurar que recibas todas las notificaciones.',
                          style: TextStyle(
                            color: Color(0xFF1E3A5F),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDisconnectedState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.watch_off,
              size: 80,
              color: Colors.grey[300],
            ),
            SizedBox(height: 24),
            Text(
              'Manilla no conectada',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Conecta tu manilla para sincronizar tus recordatorios y recibir alertas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacementNamed('/bracelet-setup');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Ir a Configuración'),
            ),
          ],
        ),
      ),
    );
  }
}
