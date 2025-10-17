// ========================================
// ARCHIVO: lib/screens/bracelet_control_screen.dart
// ========================================
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/bracelet_device.dart';
import '../services/bracelet_service.dart';
import '../services/background_ble_service_simple.dart';

class BraceletControlScreen extends StatefulWidget {
  const BraceletControlScreen({Key? key}) : super(key: key);

  @override
  State<BraceletControlScreen> createState() => _BraceletControlScreenState();
}

class _BraceletControlScreenState extends State<BraceletControlScreen> {
  final BraceletService _braceletService = BraceletService();
  final List<BraceletResponse> _responseLog = [];
  StreamSubscription<BraceletResponse>? _responseSubscription;
  bool _isTestingLed = false;
  bool _isBackgroundServiceRunning = false;

  @override
  void initState() {
    super.initState();
    _setupResponseListener();
    _checkBackgroundServiceStatus();
  }

  void _setupResponseListener() {
    _responseSubscription = _braceletService.responseStream.listen((response) {
      setState(() {
        _responseLog.insert(0, response);
        // Mantener solo los últimos 20 mensajes
        if (_responseLog.length > 20) {
          _responseLog.removeRange(20, _responseLog.length);
        }
      });
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
      setState(() {
        _isBackgroundServiceRunning = isRunning;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        elevation: 0,
        title: Text(
          'Control de Manilla',
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
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              // Navegar a configuración avanzada
            },
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
              Icons.bluetooth_disabled,
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 24),
            Text(
              'Manilla Desconectada',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'No hay ninguna manilla conectada en este momento',
              style: TextStyle(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushReplacementNamed('/bracelet-setup');
              },
              icon: Icon(Icons.add),
              label: Text('Configurar Manilla'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
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
                  isConnected ? Icons.watch : Icons.watch_off,
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
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isConnected 
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isConnected ? 'Conectado' : 'Desconectado',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isConnected ? Colors.green[700] : Colors.red[700],
                  ),
                ),
              ),
            ],
          ),
          
          if (device.lastConnected != null) ...[
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Text(
                  'Última conexión: ${_formatDateTime(device.lastConnected!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
          
          // Estado del recordatorio activo
          if (_braceletService.hasActiveReminder) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.alarm, size: 16, color: Colors.orange[700]),
                      SizedBox(width: 8),
                      Text(
                        'Recordatorio Activo:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    _braceletService.activeReminderTitle ?? 'Sin título',
                    style: TextStyle(color: Colors.orange[800]),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.touch_app, size: 14, color: Colors.grey[600]),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                        'Presiona el botón GPIO2 en la manilla para confirmar',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
          'Controles',
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
              backgroundColor: Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        SizedBox(height: 12),
        
        // Botón de test para botón físico
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _sendCommand('READ 2'),
            icon: Icon(Icons.touch_app),
            label: Text('Leer Estado Botón (GPIO2)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF28A745),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        SizedBox(height: 20),

        // Botón de Sincronización
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _braceletService.isSyncing ? null : _syncReminders,
            icon: _braceletService.isSyncing 
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white,))
                : Icon(Icons.sync),
            label: Text(_braceletService.isSyncing ? 'Sincronizando...' : 'Sincronizar Recordatorios'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF007BFF),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        
        SizedBox(height: 20),
        
        // Toggle para servicio en segundo plano
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isBackgroundServiceRunning ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isBackgroundServiceRunning ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _isBackgroundServiceRunning ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: _isBackgroundServiceRunning ? Colors.green[700] : Colors.grey[600],
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Servicio en Segundo Plano',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A5F),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _isBackgroundServiceRunning 
                              ? 'Activo - Escucha confirmaciones siempre'
                              : 'Inactivo - Solo escucha con app abierta',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isBackgroundServiceRunning,
                    onChanged: _toggleBackgroundService,
                    activeColor: Colors.green,
                  ),
                ],
              ),
              if (_isBackgroundServiceRunning) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.green[700]),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Perfecto para personas mayores - funciona con teléfono en el bolsillo',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
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
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: _responseLog.isEmpty
              ? Center(
                  child: Text(
                    'No hay mensajes aún...',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(12),
                  itemCount: _responseLog.length,
                  itemBuilder: (context, index) {
                    final response = _responseLog[index];
                    return Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                          children: [
                            TextSpan(
                              text: '[${_formatTime(response.timestamp)}] ',
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                            TextSpan(
                              text: response.response,
                              style: TextStyle(
                                color: response.isSuccess ? Colors.green[300] : Colors.red[300],
                              ),
                            ),
                          ],
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
