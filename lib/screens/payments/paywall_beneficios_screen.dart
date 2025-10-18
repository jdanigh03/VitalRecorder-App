import 'package:flutter/material.dart';
import '../../services/payment_limit_service.dart';
import '../../utils/payments_config.dart';

class PaywallBeneficiosScreen extends StatefulWidget {
  const PaywallBeneficiosScreen({super.key});

  @override
  State<PaywallBeneficiosScreen> createState() => _PaywallBeneficiosScreenState();
}

class _PaywallBeneficiosScreenState extends State<PaywallBeneficiosScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _comprar() async {
    setState(() { _loading = true; _error = null; });
    try {
      await PaymentLimitService().startPurchaseFlow();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Se abrió la pasarela de pagos')),
        );
      }
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Añadir cupo de paciente'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Beneficios de añadir más pacientes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('• Gestiona más recordatorios y mejora el seguimiento.'),
            const Text('• Aumenta tu capacidad como cuidador.'),
            const Text('• Acceso a reportes por paciente adicional.'),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Desbloquear 1 cupo por ${additionalSlotPriceBs.toStringAsFixed(0)} Bs',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _comprar,
                icon: const Icon(Icons.lock_open),
                label: _loading ? const Text('Abriendo pasarela...') : const Text('Desbloquear cupo ahora'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver'),
            )
          ],
        ),
      ),
    );
  }
}
