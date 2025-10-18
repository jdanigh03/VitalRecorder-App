import 'dart:async';
import '../models/reminder.dart';
import '../models/user.dart';

class ReportsCache {
  static final ReportsCache _instance = ReportsCache._internal();
  factory ReportsCache() => _instance;
  ReportsCache._internal();

  // Cache para los datos básicos
  List<UserModel>? _cachedPatients;
  List<Reminder>? _cachedReminders;
  DateTime? _lastCacheUpdate;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // Cache para resultados de análisis
  final Map<String, CacheEntry> _analyticsCache = {};
  static const Duration _analyticsCacheExpiry = Duration(minutes: 2);

  /// Verifica si el cache principal está vigente
  bool get _isCacheValid {
    if (_lastCacheUpdate == null) return false;
    return DateTime.now().difference(_lastCacheUpdate!) < _cacheExpiry;
  }

  /// Obtiene pacientes del cache o null si no está disponible
  List<UserModel>? getCachedPatients() {
    if (!_isCacheValid) return null;
    return _cachedPatients;
  }

  /// Obtiene recordatorios del cache o null si no está disponible
  List<Reminder>? getCachedReminders() {
    if (!_isCacheValid) return null;
    return _cachedReminders;
  }

  /// Actualiza el cache principal con nuevos datos
  void updateCache(List<UserModel> patients, List<Reminder> reminders) {
    _cachedPatients = List.from(patients);
    _cachedReminders = List.from(reminders);
    _lastCacheUpdate = DateTime.now();
    
    // Limpiar cache de analytics cuando se actualiza el principal
    _analyticsCache.clear();
    
    print('Cache actualizado con ${patients.length} pacientes y ${reminders.length} recordatorios');
  }

  /// Obtiene resultado de análisis del cache
  T? getAnalyticsResult<T>(String key) {
    final entry = _analyticsCache[key];
    if (entry == null) return null;
    
    if (DateTime.now().difference(entry.timestamp) > _analyticsCacheExpiry) {
      _analyticsCache.remove(key);
      return null;
    }
    
    return entry.data as T?;
  }

  /// Guarda resultado de análisis en el cache
  void setAnalyticsResult<T>(String key, T data) {
    _analyticsCache[key] = CacheEntry(data, DateTime.now());
  }

  /// Genera clave para cache de analytics
  String generateAnalyticsKey({
    required String operation,
    required DateTime startDate,
    required DateTime endDate,
    String? patientId,
    String? type,
  }) {
    final parts = [
      operation,
      startDate.millisecondsSinceEpoch.toString(),
      endDate.millisecondsSinceEpoch.toString(),
    ];
    
    if (patientId != null) parts.add('patient_$patientId');
    if (type != null) parts.add('type_$type');
    
    return parts.join('_');
  }

  /// Limpia todo el cache
  void clearCache() {
    _cachedPatients = null;
    _cachedReminders = null;
    _lastCacheUpdate = null;
    _analyticsCache.clear();
    print('Cache limpiado completamente');
  }

  /// Invalida solo el cache de analytics
  void invalidateAnalyticsCache() {
    _analyticsCache.clear();
    print('Cache de analytics invalidado');
  }

  /// Estadísticas del cache
  Map<String, dynamic> getCacheStats() {
    return {
      'mainCacheValid': _isCacheValid,
      'cachedPatients': _cachedPatients?.length ?? 0,
      'cachedReminders': _cachedReminders?.length ?? 0,
      'analyticsEntries': _analyticsCache.length,
      'lastUpdate': _lastCacheUpdate?.toIso8601String(),
    };
  }

  /// Limpia entradas expiradas del cache de analytics
  void cleanExpiredEntries() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    _analyticsCache.forEach((key, entry) {
      if (now.difference(entry.timestamp) > _analyticsCacheExpiry) {
        expiredKeys.add(key);
      }
    });
    
    for (final key in expiredKeys) {
      _analyticsCache.remove(key);
    }
    
    if (expiredKeys.isNotEmpty) {
      print('Limpiadas ${expiredKeys.length} entradas expiradas del cache');
    }
  }
}

class CacheEntry {
  final dynamic data;
  final DateTime timestamp;

  CacheEntry(this.data, this.timestamp);
}

/// Mixin para usar cache en servicios
mixin CacheableMixin {
  ReportsCache get cache => ReportsCache();

  /// Ejecuta operación con cache
  Future<T> withCache<T>(
    String key,
    Future<T> Function() operation,
  ) async {
    // Intentar obtener del cache
    final cached = cache.getAnalyticsResult<T>(key);
    if (cached != null) {
      print('Resultado obtenido del cache: $key');
      return cached;
    }

    // Ejecutar operación y guardar en cache
    print('Ejecutando operación y cacheando: $key');
    final result = await operation();
    cache.setAnalyticsResult(key, result);
    
    return result;
  }
}