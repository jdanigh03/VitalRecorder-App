import 'package:flutter/material.dart';

class NotificacionesScreen extends StatelessWidget {
  const NotificacionesScreen({Key? key}) : super(key: key);

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
      body: notifications.isEmpty
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
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _buildNotificationCard(
                  context,
                  notification['title'] as String,
                  notification['message'] as String,
                  notification['time'] as String,
                  notification['isRead'] as bool,
                  notification['type'] as String,
                );
              },
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
}