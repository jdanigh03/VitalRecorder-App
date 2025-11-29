import 'package:flutter/material.dart';
import '../models/subscription_plan.dart';
import '../services/subscription_service.dart';
import '../services/payment_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({Key? key}) : super(key: key);

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final PaymentService _paymentService = PaymentService();
  
  UserSubscription? _currentSubscription;
  bool _isLoading = true;
  bool _isProcessingPayment = false;

  @override
  void initState() {
    super.initState();
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    setState(() => _isLoading = true);
    try {
      // Check limits first to ensure everything is up to date
      await _subscriptionService.checkAndReconcileLimits();
      final sub = await _subscriptionService.getCurrentSubscription();
      setState(() {
        _currentSubscription = sub;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading subscription: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePurchase(SubscriptionPlan plan) async {
    setState(() => _isProcessingPayment = true);
    try {
      // 1. Get Payment URL
      final discount = plan.originalPrice - plan.price;
      
      // Generate lines for Libelula
      List<Map<String, dynamic>> lines = [];
      final basePrice = SubscriptionService.basePrice;
      
      if (plan.id == 'plan_1_person') {
        lines.add({
          'name': 'Cupo Paciente (Estándar)',
          'quantity': 1,
          'unitPrice': basePrice,
          'discount': 0.0,
        });
      } else if (plan.id == 'plan_2_people') {
        // Plan Duo: 1st full price, 2nd 20% off (6 Bs discount)
        lines.add({
          'name': 'Cupo Paciente #1 (Base)',
          'quantity': 1,
          'unitPrice': basePrice,
          'discount': 0.0,
        });
        lines.add({
          'name': 'Cupo Paciente #2 (Desc. 20%)',
          'quantity': 1,
          'unitPrice': basePrice,
          'discount': 6.0,
        });
      } else if (plan.id == 'plan_3_people') {
        // Plan Family: 1st full, 2nd full, 3rd 50% off (15 Bs discount) to reach 75 total
        lines.add({
          'name': 'Cupo Paciente #1',
          'quantity': 1,
          'unitPrice': basePrice,
          'discount': 0.0,
        });
        lines.add({
          'name': 'Cupo Paciente #2',
          'quantity': 1,
          'unitPrice': basePrice,
          'discount': 0.0,
        });
        lines.add({
          'name': 'Cupo Paciente #3 (Promoción)',
          'quantity': 1,
          'unitPrice': basePrice,
          'discount': 15.0,
        });
      }

      print('DEBUG: Generated lines for plan ${plan.id}: $lines');
      
      // We send amount as fallback, but also lines for the breakdown.
      // We rely on the backend to prioritize lines if it supports them.
      final url = await _paymentService.solicitarCupoAdicional(
        amount: plan.price, 
        discount: discount > 0 ? discount : null,
        lines: lines,
        description: 'Suscripción: ${plan.name}',
        planId: plan.id, // Send plan ID to server for webhook processing
      );

      if (url == null) {
        throw Exception('No se pudo generar el link de pago');
      }

      // 2. Open Gateway
      await _paymentService.abrirPasarela(url);

      // 3. Simulate success for now (In real app, we'd wait for webhook/callback)
      // For this implementation, we'll assume if they return from the webview, we check status or just activate
      // Since we don't have the full webhook loop here, we will optimistically activate
      // OR show a dialog asking "Did you complete the payment?"
      
      if (mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmar Pago'),
            content: const Text('¿Realizaste el pago exitosamente en la pasarela?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('No'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Sí, activar plan'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          await _subscriptionService.activateSubscription(plan.id);
          await _loadSubscription();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('¡Plan activado exitosamente!')),
            );
          }
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Planes Premium', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Background Gradient Header
                Container(
                  height: 250,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1E3A5F), Color(0xFF4A90E2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                ),
                SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        _buildCurrentStatus(),
                        const SizedBox(height: 30),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Elige tu Plan Ideal',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A5F),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Desbloquea más cupos y gestiona a todos tus pacientes sin límites.',
                                style: TextStyle(color: Colors.grey[600], fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ...SubscriptionService.plans.map((plan) => _buildPremiumPlanCard(plan)),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCurrentStatus() {
    final slots = 1 + (_currentSubscription?.activeSlots ?? 0);
    final isActive = _currentSubscription?.isActive ?? false;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TU PLAN ACTUAL',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isActive ? 'Premium Activo' : 'Plan Gratuito',
                    style: TextStyle(
                      color: isActive ? const Color(0xFF4A90E2) : Colors.black87,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF4A90E2).withOpacity(0.1) : Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isActive ? Icons.star : Icons.person_outline,
                  color: isActive ? const Color(0xFF4A90E2) : Colors.grey,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, color: Color(0xFF1E3A5F)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$slots Paciente${slots > 1 ? 's' : ''} permitidos',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                    if (isActive && _currentSubscription?.endDate != null)
                      Text(
                        'Vence: ${_formatDate(_currentSubscription!.endDate!)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumPlanCard(SubscriptionPlan plan) {
    final isCurrent = _currentSubscription?.planId == plan.id && (_currentSubscription?.isActive ?? false);
    final isRecommended = plan.id == 'plan_2_people'; // Highlight Duo as recommended

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: isRecommended 
                ? Border.all(color: const Color(0xFF4A90E2), width: 2) 
                : Border.all(color: Colors.transparent),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      plan.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                    if (plan.discountPercentage > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          'AHORRA ${plan.discountPercentage}%',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  plan.description,
                  style: TextStyle(color: Colors.grey[600], height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${plan.price.toStringAsFixed(0)} Bs',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6, left: 4),
                      child: Text(
                        '/mes',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (plan.discountPercentage > 0) ...[
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${plan.originalPrice.toStringAsFixed(0)} Bs',
                          style: const TextStyle(
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isCurrent || _isProcessingPayment 
                        ? null 
                        : () => _handlePurchase(plan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCurrent 
                          ? Colors.green 
                          : const Color(0xFF4A90E2), // Unified Premium Blue
                      foregroundColor: Colors.white, // White text enforced
                      elevation: isCurrent ? 0 : 4,
                      shadowColor: const Color(0xFF4A90E2).withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isProcessingPayment && !isCurrent
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            isCurrent ? 'Plan Actual' : 'Suscribirse Ahora',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isRecommended && !isCurrent)
          Positioned(
            top: -12,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF9966), Color(0xFFFF5E62)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                'RECOMENDADO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
