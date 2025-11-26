import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/invitacion_service.dart';
import '../models/invitacion_cuidador.dart';
import '../services/user_service.dart';
import '../reminder_service_new.dart';
import '../services/cuidador_service.dart';
import '../models/reminder_new.dart';
import '../models/reminder_confirmation.dart';
import '../models/user.dart';
import 'invitaciones_cuidador.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({Key? key}) : super(key: key);

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final InvitacionService _invitacionService = InvitacionService();
  final UserService _userService = UserService();
  final ReminderServiceNew _reminderService = ReminderServiceNew();
  final CuidadorService _cuidadorService = CuidadorService();
  
  List<InvitacionCuidador> _invitacionesPendientes = [];
  bool _isLoadingInvitations = true;
  bool _isLoadingNotifications = true;
  String? _userRole;
  DateTime? _lastReadDate;
  
  final List<_AppNotification> _notifications = [];

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
      _lastReadDate = userData?.lastNotificationReadDate;
      
      // Invitaciones para cuidador
      if (_userRole == 'cuidador') {
        final invitaciones = await _invitacionService.getInvitacionesRecibidas();
        _invitacionesPendientes = invitaciones.where((inv) => inv.esPendiente).toList();
      }
      _isLoadingInvitations = false;
      
      // Cargar historial de notificaciones
      await _loadNotifications();
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _isLoadingInvitations = false;
      _isLoadingNotifications = false;
      print('Error cargando datos de notificaciones: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Construir lista de widgets
    final List<Widget> allNotifications = [];
    
    // Invitaciones (solo cuidadores)
    if (_userRole == 'cuidador' && !_isLoadingInvitations) {
      for (final invitacion in _invitacionesPendientes) {
        allNotifications.add(_buildInvitationNotificationCard(invitacion));
      }
    }
    
    // Historial dinámico
    if (!_isLoadingNotifications) {
      for (final n in _notifications) {
        allNotifications.add(_buildNotificationCard(
          context,
          n.title,
          n.message,
          _formatRelativeTime(n.when),
          n.read,
          n.type,
        ));
      }
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
            onPressed: () async {
              // Actualización optimista con buffer de 1 segundo para evitar problemas de precisión
              _lastReadDate = DateTime.now().add(Duration(seconds: 1));
              
              // Actualizar en servidor
              await _userService.markNotificationsAsRead();
              
              // Recargar lista con la nueva fecha
              await _loadNotifications();
              
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Todas las notificaciones marcadas como leídas'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: Text(
              'Marcar todo',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _isLoadingInvitations || _isLoadingNotifications
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

  Future<void> _loadNotifications() async {
    _isLoadingNotifications = true;
    _notifications.clear();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = today.subtract(const Duration(days: 7));

    if (_userRole == 'cuidador') {
      // Cuidadores: ver eventos de pacientes asignados (últimos 7 días + hoy)
      final pacientes = await _cuidadorService.getPacientes();
      final reminders = await _cuidadorService.getAllRemindersFromPatients();

      // Procesar cada recordatorio
      for (final reminder in reminders) {
        // Encontrar nombre del paciente
        final pacienteId = reminder.userId ?? '';
        if (pacienteId.isEmpty) continue;
        
        UserModel? paciente;
        try {
          paciente = pacientes.firstWhere((p) => p.userId == pacienteId);
        } catch (_) {
          paciente = null;
        }
        final pacienteNombre = paciente?.persona.nombres ?? 'Paciente';

        // Notificación de modificación/pausa del recordatorio
        if (reminder.updatedAt != null && reminder.updatedAt!.isAfter(sevenDaysAgo)) {
           // Si se actualizó recientemente
           String msg = 'Recordatorio modificado';
           String type = 'modified';
           
           if (reminder.isPaused) {
               msg = 'Recordatorio pausado';
               type = 'paused';
           }
           
           final notificationDate = reminder.updatedAt!;
           final isRead = _lastReadDate != null && notificationDate.isBefore(_lastReadDate!);

           _notifications.add(_AppNotification(
                type: type,
                title: '${pacienteNombre} - ${reminder.title}',
                message: msg,
                when: notificationDate,
                read: isRead,
              ));
        }

        // Obtener confirmaciones del recordatorio
        final confirmations = await _reminderService.getConfirmations(reminder.id);
        
        // Generar notificaciones para los últimos 7 días + hoy
        for (int dayOffset = -7; dayOffset <= 0; dayOffset++) {
          final checkDate = today.add(Duration(days: dayOffset));
          if (!reminder.hasOccurrencesOnDay(checkDate)) continue;
          
          final occurrences = reminder.calculateOccurrencesForDay(checkDate);
          
          for (final occurrence in occurrences) {
            // Verificar si hay confirmación para esta ocurrencia
            final confirmation = confirmations.firstWhere(
              (c) => 
                c.scheduledTime.year == occurrence.year &&
                c.scheduledTime.month == occurrence.month &&
                c.scheduledTime.day == occurrence.day &&
                c.scheduledTime.hour == occurrence.hour &&
                c.scheduledTime.minute == occurrence.minute,
              orElse: () => ReminderConfirmation(
                id: '',
                reminderId: '',
                userId: '',
                scheduledTime: occurrence,
                status: ConfirmationStatus.PENDING,
                createdAt: occurrence,
              ),
            );
            
            
            DateTime? notificationTime;
            String? type;
            String? message;
            String? title = '${pacienteNombre} - ${reminder.title}';

            if (dayOffset == 0) {
              // Hoy
              if (occurrence.isAfter(now)) {
                // No mostrar recordatorios futuros en notificaciones
                continue;
              } else if (confirmation.status == ConfirmationStatus.CONFIRMED) {
                type = 'completed';
                message = 'Completado';
                notificationTime = confirmation.confirmedAt ?? occurrence;
              } else if (confirmation.status == ConfirmationStatus.MISSED) {
                type = 'warning';
                message = 'Omitido';
                notificationTime = occurrence;
              } else if (confirmation.status == ConfirmationStatus.PAUSED) {
                type = 'paused';
                message = 'Pausado';
                notificationTime = confirmation.confirmedAt ?? occurrence;
              }
            } else {
              // Días anteriores
              if (confirmation.status == ConfirmationStatus.PAUSED) {
                type = 'paused';
                message = 'Pausado (${DateFormat('dd/MM').format(occurrence)})';
                notificationTime = confirmation.confirmedAt ?? occurrence;
              } else if (confirmation.status == ConfirmationStatus.MISSED || confirmation.status == ConfirmationStatus.PENDING) {
                type = 'warning';
                message = 'Omitido (${DateFormat('dd/MM').format(occurrence)})';
                notificationTime = occurrence;
              }
            }

            if (notificationTime != null && type != null && message != null) {
               final isRead = _lastReadDate != null && notificationTime.isBefore(_lastReadDate!);
               _notifications.add(_AppNotification(
                  type: type,
                  title: title,
                  message: message,
                  when: notificationTime,
                  read: isRead,
                ));
            }
          }
        }
      }
    } else {
      // Paciente: ver sus eventos (últimos 7 días + hoy)
      final reminders = await _reminderService.getAllReminders();

      for (final reminder in reminders) {
        // Notificación de modificación/pausa del recordatorio
        if (reminder.updatedAt != null && reminder.updatedAt!.isAfter(sevenDaysAgo)) {
           String msg = 'Recordatorio modificado';
           String type = 'modified';
           
           if (reminder.isPaused) {
               msg = 'Recordatorio pausado';
               type = 'paused';
           }
           
           final notificationDate = reminder.updatedAt!;
           final isRead = _lastReadDate != null && notificationDate.isBefore(_lastReadDate!);

           _notifications.add(_AppNotification(
                type: type,
                title: reminder.title,
                message: msg,
                when: notificationDate,
                read: isRead,
              ));
        }

        final confirmations = await _reminderService.getConfirmations(reminder.id);
        
        for (int dayOffset = -7; dayOffset <= 0; dayOffset++) {
          final checkDate = today.add(Duration(days: dayOffset));
          if (!reminder.hasOccurrencesOnDay(checkDate)) continue;
          
          final occurrences = reminder.calculateOccurrencesForDay(checkDate);
          
          for (final occurrence in occurrences) {
            final confirmation = confirmations.firstWhere(
              (c) => 
                c.scheduledTime.year == occurrence.year &&
                c.scheduledTime.month == occurrence.month &&
                c.scheduledTime.day == occurrence.day &&
                c.scheduledTime.hour == occurrence.hour &&
                c.scheduledTime.minute == occurrence.minute,
              orElse: () => ReminderConfirmation(
                id: '',
                reminderId: '',
                userId: '',
                scheduledTime: occurrence,
                status: ConfirmationStatus.PENDING,
                createdAt: occurrence,
              ),
            );
            
            DateTime? notificationTime;
            String? type;
            String? message;
            String? title = reminder.title;

            if (dayOffset == 0) {
              if (occurrence.isAfter(now)) {
                // No mostrar recordatorios futuros
                continue;
              } else if (confirmation.status == ConfirmationStatus.CONFIRMED) {
                type = 'completed';
                message = 'Completado';
                notificationTime = confirmation.confirmedAt ?? occurrence;
              } else if (confirmation.status == ConfirmationStatus.MISSED) {
                type = 'warning';
                message = 'Omitido';
                notificationTime = occurrence;
              } else if (confirmation.status == ConfirmationStatus.PAUSED) {
                type = 'paused';
                message = 'Pausado';
                notificationTime = confirmation.confirmedAt ?? occurrence;
              }
            } else {
              if (confirmation.status == ConfirmationStatus.PAUSED) {
                type = 'paused';
                message = 'Pausado (${DateFormat('dd/MM').format(occurrence)})';
                notificationTime = confirmation.confirmedAt ?? occurrence;
              } else if (confirmation.status == ConfirmationStatus.MISSED || confirmation.status == ConfirmationStatus.PENDING) {
                type = 'warning';
                message = 'Omitido (${DateFormat('dd/MM').format(occurrence)})';
                notificationTime = occurrence;
              }
            }

            if (notificationTime != null && type != null && message != null) {
               final isRead = _lastReadDate != null && notificationTime.isBefore(_lastReadDate!);
               _notifications.add(_AppNotification(
                  type: type,
                  title: title,
                  message: message,
                  when: notificationTime,
                  read: isRead,
                ));
            }
          }
        }
      }
    }

    // Ordenar por fecha descendente
    _notifications.sort((a, b) => b.when.compareTo(a.when));
    _isLoadingNotifications = false;
  }

  String _formatRelativeTime(DateTime when) {
    final now = DateTime.now();
    final diff = now.difference(when);
    if (diff.inDays >= 1) {
      if (diff.inDays == 1) return 'Ayer • ${DateFormat('HH:mm').format(when)}';
      return '${DateFormat('dd/MM HH:mm').format(when)}';
    }
    if (diff.inHours >= 1) return 'hace ${diff.inHours} h';
    if (diff.inMinutes >= 1) return 'hace ${diff.inMinutes} min';
    return 'justo ahora';
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
      case 'completed':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'warning':
        icon = Icons.warning;
        color = Colors.orange;
        break;
      case 'paused':
        icon = Icons.pause_circle_filled;
        color = Colors.grey;
        break;
      case 'modified':
        icon = Icons.edit;
        color = Colors.blueGrey;
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

class _AppNotification {
  final String type; // medication | reminder | completed | warning
  final String title;
  final String message;
  final DateTime when;
  final bool read;

  _AppNotification({
    required this.type,
    required this.title,
    required this.message,
    required this.when,
    this.read = false,
  });
}
