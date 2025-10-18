import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../utils/payments_config.dart';

class PaymentService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Uri?> solicitarCupoAdicional() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');
    if (paymentsApiBaseUrl.isEmpty) {
      throw Exception('Configura paymentsApiBaseUrl en payments_config.dart');
    }

    final body = jsonEncode({
      'caregiverId': user.uid,
      'email': user.email,
    });

    final resp = await http.post(
      Uri.parse('$paymentsApiBaseUrl/api/pagos/cupo'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (resp.statusCode != 200) {
      throw Exception('Error creando deuda: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final url = data['url'] as String?;
    if (url == null) return null;
    return Uri.parse(url);
  }

  Future<void> abrirPasarela(Uri url) async {
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok) throw Exception('No se pudo abrir la pasarela de pagos');
  }
}
