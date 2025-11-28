import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionPlan {
  final String id;
  final String name;
  final String description;
  final int additionalSlots;
  final double price;
  final double originalPrice;
  final int durationDays;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.additionalSlots,
    required this.price,
    required this.originalPrice,
    this.durationDays = 30,
    this.displayDiscountPercentage,
  });

  final int? displayDiscountPercentage;

  // Calculate discount percentage for display
  int get discountPercentage {
    if (displayDiscountPercentage != null) return displayDiscountPercentage!;
    if (originalPrice <= price) return 0;
    return ((originalPrice - price) / originalPrice * 100).round();
  }
}

class UserSubscription {
  final String? planId;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final int activeSlots;

  UserSubscription({
    this.planId,
    this.startDate,
    this.endDate,
    this.isActive = false,
    this.activeSlots = 0,
  });

  factory UserSubscription.fromFirestore(Map<String, dynamic> data) {
    final endDate = (data['end_date'] as Timestamp?)?.toDate();
    final now = DateTime.now();
    final isActive = endDate != null && endDate.isAfter(now);
    
    return UserSubscription(
      planId: data['plan_id'],
      startDate: (data['start_date'] as Timestamp?)?.toDate(),
      endDate: endDate,
      isActive: isActive,
      activeSlots: isActive ? (data['active_slots'] ?? 0) : 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'plan_id': planId,
      'start_date': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'end_date': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'active_slots': activeSlots,
    };
  }
  
  // Default free tier
  static UserSubscription free() {
    return UserSubscription(
      isActive: true,
      activeSlots: 0, // 0 additional slots, so just the default 1
    );
  }
}
