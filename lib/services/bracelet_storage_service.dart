import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bracelet_device.dart';

/// Servicio para almacenar información de la manilla localmente
/// Permite recordar la última manilla conectada y reconectar automáticamente
class BraceletStorageService {
  static const String _keyLastBracelet = 'last_connected_bracelet';
  static const String _keyAutoReconnect = 'auto_reconnect_enabled';
  static const String _keyReconnectAttempts = 'reconnect_attempts';
  
  /// Guardar información de la última manilla conectada
  static Future<void> saveLastConnectedBracelet(BraceletDevice device) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Crear mapa con información esencial
      final deviceData = {
        'name': device.name,
        'macAddress': device.macAddress,
        'id': device.id,
        'lastConnected': device.lastConnected?.millisecondsSinceEpoch,
        'serviceUuid': BraceletDevice.serviceUuid,
        'autoConnect': true, // Marcar para reconexión automática
      };
      
      final jsonString = jsonEncode(deviceData);
      await prefs.setString(_keyLastBracelet, jsonString);
      
      print('[STORAGE] 💾 Manilla guardada: ${device.name} (${device.macAddress})');
    } catch (e) {
      print('[STORAGE] ❌ Error guardando manilla: $e');
    }
  }
  
  /// Obtener información de la última manilla conectada
  static Future<BraceletDevice?> getLastConnectedBracelet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyLastBracelet);
      
      if (jsonString == null || jsonString.isEmpty) {
        print('[STORAGE] ℹ️ No hay manilla guardada');
        return null;
      }
      
      final deviceData = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Reconstruir BraceletDevice desde datos guardados
      final device = BraceletDevice(
        name: deviceData['name'] ?? 'Manilla Desconocida',
        macAddress: deviceData['macAddress'] ?? '',
        id: deviceData['id'] ?? '',
        connectionStatus: BraceletConnectionStatus.disconnected,
        lastConnected: deviceData['lastConnected'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(deviceData['lastConnected'])
            : null,
      );
      
      print('[STORAGE] 📱 Manilla recuperada: ${device.name} (${device.macAddress})');
      return device;
    } catch (e) {
      print('[STORAGE] ❌ Error recuperando manilla: $e');
      return null;
    }
  }
  
  /// Verificar si debe reconectar automáticamente
  static Future<bool> shouldAutoReconnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyAutoReconnect) ?? true; // Por defecto habilitado
    } catch (e) {
      print('[STORAGE] ❌ Error verificando auto-reconexión: $e');
      return true;
    }
  }
  
  /// Habilitar/deshabilitar reconexión automática
  static Future<void> setAutoReconnect(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoReconnect, enabled);
      print('[STORAGE] 🔄 Auto-reconexión: ${enabled ? 'HABILITADA' : 'DESHABILITADA'}');
    } catch (e) {
      print('[STORAGE] ❌ Error configurando auto-reconexión: $e');
    }
  }
  
  /// Obtener número de intentos de reconexión
  static Future<int> getReconnectAttempts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_keyReconnectAttempts) ?? 0;
    } catch (e) {
      return 0;
    }
  }
  
  /// Incrementar contador de intentos de reconexión
  static Future<void> incrementReconnectAttempts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_keyReconnectAttempts) ?? 0;
      await prefs.setInt(_keyReconnectAttempts, current + 1);
      print('[STORAGE] 🔁 Intento de reconexión #${current + 1}');
    } catch (e) {
      print('[STORAGE] ❌ Error incrementando intentos: $e');
    }
  }
  
  /// Resetear contador de intentos de reconexión
  static Future<void> resetReconnectAttempts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyReconnectAttempts, 0);
      print('[STORAGE] ✅ Contador de reintentos reseteado');
    } catch (e) {
      print('[STORAGE] ❌ Error reseteando intentos: $e');
    }
  }
  
  /// Limpiar información de manilla guardada
  static Future<void> clearSavedBracelet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLastBracelet);
      await prefs.remove(_keyReconnectAttempts);
      print('[STORAGE] 🗑️ Información de manilla eliminada');
    } catch (e) {
      print('[STORAGE] ❌ Error eliminando manilla: $e');
    }
  }
  
  /// Obtener estadísticas de almacenamiento
  static Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDevice = await getLastConnectedBracelet();
      
      return {
        'hasStoredBracelet': lastDevice != null,
        'deviceName': lastDevice?.name,
        'macAddress': lastDevice?.macAddress,
        'deviceId': lastDevice?.id,
        'lastConnected': lastDevice?.lastConnected,
        'autoReconnectEnabled': await shouldAutoReconnect(),
        'reconnectAttempts': await getReconnectAttempts(),
      };
    } catch (e) {
      print('[STORAGE] ❌ Error obteniendo estadísticas: $e');
      return {};
    }
  }
}