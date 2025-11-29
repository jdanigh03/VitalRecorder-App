import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/subscription_plan.dart';

class SubscriptionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Define available plans
  // Base price for 1 additional slot
  static const double basePrice = 30.0;

  // Define available plans
  static List<SubscriptionPlan> get plans => [
    SubscriptionPlan(
      id: 'plan_1_person',
      name: 'Plan Individual',
      description: 'Añade 1 paciente adicional',
      additionalSlots: 1,
      price: basePrice,
      originalPrice: basePrice,
    ),
    SubscriptionPlan(
      id: 'plan_2_people',
      name: 'Plan Duo',
      description: 'Añade 2 pacientes (2do con 20% OFF)',
      additionalSlots: 2,
      price: 54.0, // 30 + 24
      originalPrice: basePrice * 2,
      displayDiscountPercentage: 20,
    ),
    SubscriptionPlan(
      id: 'plan_3_people',
      name: 'Plan Familiar',
      description: 'Añade 3 pacientes (2do y 3ro con 25% OFF)',
      additionalSlots: 3,
      price: 75.0, // 30 + 22.5 + 22.5
      originalPrice: basePrice * 3,
      displayDiscountPercentage: 25,
    ),
  ];

  // Get current user subscription
  Future<UserSubscription> getCurrentSubscription() async {
    final user = _auth.currentUser;
    if (user == null) return UserSubscription.free();

    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      final data = doc.data();
      
      if (data != null && data.containsKey('subscription')) {
        return UserSubscription.fromFirestore(data['subscription']);
      }
    } catch (e) {
      print('Error getting subscription: $e');
    }
    
    return UserSubscription.free();
  }

  // Get total max patients allowed (Default + Subscription)
  Future<int> getMaxPatients() async {
    final sub = await getCurrentSubscription();
    // Default is 1, plus any active slots from subscription
    return 1 + sub.activeSlots;
  }

  // Activate a subscription (Called after successful payment)
  Future<void> activateSubscription(String planId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final plan = plans.firstWhere((p) => p.id == planId, orElse: () => throw Exception('Plan no encontrado'));
    
    final now = DateTime.now();
    final endDate = now.add(Duration(days: plan.durationDays));

    final subscriptionData = {
      'plan_id': plan.id,
      'start_date': Timestamp.fromDate(now),
      'end_date': Timestamp.fromDate(endDate),
      'active_slots': plan.additionalSlots,
      'updated_at': Timestamp.fromDate(now),
    };

    // Update user doc with subscription info
    await _db.collection('users').doc(user.uid).set({
      'subscription': subscriptionData,
    }, SetOptions(merge: true));

    // Add to history
    await _db.collection('users').doc(user.uid).collection('subscription_history').add({
      ...subscriptionData,
      'price_paid': plan.price,
      'action': 'purchase',
    });
  }

  // Check for expiration and reconcile limits
  Future<void> checkAndReconcileLimits() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final sub = await getCurrentSubscription();
    
    // If subscription is not active (expired or never had one), we need to check limits
    // Even if active, we should check if we are over limit (e.g. downgraded)
    
    final maxAllowed = 1 + sub.activeSlots;
    
    // Get current active patients
    // We need to find all patients where this caregiver is active
    // This is an expensive query if not optimized, similar to PaymentLimitService
    
    final allUsersSnapshot = await _db.collection('users').where('role', isEqualTo: 'user').get();
    
    List<Map<String, dynamic>> activeRelations = []; // {patientId, relationDocId, dateAdded}

    for (final userDoc in allUsersSnapshot.docs) {
      final caregiverQuery = await _db
          .collection('users')
          .doc(userDoc.id)
          .collection('cuidadores')
          .where('email', isEqualTo: user.email)
          .where('activo', isEqualTo: true)
          .get();

      for (final doc in caregiverQuery.docs) {
        activeRelations.add({
          'patientId': userDoc.id,
          'relationDocId': doc.id,
          'dateAdded': (doc.data()['fecha_creacion'] as Timestamp?)?.toDate() ?? DateTime(2000),
        });
      }
    }

    // Sort by date added (oldest first)
    // We want to keep the oldest ones (first added) and deactivate the newest ones if over limit
    // OR: Keep the ones that fit the limit. Usually you keep the first ones you added.
    activeRelations.sort((a, b) => (a['dateAdded'] as DateTime).compareTo(b['dateAdded'] as DateTime));

    if (activeRelations.length > maxAllowed) {
      // We have more active patients than allowed. Deactivate the excess.
      // The first 'maxAllowed' are safe. The rest need deactivation.
      
      final toDeactivate = activeRelations.sublist(maxAllowed);
      
      for (final relation in toDeactivate) {
        print('Deactivating patient ${relation['patientId']} due to limit reached');
        await _db
            .collection('users')
            .doc(relation['patientId'])
            .collection('cuidadores')
            .doc(relation['relationDocId'])
            .update({
              'activo': false,
              'deactivated_reason': 'subscription_limit_reached',
              'deactivated_at': Timestamp.now(),
            });
      }
    }
  }
}
