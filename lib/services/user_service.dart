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

  // Obtener datos de cualquier usuario por su ID
  Future<UserModel?> getUserData(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error obteniendo datos del usuario por ID: $e');
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

  // Validar lista de emails familiares
  Future<Map<String, dynamic>> validateFamiliarEmails(List<String> emails) async {
    try {
      List<String> validEmails = [];
      List<String> invalidEmails = [];
      String? currentUserEmail = currentUser?.email;
      
      for (String email in emails) {
        if (email.trim().isEmpty) continue;
        
        // Verificar que no sea el mismo email del usuario actual
        if (currentUserEmail != null && currentUserEmail == email.trim()) {
          invalidEmails.add('$email (es tu propio email)');
          continue;
        }
        
        // Verificar formato básico de email
        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
        if (emailRegex.hasMatch(email.trim())) {
          validEmails.add(email.trim());
        } else {
          invalidEmails.add('$email (formato inválido)');
        }
      }
      
      return {
        'valid': validEmails,
        'invalid': invalidEmails,
        'isValid': invalidEmails.isEmpty,
      };
    } catch (e) {
      print('Error validando emails de familiares: $e');
      return {
        'valid': <String>[],
        'invalid': ['Error de validación'],
        'isValid': false,
      };
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
          'role': userData.role,
        };
      } else {
        // Fallback a datos de Firebase Auth
        final user = currentUser;
        return {
          'nombre': user?.displayName ?? 'Usuario',
          'email': user?.email ?? '',
          'role': 'user', // default role
        };
      }
    } catch (e) {
      print('Error obteniendo información de display: $e');
      return {
        'nombre': 'Usuario',
        'email': '',
        'role': 'user',
      };
    }
  }

  // Verificar si el usuario actual es paciente
  Future<bool> isPatient() async {
    try {
      final userData = await getCurrentUserData();
      return userData?.role == 'user' || userData?.role == 'patient';
    } catch (e) {
      print('Error verificando si es paciente: $e');
      return true; // default to patient
    }
  }

  // Verificar si el usuario actual es cuidador
  Future<bool> isCaregiver() async {
    try {
      final userData = await getCurrentUserData();
      return userData?.role == 'cuidador';
    } catch (e) {
      print('Error verificando si es cuidador: $e');
      return false;
    }
  }

  // Obtener rol del usuario actual
  Future<String> getUserRole() async {
    try {
      final userData = await getCurrentUserData();
      return userData?.role ?? 'user';
    } catch (e) {
      print('Error obteniendo rol del usuario: $e');
      return 'user';
    }
  }

  // Actualizar rol del usuario
  Future<bool> updateUserRole(String newRole) async {
    try {
      final user = currentUser;
      if (user == null) return false;

      await _usersCollection.doc(user.uid).update({
        'role': newRole,
      });
      return true;
    } catch (e) {
      print('Error actualizando rol del usuario: $e');
      return false;
    }
  }
}
