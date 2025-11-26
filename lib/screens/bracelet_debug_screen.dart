// ========================================
// ARCHIVO: lib/screens/bracelet_debug_screen.dart
// ========================================
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/bracelet_device.dart';
import '../services/bracelet_service.dart';
import '../services/background_ble_service_simple.dart';
import '../services/bracelet_storage_service.dart';

class BraceletDebugScreen extends StatefulWidget {
  const BraceletDebugScreen({Key? key}) : super(key: key);

  @override
  State<BraceletDebugScreen> createState() => _BraceletDebugScreenState();
}

class _BraceletDebugScreenState extends State<BraceletDebugScreen> {
  final BraceletService _braceletService = BraceletService();
  final List<BraceletResponse> _responseLog = [];
  StreamSubscription<BraceletResponse>? _responseSubscription;
  bool _isTestingLed = false;
  bool _isBackgroundServiceRunning = false;
  Map<String, dynamic> _reconnectionStats = {};

  @override
  void initState() {
    super.initState();
    _setupResponseListener();
    _checkBackgroundServiceStatus();
    _loadReconnectionStats();
  }

  void _setupResponseListener() {
    _responseSubscription = _braceletService.responseStream.listen((response) {
      if (mounted) {
        setState(() {
          _responseLog.insert(0, response);
          // Mantener solo los últimos 20 mensajes
          if (_responseLog.length > 20) {
            _responseLog.removeRange(20, _responseLog.length);
          }
        });
      }
    });
  }

  Future<void> _sendCommand(String command) async {
    try {
      await _braceletService.sendCommand(command);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error enviando comando: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _simulateReminderAlert() async {
    try {
      await _braceletService.simulateAlert();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alerta de prueba enviada'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error enviando alerta: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _syncReminders() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sincronizando recordatorios...'),
          backgroundColor: Colors.blue,
        ),
      );
      
      await _braceletService.syncRemindersToBracelet();
      
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Recordatorios sincronizados con éxito!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al sincronizar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _checkBackgroundServiceStatus() async {
    try {
      final isRunning = await BackgroundBleService.isServiceRunning();
      if (mounted) {
        setState(() {
          _isBackgroundServiceRunning = isRunning;
        });
      }
    } catch (e) {
      print('Error verificando estado del servicio: $e');
    }
  }
  
  Future<void> _toggleBackgroundService(bool enable) async {
    try {
      if (enable) {
        await BackgroundBleService.startService();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Servicio en segundo plano iniciado'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await BackgroundBleService.stopService();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Servicio en segundo plano detenido'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      
      await _checkBackgroundServiceStatus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error con servicio en segundo plano: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _loadReconnectionStats() async {
    try {
      final stats = await BraceletStorageService.getStorageStats();
      if (mounted) {
        setState(() {
          _reconnectionStats = stats;
        });
      }
    } catch (e) {
      print('Error cargando estadísticas de reconexión: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.grey[800], // Darker for debug
        elevation: 0,
        title: Text(
          'Debug Manilla',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: AnimatedBuilder(
        animation: _braceletService,
        builder: (context, child) {
          final device = _braceletService.connectedDevice;
          
          if (device == null) {
            return _buildDisconnectedState();
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Estado de conexión
                _buildConnectionCard(device),
                
                SizedBox(height: 20),
                
                // Controles principales
                _buildControlSection(),
                
                SizedBox(height: 20),
                
                // Log de respuestas
                _buildResponseLogSection(),
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
              Icons.bug_report,
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 24),
            Text(
              'Modo Debug',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'No hay manilla conectada para depurar',
              style: TextStyle(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard(BraceletDevice device) {
    final isConnected = device.connectionStatus == BraceletConnectionStatus.connected;
    
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
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isConnected 
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isConnected ? Icons.developer_board : Icons.developer_board_off,
                  color: isConnected ? Colors.green : Colors.red,
                  size: 32,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'MAC: ${device.macAddress}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (device.lastConnected != null) ...[
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 12),
            Text(
              'Última conexión: ${_formatDateTime(device.lastConnected!)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Controles de Debug',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A5F),
          ),
        ),
        SizedBox(height: 16),
        
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _simulateReminderAlert,
            icon: Icon(Icons.notifications_active),
            label: Text('Simular Alerta'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ),

        SizedBox(height: 12),
        
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _sendCommand('READ 2'),
            icon: Icon(Icons.touch_app),
            label: Text('Leer Estado GPIO2'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey,
              foregroundColor: Colors.white,
            ),
          ),
        ),

        SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _braceletService.isSyncing ? null : _syncReminders,
            icon: _braceletService.isSyncing 
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white,))
                : Icon(Icons.sync),
            label: Text('Forzar Sincronización'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        
        SizedBox(height: 20),
        
        // Toggle para servicio en segundo plano
        SwitchListTile(
          title: Text('Servicio Background'),
          subtitle: Text(_isBackgroundServiceRunning ? 'Activo' : 'Inactivo'),
          value: _isBackgroundServiceRunning,
          onChanged: _toggleBackgroundService,
          secondary: Icon(Icons.settings_remote),
        ),
      ],
    );
  }

  Widget _buildResponseLogSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Log de Respuestas',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _responseLog.clear();
                });
              },
              child: Text('Limpiar'),
            ),
          ],
        ),
        SizedBox(height: 12),
        
        Container(
          height: 300,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: _responseLog.isEmpty
              ? Center(
                  child: Text(
                    'Esperando datos...',
                    style: TextStyle(color: Colors.green[900]),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(12),
                  itemCount: _responseLog.length,
                  itemBuilder: (context, index) {
                    final response = _responseLog[index];
                    return Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        '[${_formatTime(response.timestamp)}] ${response.response}',
                        style: TextStyle(
                          fontFamily: 'monospace', 
                          fontSize: 11,
                          color: response.isSuccess ? Colors.green : Colors.red,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${_formatTime(dateTime)}';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _responseSubscription?.cancel();
    super.dispose();
  }
}
