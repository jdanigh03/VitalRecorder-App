// ========================================
// ARCHIVO: lib/screens/bracelet_control_screen.dart
// ========================================
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/bracelet_device.dart';
import '../services/bracelet_service.dart';

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

  @override
  void initState() {
    super.initState();
    _setupResponseListener();
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

  Future<void> _testLedSequence() async {
    setState(() {
      _isTestingLed = true;
    });

    try {
      // Secuencia de prueba: ON -> esperar -> OFF -> esperar -> ON
      await _braceletService.turnLedOn();
      await Future.delayed(Duration(seconds: 1));
      await _braceletService.turnLedOff();
      await Future.delayed(Duration(seconds: 1));
      await _braceletService.turnLedOn();
      await Future.delayed(Duration(seconds: 1));
      await _braceletService.turnLedOff();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Prueba de LED completada!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error en prueba de LED: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isTestingLed = false;
      });
    }
  }

  Future<void> _simulateReminderAlert() async {
    try {
      final notification = BraceletNotification(
        type: BraceletNotificationType.medicationTime,
        title: 'Prueba de Recordatorio',
        message: 'Simulación de notificación',
        scheduledTime: DateTime.now(),
      );
      
      await _braceletService.sendReminderNotification(notification);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notificación de prueba enviada'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error enviando notificación: $e'),
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
          
          // Estado del LED
          SizedBox(height: 16),
          Row(
            children: [
              Icon(
                device.isLedOn ? Icons.lightbulb : Icons.lightbulb_outline,
                color: device.isLedOn ? Colors.amber : Colors.grey,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'LED: ${device.isLedOn ? "Encendido" : "Apagado"}',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ],
          ),
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
        
        // Grid de controles
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            _buildControlButton(
              'LED ON',
              Icons.lightbulb,
              Colors.amber,
              () => _braceletService.turnLedOn(),
            ),
            _buildControlButton(
              'LED OFF',
              Icons.lightbulb_outline,
              Colors.grey,
              () => _braceletService.turnLedOff(),
            ),
            _buildControlButton(
              'Estado',
              Icons.info,
              Colors.blue,
              () => _sendCommand(BraceletCommand.status),
            ),
            _buildControlButton(
              'Ayuda',
              Icons.help,
              Colors.purple,
              () => _sendCommand(BraceletCommand.help),
            ),
          ],
        ),
        
        SizedBox(height: 20),
        
        // Botones de prueba
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isTestingLed ? null : _testLedSequence,
                icon: _isTestingLed 
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.flash_on),
                label: Text(_isTestingLed ? 'Probando...' : 'Probar LED'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _simulateReminderAlert,
                icon: Icon(Icons.notifications_active),
                label: Text('Simular Alerta'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControlButton(String title, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
        elevation: 0,
        padding: EdgeInsets.all(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
