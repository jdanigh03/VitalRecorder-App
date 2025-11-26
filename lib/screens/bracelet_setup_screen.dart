// ========================================
// ARCHIVO: lib/screens/bracelet_setup_screen.dart
// ========================================
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import '../models/bracelet_device.dart';
import '../services/bracelet_service.dart';
import '../services/notification_service.dart';

class BraceletSetupScreen extends StatefulWidget {
  const BraceletSetupScreen({Key? key}) : super(key: key);

  @override
  State<BraceletSetupScreen> createState() => _BraceletSetupScreenState();
}

class _BraceletSetupScreenState extends State<BraceletSetupScreen> {
  final BraceletService _braceletService = BraceletService();
  final NotificationService _notificationService = NotificationService();
  StreamSubscription<BraceletConnectionStatus>? _connectionSubscription;
  
  bool _isInitialized = false;
  bool _isConnecting = false;
  String? _connectionError;

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
    _setupConnectionListener();
  }

  void _setupConnectionListener() {
    _connectionSubscription = _braceletService.connectionStatusStream.listen((status) {
      if (status == BraceletConnectionStatus.disconnected) {
        _notificationService.showBraceletDisconnectedNotification();
      }
    });
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeBluetooth() async {
    try {
      final success = await _braceletService.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = success;
          if (!success) {
            _connectionError = "No se pudo inicializar Bluetooth. Verifique que esté activado.";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _connectionError = "Error inicializando Bluetooth: $e";
        });
      }
    }
  }

  Future<void> _startScan() async {
    if (!_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bluetooth no está disponible'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _connectionError = null;
    });

    try {
      await _braceletService.startScan(timeout: Duration(seconds: 15));
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionError = "Error durante el escaneo: $e";
        });
      }
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _isConnecting = true;
      _connectionError = null;
    });

    try {
      final success = await _braceletService.connectToDevice(device);
      
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('¡Conectado exitosamente!'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navegar a la pantalla de control después de conexión exitosa
          Navigator.of(context).pushReplacementNamed('/bracelet-control');
        } else {
          setState(() {
            _connectionError = "No se pudo conectar a la manilla";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectionError = "Error conectando: $e";
        });
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
          'Configurar Manilla',
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
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header informativo
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF4A90E2),
                    Color(0xFF357ABD),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.watch, color: Colors.white, size: 32),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Manilla de Recordatorios',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Conecte su manilla ESP32-C3 "Vital Recorder" para recibir notificaciones LED de sus recordatorios.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Estado del Bluetooth
            if (!_isInitialized) ...[
              _buildErrorCard(
                'Bluetooth No Disponible',
                _connectionError ?? 'Verifique que el Bluetooth esté activado',
                Icons.bluetooth_disabled,
                () => _initializeBluetooth(),
              ),
            ] else ...[
              
              // Botón de escaneo
              Container(
                width: double.infinity,
                child: AnimatedBuilder(
                  animation: _braceletService,
                  builder: (context, child) {
                    return ElevatedButton.icon(
                      onPressed: _braceletService.isScanning ? null : _startScan,
                      icon: _braceletService.isScanning
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Icons.search),
                  label: Text(
                    _braceletService.isScanning 
                        ? 'Buscando manillas...' 
                        : 'Buscar Manilla',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF4A90E2),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
              ),
              ),

              SizedBox(height: 20),

              // Lista de dispositivos encontrados
              AnimatedBuilder(
                animation: _braceletService,
                builder: (context, child) {
                  final devices = _braceletService.discoveredDevices;
                  
                  if (devices.isEmpty && !_braceletService.isScanning) {
                    return _buildInfoCard(
                      'No se encontraron manillas',
                      'Asegúrese de que su manilla ESP32-C3 esté encendida y cerca del dispositivo.',
                      Icons.info_outline,
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (devices.isNotEmpty) ...[
                        Text(
                          'Manillas Encontradas',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A5F),
                          ),
                        ),
                        SizedBox(height: 12),
                      ],
                      
                      ...devices.map((device) => _buildDeviceCard(device)),
                    ],
                  );
                },
              ),

              // Error de conexión
              if (_connectionError != null) ...[
                SizedBox(height: 16),
                _buildErrorCard(
                  'Error de Conexión',
                  _connectionError!,
                  Icons.error,
                  () => setState(() => _connectionError = null),
                ),
              ],

              // Instrucciones
              SizedBox(height: 32),
              _buildInstructionsCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(BluetoothDevice device) {
    final deviceName = device.platformName.isNotEmpty 
        ? device.platformName 
        : 'Vital Recorder';
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color(0xFF4A90E2).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.watch,
            color: Color(0xFF4A90E2),
            size: 24,
          ),
        ),
        title: Text(
          deviceName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A5F),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              'ID: ${device.remoteId}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Compatible',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: _isConnecting 
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : ElevatedButton(
                onPressed: () => _connectToDevice(device),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('Conectar'),
              ),
      ),
    );
  }

  Widget _buildErrorCard(String title, String message, IconData icon, VoidCallback onRetry) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.red, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.red[600]),
          ),
          SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: Icon(Icons.refresh),
            label: Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String message, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(color: Colors.blue[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, color: Colors.grey[600]),
              SizedBox(width: 8),
              Text(
                'Instrucciones',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            '1. Asegúrese de que su manilla ESP32-C3 esté encendida\n'
            '2. Mantenga la manilla cerca del teléfono (menos de 5 metros)\n'
            '3. Presione "Buscar Manilla" para iniciar el escaneo\n'
            '4. Seleccione su dispositivo "Vital Recorder" y presione "Conectar"',
            style: TextStyle(
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
