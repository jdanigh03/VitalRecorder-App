import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = FirebaseFirestore.instance.collection('users').doc(uid).snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userDoc,
      builder: (context, snap) {
        // Estado de carga / error
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snap.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snap.error}')),
          );
        }

        final data = snap.data?.data();

        // Obtener el nombre desde Firestore
        String nombre = '';
        if (data != null) {
          final persona = data['persona'] as Map<String, dynamic>?;
          nombre = (persona?['nombres'] as String?)?.trim() ?? '';
        }

        // Si el nombre no está en Firestore, usa el displayName de FirebaseAuth
        nombre = nombre.isEmpty
            ? (FirebaseAuth.instance.currentUser?.displayName ?? 'Usuario')
            : nombre;

        // Si deseas mostrar solo el primer nombre
        final primerNombre = nombre.split(' ').first;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // Fondo con gradiente
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF1A237E)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    // Barra superior personalizada
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0C1A3A),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white24,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Hola, Bienvenido De Nuevo',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  primerNombre.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.notifications_none, color: Colors.white),
                            tooltip: 'Notificaciones',
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.settings, color: Colors.white),
                            tooltip: 'Ajustes',
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.help_outline, color: Colors.white),
                            tooltip: 'Ayuda',
                          ),
                        ],
                      ),
                    ),

                    // Cuerpo con mensaje grande
                    Expanded(
                      child: Center(
                        child: Text(
                          'Bienvenido\n@${primerNombre.toUpperCase()}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Botón para cerrar sesión
              Positioned(
                right: 12,
                bottom: 20,
                child: FloatingActionButton.extended(
                  backgroundColor: const Color(0xFF0C1A3A),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    // AuthGate se encargará de volver al Login
                  },
                  label: const Text('Salir', style: TextStyle(color: Colors.white)),
                  icon: const Icon(Icons.logout, color: Colors.white),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
