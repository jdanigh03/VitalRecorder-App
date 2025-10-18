import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'payment_service.dart';

class PaymentLimitService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Retorna true si el cuidador puede aceptar más pacientes según su límite efectivo
  Future<bool> canAcceptMorePatients() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    // Leer slots del usuario
    final doc = await _db.collection('users').doc(user.uid).get();
    final data = doc.data() ?? {};
    final additional = (data['additional_patient_slots'] ?? 0) as int;
    final maxDefault = (data['max_patients_default'] ?? 2) as int;
    final limit = maxDefault + additional;

    // Contar pacientes asignados: subcolección de cuidadores en todos los pacientes
    // Simplificación: contamos entradas activas en subcolección de los pacientes del sistema que referencien el email del cuidador actual
    // Si tienes una colección dedicada a relaciones, usa esa para performance.
    final allUsersSnapshot = await _db.collection('users').where('role', isEqualTo: 'user').get();
    int count = 0;
    for (final userDoc in allUsersSnapshot.docs) {
      final snap = await _db
          .collection('users')
          .doc(userDoc.id)
          .collection('cuidadores')
          .where('email', isEqualTo: _auth.currentUser?.email)
          .where('activo', isEqualTo: true)
          .get();
      if (snap.docs.isNotEmpty) count++;
      if (count >= limit) break;
    }

    return count < limit;
  }

  /// Inicia el flujo de compra (crea deuda y abre pasarela)
  Future<void> startPurchaseFlow() async {
    final svc = PaymentService();
    final url = await svc.solicitarCupoAdicional();
    if (url != null) {
      await svc.abrirPasarela(url);
    } else {
      throw Exception('No se recibió URL de pasarela');
    }
  }
}
