import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Colección de usuarios en Firestore
  CollectionReference get _usersCollection => _firestore.collection('users');

  // Obtener el usuario actual
  User? get currentUser => _auth.currentUser;

  // Obtener datos del usuario desde Firestore
  Future<UserModel?> getCurrentUserData() async {
    try {
      final user = currentUser;
      if (user == null) return null;

      final doc = await _usersCollection.doc(user.uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error obteniendo datos del usuario: $e');
      return null;
    }
  }

  // Crear o actualizar datos del usuario
  Future<bool> createOrUpdateUser(UserModel userData) async {
    try {
      final user = currentUser;
      if (user == null) return false;

      await _usersCollection.doc(user.uid).set(userData.toMap(), SetOptions(merge: true));
      return true;
    } catch (e) {
      print('Error guardando datos del usuario: $e');
      return false;
    }
  }

  // Actualizar solo la información personal
  Future<bool> updatePersonalInfo(UserPersona persona) async {
    try {
      final user = currentUser;
      if (user == null) return false;

      await _usersCollection.doc(user.uid).update({
        'persona': persona.toMap(),
      });
      return true;
    } catch (e) {
      print('Error actualizando información personal: $e');
      return false;
    }
  }

  // Actualizar solo la configuración
  Future<bool> updateSettings(UserSettings settings) async {
    try {
      final user = currentUser;
      if (user == null) return false;

      await _usersCollection.doc(user.uid).update({
        'settings': settings.toMap(),
      });
      return true;
    } catch (e) {
      print('Error actualizando configuración: $e');
      return false;
    }
  }

  // Verificar si existe el usuario en Firestore
  Future<bool> userExists() async {
    try {
      final user = currentUser;
      if (user == null) return false;

      final doc = await _usersCollection.doc(user.uid).get();
      return doc.exists;
    } catch (e) {
      print('Error verificando existencia del usuario: $e');
      return false;
    }
  }

  // Crear usuario inicial con datos básicos
  Future<bool> createInitialUser() async {
    try {
      final user = currentUser;
      if (user == null) return false;

      // Crear usuario con datos mínimos
      final initialUser = UserModel(
        email: user.email ?? '',
        persona: UserPersona(
          nombres: user.displayName ?? 'Usuario',
          apellidos: '',
        ),
        settings: UserSettings(
          telefono: '',
        ),
        createdAt: DateTime.now(),
      );

      await _usersCollection.doc(user.uid).set(initialUser.toMap());
      return true;
    } catch (e) {
      print('Error creando usuario inicial: $e');
      return false;
    }
  }

  // Stream para escuchar cambios en tiempo real
  Stream<UserModel?> getUserStream() {
    final user = currentUser;
    if (user == null) return Stream.value(null);

    return _usersCollection.doc(user.uid).snapshots().map((doc) {
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    });
  }

  // Validar email del familiar
  Future<bool> validateFamiliarEmail(String email) async {
    try {
      // Verificar que no sea el mismo email del usuario actual
      if (currentUser?.email == email) {
        return false;
      }

      // Verificar formato básico de email
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      return emailRegex.hasMatch(email);
    } catch (e) {
      print('Error validando email del familiar: $e');
      return false;
    }
  }

  // Obtener información básica para mostrar en la UI
  Future<Map<String, String>> getUserDisplayInfo() async {
    try {
      final userData = await getCurrentUserData();
      if (userData != null) {
        return {
          'nombre': userData.nombreCompleto.isNotEmpty 
              ? userData.nombreCompleto 
              : 'Usuario',
          'email': userData.email,
        };
      } else {
        // Fallback a datos de Firebase Auth
        final user = currentUser;
        return {
          'nombre': user?.displayName ?? 'Usuario',
          'email': user?.email ?? '',
        };
      }
    } catch (e) {
      print('Error obteniendo información de display: $e');
      return {
        'nombre': 'Usuario',
        'email': '',
      };
    }
  }
}
