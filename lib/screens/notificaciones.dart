import 'package:flutter/material.dart';
import '../services/invitacion_service.dart';
import '../models/invitacion_cuidador.dart';
import '../services/user_service.dart';
import 'invitaciones_cuidador.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({Key? key}) : super(key: key);

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final InvitacionService _invitacionService = InvitacionService();
  final UserService _userService = UserService();
  
  List<InvitacionCuidador> _invitacionesPendientes = [];
  bool _isLoadingInvitations = true;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      // Obtener rol del usuario
      final userData = await _userService.getCurrentUserData();
      _userRole = userData?.role;
      
      // Si es cuidador, cargar invitaciones pendientes
      if (_userRole == 'cuidador') {
        final invitaciones = await _invitacionService.getInvitacionesRecibidas();
        setState(() {
          _invitacionesPendientes = invitaciones.where((inv) => inv.esPendiente).toList();
          _isLoadingInvitations = false;
        });
      } else {
        setState(() {
          _isLoadingInvitations = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingInvitations = false;
      });
      print('Error cargando datos de notificaciones: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = [
      {
        'title': 'Amoxicilina 1g',
        'message': 'Es hora de tomar tu medicamento',
        'time': '9:00 AM',
        'isRead': false,
        'type': 'medication',
      },
      {
        'title': 'Recordatorio próximo',
        'message': 'Ibuprofeno 400mg en 2 horas',
        'time': '12:00 PM',
        'isRead': true,
        'type': 'reminder',
      },
      {
        'title': 'Caminata',
        'message': 'No olvides tu caminata de 30 minutos',
        'time': '6:00 PM',
        'isRead': false,
        'type': 'activity',
      },
      {
        'title': 'Medicamento omitido',
        'message': 'No confirmaste la toma de Vitamina D',
        'time': 'Ayer',
        'isRead': true,
        'type': 'warning',
      },
    ];

    // Combinar notificaciones regulares con invitaciones
    final List<Widget> allNotifications = [];
    
    // Agregar invitaciones pendientes para cuidadores
    if (_userRole == 'cuidador' && !_isLoadingInvitations) {
      for (final invitacion in _invitacionesPendientes) {
        allNotifications.add(_buildInvitationNotificationCard(invitacion));
      }
    }
    
    // Agregar notificaciones regulares
    for (int i = 0; i < notifications.length; i++) {
      final notification = notifications[i];
      allNotifications.add(_buildNotificationCard(
        context,
        notification['title'] as String,
        notification['message'] as String,
        notification['time'] as String,
        notification['isRead'] as bool,
        notification['type'] as String,
      ));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        title: const Text(
          'Notificaciones',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Todas las notificaciones marcadas como leídas'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text(
              'Marcar todo',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _isLoadingInvitations
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Cargando notificaciones...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : allNotifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No tienes notificaciones',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.all(16),
                  itemCount: allNotifications.length,
                  separatorBuilder: (context, index) => SizedBox(height: 8),
                  itemBuilder: (context, index) => allNotifications[index],
                ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    String title,
    String message,
    String time,
    bool isRead,
    String type,
  ) {
    IconData icon;
    Color color;

    switch (type) {
      case 'medication':
        icon = Icons.medication;
        color = Colors.blue;
        break;
      case 'activity':
        icon = Icons.directions_run;
        color = Colors.green;
        break;
      case 'warning':
        icon = Icons.warning;
        color = Colors.orange;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.purple;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : Color(0xFF4A90E2).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRead ? Colors.grey.shade200 : Color(0xFF4A90E2).withOpacity(0.3),
          width: isRead ? 1 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ),
            if (!isRead)
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Color(0xFF4A90E2),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              time,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.close, color: Colors.grey),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Notificación eliminada'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInvitationNotificationCard(InvitacionCuidador invitacion) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.purple.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InvitacionesCuidadorScreen(),
            ),
          ).then((_) {
            // Recargar datos cuando regrese de la pantalla de invitaciones
            _cargarDatos();
          });
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple[400]!, Colors.purple[600]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_add,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Nueva Invitación',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A5F),
                              ),
                            ),
                            Spacer(),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.purple,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'NUEVO',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          '${invitacion.pacienteNombre} te invita a ser su cuidador',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Relación: ${invitacion.relacion}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.purple[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          _formatearFecha(invitacion.fechaEnvio),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.purple[100]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.touch_app,
                      color: Colors.purple[600],
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Toca para ver y responder a la invitación',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.purple[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    final now = DateTime.now();
    final difference = now.difference(fecha);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'hace ${difference.inMinutes} minutos';
      }
      return 'hace ${difference.inHours} horas';
    } else if (difference.inDays == 1) {
      return 'ayer';
    } else if (difference.inDays < 7) {
      return 'hace ${difference.inDays} días';
    } else {
      return '${fecha.day}/${fecha.month}/${fecha.year}';
    }
  }
}
