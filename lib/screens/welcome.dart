import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'agregar_recordatorio.dart';
import 'historial.dart';
import 'notificaciones.dart';
import 'ajustes.dart';
import 'asignar_cuidador.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Stream<QuerySnapshot> _getUpcomingReminders(String userId) {
    final now = DateTime.now();
    // Margen de 1 min hacia atrás para no quedarnos sin resultados por segundos de diferencia
    final from = now.subtract(const Duration(minutes: 1));

    return FirebaseFirestore.instance
        .collection('reminders')
        .where('userId', isEqualTo: userId)
        .orderBy('dateTime', descending: false)
        .startAt([Timestamp.fromDate(from)]) // >= from
        .limit(3)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'Usuario';
    final userName = email.split('@')[0];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con logo y saludo
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hola, $userName',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Gestiona tus recordatorios',
                          style: TextStyle(color: Colors.white60, fontSize: 15),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Image.asset(
                        'assets/vital_recorder_nobg.png',
                        height: 50,
                        width: 50,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Sección de próximos recordatorios
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A90E2).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.upcoming_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Próximos Recordatorios',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      user != null
                          ? StreamBuilder<QuerySnapshot>(
                              stream: _getUpcomingReminders(user.uid),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20.0),
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                }

                                if (snapshot.hasError) {
                                  // Muestra el error (útil si falta un índice compuesto)
                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.error_outline,
                                            color: Colors.redAccent, size: 20),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Error al cargar: ${snapshot.error}\n'
                                            'Si Firestore sugiere crear un índice, ábrelo y créalo.',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.info_outline, color: Colors.white60, size: 20),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'No hay recordatorios próximos',
                                            style: TextStyle(
                                              color: Colors.white60,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                return Column(
                                  children: snapshot.data!.docs.map((doc) {
                                    final data = doc.data() as Map<String, dynamic>;
                                    final title = data['title'] ?? 'Sin título';
                                    final ts = data['dateTime'];
                                    final dateTime = ts is Timestamp
                                        ? ts.toDate()
                                        : DateTime.tryParse(ts?.toString() ?? '') ?? DateTime.now();
                                    final type = (data['type'] ?? 'General').toString();

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.1),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: _getTypeColor(type),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              _getTypeIcon(type),
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  title,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _formatDateTime(dateTime),
                                                  style: TextStyle(
                                                    color: Colors.white.withOpacity(0.6),
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            )
                          : const Text(
                              'Inicia sesión para ver recordatorios',
                              style: TextStyle(color: Colors.white60),
                            ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Grid de opciones principales
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85,
                  children: [
                    _buildMenuCard(
                      context,
                      title: 'Agregar',
                      subtitle: 'Recordatorio',
                      icon: Icons.add_circle_outline,
                      colors: [const Color(0xFF4A90E2), const Color(0xFF357ABD)],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AgregarRecordatorioScreen()),
                      ),
                    ),
                    _buildMenuCard(
                      context,
                      title: 'Historial',
                      subtitle: 'Ver todos',
                      icon: Icons.history,
                      colors: [const Color(0xFF3AB54A), const Color(0xFF2E8B41)],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HistorialScreen()),
                      ),
                    ),
                    _buildMenuCard(
                      context,
                      title: 'Notificaciones',
                      subtitle: 'Alertas',
                      icon: Icons.notifications_outlined,
                      colors: [const Color(0xFFFF9800), const Color(0xFFFFB74D)],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificacionesScreen()),
                      ),
                    ),
                    _buildMenuCard(
                      context,
                      title: 'Cuidador',
                      subtitle: 'Asignar',
                      icon: Icons.supervised_user_circle_outlined,
                      colors: [const Color(0xFF8E24AA), const Color(0xFFBA68C8)],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AsignarCuidadorScreen()),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Botón de ajustes y cerrar sesión
                _buildTransparentButton(
                  context,
                  text: 'Ajustes',
                  icon: Icons.settings_outlined,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AjustesScreen()),
                  ),
                ),

                const SizedBox(height: 12),

                _buildTransparentButton(
                  context,
                  text: 'Cerrar Sesión',
                  icon: Icons.logout_outlined,
                  isLogout: true,
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors.first.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransparentButton(
    BuildContext context, {
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    bool isLogout = false,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: isLogout ? Colors.red.withOpacity(0.15) : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLogout ? Colors.red.withOpacity(0.3) : Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(icon, color: isLogout ? Colors.red[300] : Colors.white70),
                const SizedBox(width: 16),
                Text(
                  text,
                  style: TextStyle(
                    color: isLogout ? Colors.red[300] : Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'medicación':
      case 'medicamento':
        return const Color(0xFF4A90E2);
      case 'cita':
      case 'cita médica':
        return const Color(0xFF3AB54A);
      case 'tarea':
      case 'ejercicio':
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF8E24AA);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'medicación':
      case 'medicamento':
        return Icons.medication_outlined;
      case 'cita':
      case 'cita médica':
        return Icons.event_outlined;
      case 'tarea':
        return Icons.task_outlined;
      case 'ejercicio':
        return Icons.fitness_center_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inDays == 0) {
      if (difference.inHours < 1) {
        final mins = difference.inMinutes;
        if (mins <= 0) {
          return 'Ahora';
        }
        return 'En $mins min';
      }
      return 'Hoy a las ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Mañana a las ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month} a las ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
