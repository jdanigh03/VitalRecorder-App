import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vital_recorder_app/screens/notificaciones.dart';
import '../models/reminder.dart';
import '../models/user.dart';
import '../services/user_service.dart';
import '../services/cuidador_service.dart';
import '../services/invitacion_service.dart';
import '../services/reminder_service.dart';
import 'cuidador_pacientes_screen.dart';
import 'cuidador_recordatorios_screen.dart';
import 'cuidador_reportes_screen.dart';
import 'cuidador_pacientes_recordatorios.dart';
import 'invitaciones_cuidador.dart';
import 'ajustes.dart';
import 'auth_wrapper.dart';
import '../widgets/global_reminder_indicator.dart';

class CuidadorDashboard extends StatefulWidget {
  const CuidadorDashboard({Key? key}) : super(key: key);

  @override
  State<CuidadorDashboard> createState() => _CuidadorDashboardState();
}

class _CuidadorDashboardState extends State<CuidadorDashboard> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  String _cuidadorName = 'Cuidador';
  bool _isLoading = true;
  bool _hasInitialized = false;
  
  // Servicios
  final CuidadorService _cuidadorService = CuidadorService();
  final UserService _userService = UserService();
  final InvitacionService _invitacionService = InvitacionService();
  final ReminderService _reminderService = ReminderService();
  
  // Datos
  UserModel? _currentUserData;
  List<Reminder> _todayReminders = [];
  int _invitacionesPendientes = 0;

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

  // Configurar stream para monitorear invitaciones en tiempo real
  void _setupInvitacionesStream() {
    if (!_hasInitialized) return;
    
    _invitacionService.getInvitacionesRecibidasStream().listen((invitaciones) {
      final newCount = invitaciones.where((inv) => inv.esPendiente).length;
      
      // Si hay cambios en las invitaciones pendientes
      if (newCount != _invitacionesPendientes && mounted) {
        // Si aumentó el número, mostrar notificación
        if (newCount > _invitacionesPendientes) {
          _mostrarNotificacionNuevaInvitacion();
        }
        
        setState(() {
          _invitacionesPendientes = newCount;
        });
      }
    }, onError: (error) {
      print('Error en stream de invitaciones: $error');
    });
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
        _cuidadorName = nombres.isNotEmpty ? nombres : userInfo['nombre'] ?? 'Cuidador';
      } else {
        _cuidadorName = userInfo['nombre'] ?? 'Cuidador';
      }

      print('=== DATOS CUIDADOR CARGADOS ===');
      print('Email: $userEmail');
      print('Nombre: $_cuidadorName');
      
      // Cargar recordatorios relevantes de pacientes asignados
      await _loadRelevantRemindersFromPatients();
      
      // Cargar invitaciones pendientes
      await _loadInvitacionesPendientes();
      
      setState(() {
        _isLoading = false;
        _hasInitialized = true;
      });
    } catch (e) {
      print('Error cargando datos del cuidador: $e');
      setState(() {
        _isLoading = false;
        _cuidadorName = 'Cuidador';
      });
    }
  }

  Future<void> _loadRelevantRemindersFromPatients() async {
    try {
      print('=== CARGANDO RECORDATORIOS ===');
      
      // Verificar si el usuario actual tiene pacientes asignados
      final pacientesAsignados = await _cuidadorService.getPacientes();
      
      List<Reminder> relevantReminders = [];
      
      if (pacientesAsignados.isNotEmpty) {
        // Si es cuidador: obtener recordatorios de pacientes asignados
        print('Usuario es CUIDADOR - Cargando recordatorios de ${pacientesAsignados.length} pacientes');
        relevantReminders = await _cuidadorService.getTodayRemindersFromAllPatients();
      } else {
        // Si es paciente: obtener sus propios recordatorios
        print('Usuario es PACIENTE - Cargando recordatorios propios');
        final allReminders = await _reminderService.getAllReminders();
        
        // Filtrar recordatorios relevantes (hoy + pendientes de días anteriores)
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        relevantReminders = allReminders.where((r) {
          final reminderDate = DateTime(r.dateTime.year, r.dateTime.month, r.dateTime.day);
          final isToday = reminderDate.isAtSameMomentAs(today);
          final isPastButActive = reminderDate.isBefore(today) && r.isActive && !r.isCompleted;
          return isToday || isPastButActive;
        }).toList();
        
        print('=== DEBUG FILTRO PACIENTE ===');
        print('Total recordatorios en BD: ${allReminders.length}');
        print('Recordatorios relevantes filtrados: ${relevantReminders.length}');
        for (final reminder in relevantReminders) {
          final dateStr = '${reminder.dateTime.day}/${reminder.dateTime.month}';
          print('✅ ${reminder.title} [$dateStr] - Activo: ${reminder.isActive} - Completado: ${reminder.isCompleted}');
        }
      }
      
      // Ordenar por hora
      relevantReminders.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      
      // Eliminar duplicados
      _todayReminders = relevantReminders.toSet().toList();
      
      print('=== RESULTADO FINAL ===');
      print('Total recordatorios mostrados: ${_todayReminders.length}');
      
    } catch (e) {
      print('Error cargando recordatorios: $e');
      _todayReminders = [];
    }
  }

  Future<void> _loadInvitacionesPendientes() async {
    try {
      final invitaciones = await _invitacionService.getInvitacionesRecibidas();
      final newCount = invitaciones.where((inv) => inv.esPendiente).length;
      
      // Si hay más invitaciones pendientes que antes, mostrar notificación
      if (newCount > _invitacionesPendientes && _hasInitialized) {
        _mostrarNotificacionNuevaInvitacion();
      }
      
      _invitacionesPendientes = newCount;
      
      print('=== INVITACIONES PENDIENTES ===');
      print('Total invitaciones pendientes: $_invitacionesPendientes');
    } catch (e) {
      print('Error cargando invitaciones pendientes: $e');
      _invitacionesPendientes = 0;
    }
  }

  void _mostrarNotificacionNuevaInvitacion() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.mail, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text('¡Tienes una nueva invitación de un paciente!'),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Ver',
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const InvitacionesCuidadorScreen()),
            ).then((_) {
              _loadUserData();
            });
          },
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CuidadorPacientesScreen()),
        ).then((_) {
          setState(() => _selectedIndex = 0);
          _loadUserData();
        });
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CuidadorRecordatoriosScreen()),
        ).then((_) {
          setState(() => _selectedIndex = 0);
          _loadUserData();
        });
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AjustesScreen()),
        ).then((_) {
          setState(() => _selectedIndex = 0);
          _loadUserData();
        });
        break;
    }
  }

  void _marcarComoCompletado(Reminder reminder) async {
    try {
      // No podemos marcar recordatorios de pacientes como completados
      // Esto debe ser hecho por el paciente directamente
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.info, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('Los pacientes deben completar sus propios recordatorios'),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usar _todayReminders que ya viene filtrado y ordenado
    final todayReminders = _todayReminders;

    final pendingCount = todayReminders.where((r) => !r.isCompleted).length;
    final completedCount = todayReminders.where((r) => r.isCompleted).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        elevation: 0,
        title: Row(
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
                child: Icon(Icons.supervisor_account, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cuidador',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _cuidadorName.toUpperCase(),
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
        actions: [
          // Botón de invitaciones
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.mail_outline, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const InvitacionesCuidadorScreen()),
                  ).then((_) {
                    // Recargar datos al regresar
                    _loadUserData();
                  });
                },
              ),
              if (_invitacionesPendientes > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    constraints: BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '$_invitacionesPendientes',
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
          // Botón de notificaciones
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
                          ? 'No hay recordatorios pendientes'
                          : pendingCount == 0
                              ? '¡Todos los recordatorios completados!'
                              : 'Pacientes: $pendingCount ${pendingCount == 1 ? 'pendiente' : 'pendientes'}',
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
                  ],
                ),
              ),
              
              // Indicador global de recordatorio de manilla
              GlobalReminderIndicator(),

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
                                  'Recordatorios Pendientes',
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
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CuidadorPacientesRecordatoriosScreen(),
                                  ),
                                ).then((_) => _loadUserData());
                              },
                              icon: Icon(Icons.folder_shared, size: 18),
                              label: Text('Por Pacientes'),
                              style: TextButton.styleFrom(
                                foregroundColor: Color(0xFF4A90E2),
                                backgroundColor: Color(0xFF4A90E2).withOpacity(0.1),
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CuidadorReportesScreen(),
                                  ),
                                );
                              },
                              icon: Icon(Icons.analytics, size: 18),
                              label: Text('Reportes'),
                              style: TextButton.styleFrom(
                                foregroundColor: Color(0xFF4A90E2),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CuidadorPacientesScreen(),
                                  ),
                                );
                              },
                              icon: Icon(Icons.people, size: 18),
                              label: Text('Pacientes'),
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
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CuidadorPacientesScreen(),
            ),
          );
        },
        backgroundColor: const Color(0xFF4A90E2),
        icon: const Icon(Icons.people, color: Colors.white),
        label: const Text(
          'Ver Pacientes',
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
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Pacientes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.schedule_outlined),
              activeIcon: Icon(Icons.schedule),
              label: 'Recordatorios',
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
              'Cargando recordatorios de pacientes...',
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
                Icons.supervisor_account_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No hay recordatorios de pacientes hoy',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tus pacientes no tienen recordatorios programados para hoy',
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
                    builder: (context) => CuidadorPacientesScreen(),
                  ),
                );
              },
              icon: Icon(Icons.people),
              label: Text('Ver Mis Pacientes'),
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

  Widget _buildReminderCard(Reminder reminder) {
    final isPast = reminder.dateTime.isBefore(DateTime.now()) && !reminder.isCompleted;
    
    return GestureDetector(
      onTap: () {
        _showReminderDetails(reminder);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPast 
                ? Colors.red.withOpacity(0.3) 
                : reminder.isCompleted 
                    ? Colors.green.withOpacity(0.3)
                    : Colors.transparent,
            width: isPast || reminder.isCompleted ? 2 : 0,
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
                  // Icono del tipo
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

                  // Información del recordatorio
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
                            decoration: reminder.isCompleted 
                                ? TextDecoration.lineThrough 
                                : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          reminder.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            decoration: reminder.isCompleted 
                                ? TextDecoration.lineThrough 
                                : null,
                          ),
                          overflow: TextOverflow.ellipsis,
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
                                  color: isPast ? Colors.red : Colors.grey[500],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${reminder.dateTime.hour}:${reminder.dateTime.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isPast ? Colors.red : Color(0xFF4A90E2),
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
                                  reminder.frequency,
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

                  // Botón de acción o estado - adaptado para cuidador
                  const SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: reminder.isCompleted 
                          ? Colors.green.withOpacity(0.1)
                          : isPast 
                              ? Colors.red.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      reminder.isCompleted 
                          ? Icons.check_circle
                          : isPast 
                              ? Icons.error
                              : Icons.schedule,
                      color: reminder.isCompleted 
                          ? Colors.green
                          : isPast 
                              ? Colors.red
                              : Colors.orange,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
            
            // Indicador de estado omitido
            if (isPast)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Omitido',
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







  void _showReminderDetails(Reminder reminder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(reminder.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Descripción: ${reminder.description}'),
            SizedBox(height: 8),
            Text('Tipo: ${reminder.type}'),
            SizedBox(height: 8),
            Text('Fecha: ${reminder.dateTime.toString()}'),
            SizedBox(height: 8),
            Text('Estado: ${reminder.isCompleted ? 'Completado' : 'Pendiente'}'),
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

  Future<void> _handleLogout() async {
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
  }
}
