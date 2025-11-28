import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../utils/payments_config.dart';

class PaymentService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Uri?> solicitarCupoAdicional({double? amount, double? discount, List<Map<String, dynamic>>? lines, String? description}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');
    if (paymentsApiBaseUrl.isEmpty) {
      throw Exception('Configura paymentsApiBaseUrl en payments_config.dart');
    }

    final Map<String, dynamic> requestData = {
      'caregiverId': user.uid,
      'email': user.email,
      'description': description,
      'tipo_factura': '3', // Request detailed invoice
      'moneda': 'BOB',
    };

    if (amount != null) requestData['amount'] = amount;
    if (discount != null) requestData['discount'] = discount;
    
    if (lines != null) {
      final mappedLines = lines.map((l) => {
        'concepto': l['name'],
        'cantidad': l['quantity'],
        'costo_unitario': l['unitPrice'],
        'descuento_unitario': l['discount'],
        'codigo_producto': 'SUSC-001',
        'unidad_medida': 'UNIDAD'
      }).toList();

      // Send in multiple formats to ensure backend picks it up
      requestData['lineas_detalle_deuda'] = mappedLines;
      requestData['items'] = mappedLines; // Common alias
      requestData['lines'] = mappedLines; // Common alias
    }

    final body = jsonEncode(requestData);

    print('DEBUG: ----------------------------------------');
    print('DEBUG: PAYMENT REQUEST BODY (VERSION 3):');
    print(const JsonEncoder.withIndent('  ').convert(requestData));
    print('DEBUG: ----------------------------------------');

    final resp = await http.post(
      Uri.parse('$paymentsApiBaseUrl/api/pagos/cupo'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    
    print('DEBUG: PAYMENT RESPONSE: ${resp.body}');

    if (resp.statusCode != 200) {
      throw Exception('Error creando deuda: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final url = data['url'] as String?;
    if (url == null) return null;
    return Uri.parse(url);
  }

  Future<void> abrirPasarela(Uri url) async {
    // Usamos inAppWebView para abrir el enlace dentro de la aplicación
    final ok = await launchUrl(
      url, 
      mode: LaunchMode.inAppWebView,
      webViewConfiguration: const WebViewConfiguration(
        enableJavaScript: true,
        enableDomStorage: true,
      ),
    );
    if (!ok) throw Exception('No se pudo abrir la pasarela de pagos');
  }
}
