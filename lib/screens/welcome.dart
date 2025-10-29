// ========================================
// ARCHIVO: lib/screens/welcome.dart
// ========================================
import 'package:flutter/material.dart';
import 'package:vital_recorder_app/screens/notificaciones.dart';
import '../models/reminder_new.dart';
import '../models/user.dart';
import '../services/user_service.dart';
import '../reminder_service_new.dart';
import '../services/bracelet_service.dart';
import '../services/calendar_service.dart';
import '../services/notification_service.dart';
import '../models/bracelet_device.dart';
import 'agregar_recordatorio.dart';
import 'detalle_recordatorio.dart';
import 'historial.dart';
import 'calendario.dart';
import 'asignar_cuidador.dart';
import 'ajustes.dart';
import 'perfil_usuario.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  String _userName = 'Usuario';
  bool _isLoading = true;
  bool _hasInitialized = false;
  
  // Variables para selección múltiple
  bool _isMultiSelectMode = false;
  Set<String> _selectedReminderIds = <String>{};
  
  // Servicios de Firebase
  final UserService _userService = UserService();
  final ReminderServiceNew _reminderService = ReminderServiceNew();
  final BraceletService _braceletService = BraceletService();
  final CalendarService _calendarService = CalendarService();
  final NotificationService _notificationService = NotificationService();
  
  // Datos del usuario
  UserModel? _currentUserData;
  List<ReminderNew> _todayReminders = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hasInitialized = false;
    _loadUserData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recargar datos solo después de la inicialización inicial y cuando la pantalla se hace visible
    if (_hasInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadUserData();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Recargar cuando la app vuelve a primer plano
    if (state == AppLifecycleState.resumed && _hasInitialized) {
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Obtener información básica del usuario
      final userInfo = await _userService.getUserDisplayInfo();
      final userEmail = userInfo['email'] ?? 'Sin email';
      
      // Obtener datos completos del usuario desde Firestore
      _currentUserData = await _userService.getCurrentUserData();
      
      // Actualizar nombre de usuario
      if (_currentUserData != null) {
        final nombres = _currentUserData!.persona.nombres;
        _userName = nombres.isNotEmpty ? nombres : userInfo['nombre'] ?? 'Usuario';
      } else {
        _userName = userInfo['nombre'] ?? 'Usuario';
      }

      print('=== DATOS USUARIO CARGADOS ===');
      print('Email: $userEmail');
      print('Nombre: $_userName');
      
      // Cargar recordatorios de hoy
      await _loadTodayReminders();
      
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasInitialized = true;
      });
    } catch (e) {
      print('Error cargando datos del usuario: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _userName = 'Usuario';
      });
    }
  }

  Future<void> _loadTodayReminders() async {
    try {
      print('=== CARGANDO RECORDATORIOS (NUEVO SISTEMA) ===');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Obtener todos los recordatorios activos
      final allReminders = await _reminderService.getAllReminders();
      print('Recordatorios activos encontrados: ${allReminders.length}');
      
      List<ReminderNew> relevantReminders = [];
      
      // Para cada recordatorio, obtener ocurrencias de hoy y pendientes
      for (final reminder in allReminders) {
        // Verificar si tiene ocurrencias hoy
        if (reminder.hasOccurrencesOnDay(today)) {
          relevantReminders.add(reminder);
          print('✅ ${reminder.title} - Activo hoy');
        }
      }
      
      _todayReminders = relevantReminders;
      
      print('=== RECORDATORIOS CARGADOS ===');
      print('Total recordatorios relevantes: ${_todayReminders.length}');
      for (final reminder in _todayReminders) {
        print('- ${reminder.title} - ${reminder.intervalDisplayText}');
      }
    } catch (e) {
      print('Error cargando recordatorios: $e');
      _todayReminders = [];
    }
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    
    if (!mounted) return;
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        // Ya estamos en Inicio
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AjustesScreen()),
        );
        break;
    }
  }

  void _marcarComoCompletado(ReminderNew reminder, DateTime scheduledTime) async {
    try {
      final now = DateTime.now();
      
      // Confirmar ocurrencia específica
      final success = await _reminderService.confirmReminder(
        reminderId: reminder.id,
        scheduledTime: scheduledTime,
        confirmedAt: now,
      );
      
      if (success) {
        // Recargar la lista de recordatorios para reflejar cambios
        await _loadTodayReminders();
        setState(() {});
        
        // Enviar notificación a la manilla si está conectada
        _sendBraceletNotification(reminder);
      } else {
        throw Exception('No se pudo marcar como completado');
      }
    } catch (e) {
      print('Error marcando recordatorio como completado: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('Error al completar recordatorio'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text('¡Recordatorio completado!'),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendBraceletNotification(ReminderNew reminder) async {
    try {
      // Solo enviar si hay una manilla conectada
      if (!_braceletService.isConnected) {
        print('No hay manilla conectada para enviar notificación');
        return;
      }

      // Determinar tipo de notificación basado en el tipo de recordatorio
      BraceletNotificationType notificationType;
      if (reminder.type == 'medication') {
        notificationType = BraceletNotificationType.medicationTime;
      } else if (reminder.type == 'exercise') {
        notificationType = BraceletNotificationType.exerciseTime;
      } else {
        notificationType = BraceletNotificationType.reminderAlert;
      }

      // Crear notificación para la manilla
      final braceletNotification = BraceletNotification(
        type: notificationType,
        title: 'Recordatorio Completado',
        message: '${reminder.title} - ¡Bien hecho!',
        duration: 3, // 3 segundos de notificación
        scheduledTime: DateTime.now(),
      );

      // Enviar a la manilla
      await _braceletService.sendReminderNotification(braceletNotification);
      print('Notificación enviada a la manilla: ${reminder.title}');

    } catch (e) {
      print('Error enviando notificación a la manilla: $e');
      // No mostrar error al usuario ya que es funcionalidad secundaria
    }
  }

  // === FUNCIONES DE SELECCIÓN MÚTIPLE ===
  
  void _startMultiSelect(String reminderId) {
    setState(() {
      _isMultiSelectMode = true;
      _selectedReminderIds.add(reminderId);
    });
  }
  
  void _toggleSelection(String reminderId) {
    setState(() {
      if (_selectedReminderIds.contains(reminderId)) {
        _selectedReminderIds.remove(reminderId);
        // Si no hay más seleccionados, salir del modo
        if (_selectedReminderIds.isEmpty) {
          _isMultiSelectMode = false;
        }
      } else {
        _selectedReminderIds.add(reminderId);
      }
    });
  }
  
  void _cancelMultiSelect() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedReminderIds.clear();
    });
  }
  
  void _selectAll() {
    setState(() {
      _selectedReminderIds = _todayReminders.map((r) => r.id).toSet();
    });
  }
  
  Future<void> _completeMultipleReminders() async {
    if (_selectedReminderIds.isEmpty) return;
    
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      int completedCount = 0;
      
      for (final reminderId in _selectedReminderIds) {
        final reminder = _todayReminders.firstWhere((r) => r.id == reminderId);
        final reminderDate = DateTime(reminder.dateTime.year, reminder.dateTime.month, reminder.dateTime.day);
        final completionDate = reminderDate.isBefore(today) ? reminderDate : today;
        
        final success = await _calendarService.markReminderCompleted(reminder.id, completionDate);
        if (success) {
          completedCount++;
        }
      }
      
      // Salir del modo selección
      _cancelMultiSelect();
      
      // Recargar la lista
      await _loadTodayReminders();
      setState(() {});
      
      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('¡$completedCount recordatorios completados!'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: Duration(seconds: 2),
        ),
      );
      
    } catch (e) {
      print('Error completando múltiples recordatorios: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al completar recordatorios'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usar _todayReminders que ya viene filtrado y ordenado desde Firebase
    final todayReminders = _todayReminders;

    // Los contadores se calculan diferente ahora:
    // - Pendientes: recordatorios que aparecen en la lista (ya filtrados para mostrar solo no completados)
    // - Completados: no los mostramos en la lista, pero podrían estar completados hoy
    final pendingCount = todayReminders.length; // Todos los que aparecen son pendientes
    final completedCount = 0; // No mostramos completados en esta vista

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        elevation: 0,
        // AppBar diferente para modo selección
        title: _isMultiSelectMode
            ? Text(
                '${_selectedReminderIds.length} seleccionados',
                style: TextStyle(color: Colors.white, fontSize: 18),
              )
            : Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.white24,
                      radius: 18,
                      child: Icon(Icons.person, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bienvenido',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _userName.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        // Botones de acción diferentes según el modo
        actions: _isMultiSelectMode
            ? [
                // Botón seleccionar todos
                IconButton(
                  icon: Icon(
                    _selectedReminderIds.length == _todayReminders.length
                        ? Icons.deselect
                        : Icons.select_all,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    if (_selectedReminderIds.length == _todayReminders.length) {
                      _cancelMultiSelect();
                    } else {
                      _selectAll();
                    }
                  },
                  tooltip: _selectedReminderIds.length == _todayReminders.length
                      ? 'Deseleccionar todo'
                      : 'Seleccionar todo',
                ),
                // Botón completar seleccionados
                IconButton(
                  icon: Icon(Icons.check_circle, color: Colors.green),
                  onPressed: _selectedReminderIds.isEmpty
                      ? null
                      : _completeMultipleReminders,
                  tooltip: 'Completar seleccionados',
                ),
                // Botón cancelar
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: _cancelMultiSelect,
                  tooltip: 'Cancelar',
                ),
              ]
            : [
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const NotificacionesScreen()),
                        );
                      },
                    ),
                    if (pendingCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            '$pendingCount',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AjustesScreen()),
                    );
                  },
                ),
              ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadUserData();
        },
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con gradiente
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1E3A5F),
                      Color(0xFF2D5082),
                      Color(0xFF4A90E2),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getFormattedDate(DateTime.now()),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      todayReminders.isEmpty
                          ? 'No tienes recordatorios pendientes'
                          : pendingCount == 0
                              ? '¡Todos los recordatorios al día!'
                              : 'Tienes $pendingCount ${pendingCount == 1 ? 'recordatorio pendiente' : 'recordatorios pendientes'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildStatCard(
                          'Total',
                          '${todayReminders.length}',
                          Icons.calendar_today,
                          Colors.white24,
                        ),
                        SizedBox(width: 12),
                        _buildStatCard(
                          'Completados',
                          '$completedCount',
                          Icons.check_circle,
                          Colors.green.withOpacity(0.3),
                        ),
                        SizedBox(width: 12),
                        _buildStatCard(
                          'Pendientes',
                          '$pendingCount',
                          Icons.pending,
                          Colors.orange.withOpacity(0.3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Widget de estado de la manilla
                    _buildBraceletWidget(),
                  ],
                ),
              ),

              // Contenido principal
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                color: Color(0xFF1E3A5F),
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Recordatorios Actuales',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A5F),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const CalendarioScreen(),
                                  ),
                                );
                              },
                              icon: Icon(Icons.file_download, size: 18),
                              label: Text('Exportar'),
                              style: TextButton.styleFrom(
                                foregroundColor: Color(0xFF4A90E2),
                              ),
                            ),
                            SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const CalendarioScreen(),
                                  ),
                                );
                              },
                              icon: Icon(Icons.calendar_view_month, size: 18),
                              label: Text('Calendario'),
                              style: TextButton.styleFrom(
                                foregroundColor: Color(0xFF4A90E2),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Lista de recordatorios con loading state
                    if (_isLoading)
                      _buildLoadingState()
                    else if (todayReminders.isEmpty)
                      _buildEmptyState()
                    else
                      ...todayReminders.map((reminder) => _buildReminderCard(reminder)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AgregarRecordatorioScreen(),
            ),
          );
          _loadUserData(); // Recargar después de agregar
        },
        backgroundColor: const Color(0xFF4A90E2),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nuevo Recordatorio',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 4,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF4A90E2),
          unselectedItemColor: Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          backgroundColor: Colors.white,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Cuidadores',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'Historial',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Ajustes',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            CircularProgressIndicator(
              color: Color(0xFF4A90E2),
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              'Cargando recordatorios...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No hay recordatorios pendientes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '¡Excelente! Todo al día',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AgregarRecordatorioScreen(),
                  ),
                );
              },
              icon: Icon(Icons.add),
              label: Text('Agregar Recordatorio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(ReminderNew reminder) {
    final now = DateTime.now();
    final nextOccurrence = reminder.getNextOccurrence();
    final isSelected = _selectedReminderIds.contains(reminder.id);
    
    // Mostrar próxima ocurrencia o última si no hay próxima
    final displayTime = nextOccurrence ?? DateTime.now();
    final isPast = nextOccurrence == null || nextOccurrence.isBefore(now);
    
    return GestureDetector(
      onTap: () async {
        if (_isMultiSelectMode) {
          _toggleSelection(reminder.id);
        } else {
          // Navegar a confirmaciones del paciente
          Navigator.pushNamed(context, '/paciente_confirmaciones');
        }
      },
      onLongPress: () {
        if (!_isMultiSelectMode) {
          _startMultiSelect(reminder.id);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.blue
                : isPast
                    ? Colors.red.withOpacity(0.3)
                    : Colors.orange.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_isMultiSelectMode) ...[
                    Checkbox(
                      value: isSelected,
                      onChanged: (value) => _toggleSelection(reminder.id),
                      activeColor: Colors.blue,
                      shape: CircleBorder(),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: reminder.type == 'medication'
                            ? [Colors.blue[400]!, Colors.blue[600]!]
                            : [Colors.green[400]!, Colors.green[600]!],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: (reminder.type == 'medication' 
                              ? Colors.blue 
                              : Colors.green).withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      reminder.type == 'medication' 
                          ? Icons.medication 
                          : Icons.directions_run,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reminder.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A5F),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          reminder.notes ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time, 
                                  size: 14, 
                                  color: isPast ? Colors.red : Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${displayTime.hour}:${displayTime.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isPast ? Colors.red : Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.repeat, size: 14, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text(
                                  reminder.intervalDisplayText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!_isMultiSelectMode) ...[
                    const SizedBox(width: 8),
                    Icon(
                      isPast ? Icons.error : Icons.schedule,
                      color: isPast ? Colors.red : Colors.orange,
                      size: 32,
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPast ? Colors.red : Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isPast ? 'Vencido' : 'Pendiente',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBraceletWidget() {
    return AnimatedBuilder(
      animation: _braceletService,
      builder: (context, child) {
        final device = _braceletService.connectedDevice;
        final isConnected = device?.connectionStatus == BraceletConnectionStatus.connected;
        
        return GestureDetector(
          onTap: () {
            if (isConnected) {
              Navigator.of(context).pushNamed('/bracelet-control');
            } else {
              Navigator.of(context).pushNamed('/bracelet-setup');
            }
          },
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isConnected 
                        ? Colors.green.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isConnected ? Icons.watch : Icons.watch_off,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isConnected 
                            ? 'Manilla Conectada' 
                            : 'Configurar Manilla',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        isConnected 
                            ? '${device!.name} • Lista para notificaciones'
                            : 'Conecta tu manilla ESP32-C3 para recordatorios LED',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.7),
                  size: 16,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getFormattedDate(DateTime date) {
    const months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    const days = [
      'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
    ];
    
    final dayName = days[date.weekday - 1];
    final day = date.day;
    final month = months[date.month - 1];
    final year = date.year;
    
    return '$dayName, $day de $month de $year';
  }
}