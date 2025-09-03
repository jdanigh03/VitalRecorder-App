import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  String userName = 'Usuario'; // Valor por defecto
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        // Busca el documento del usuario en Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          
          // Extrae el nombre desde persona.nombres
          final nombres = data['persona']?['nombres'];
          
          if (nombres != null && nombres.isNotEmpty) {
            setState(() {
              userName = nombres;
              isLoading = false;
            });
          } else {
            // Si no hay nombres, usa el email como fallback
            setState(() {
              userName = user.email?.split('@')[0] ?? 'Usuario';
              isLoading = false;
            });
          }
        } else {
          // Si no existe el documento, usa el email
          setState(() {
            userName = user.email?.split('@')[0] ?? 'Usuario';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error cargando datos del usuario: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      body: Center(
        child: isLoading 
          ? const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            )
          : Text(
              'Bienvenido, $userName',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
      ),
    );
  }
}