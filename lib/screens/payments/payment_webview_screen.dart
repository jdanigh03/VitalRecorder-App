import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:gal/gal.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final Uri url;

  const PaymentWebViewScreen({Key? key, required this.url}) : super(key: key);

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Pasarela de Pago', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E3A5F),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Cerrar',
        ),
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.url.toString())),
            initialSettings: InAppWebViewSettings(
              useOnDownloadStart: true,
              allowsInlineMediaPlayback: true,
              javaScriptEnabled: true,
              useHybridComposition: true,
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            onLoadStart: (controller, url) {
              setState(() {
                _isLoading = true;
              });
            },
            onLoadStop: (controller, url) {
              setState(() {
                _isLoading = false;
              });
            },
            onProgressChanged: (controller, progress) {
              setState(() {
                _progress = progress / 100;
              });
            },
            // Intercepta descargas iniciadas por el usuario (ej: botón "Descargar QR")
            onDownloadStartRequest: (controller, downloadRequest) async {
              await _handleDownload(downloadRequest.url.toString());
            },
          ),
          if (_isLoading || _progress < 1.0)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
            ),
        ],
      ),
    );
  }

  Future<void> _handleDownload(String url) async {
    try {
      // Verificar permisos
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Procesando descarga...')),
      );

      Uint8List imageBytes;

      // Manejar Data URIs (Base64)
      if (url.startsWith('data:')) {
        try {
          // Formato esperado: data:image/png;base64,iVBORw0KGgoAAA...
          final split = url.split(',');
          if (split.length < 2) throw Exception('Data URI inválido');
          
          final base64String = split[1];
          imageBytes = base64Decode(base64String);
        } catch (e) {
          print('Error decodificando Base64: $e');
          throw Exception('No se pudo procesar la imagen Base64');
        }
      } else {
        // Descargar usando Dio para URLs normales (http/https)
        var response = await Dio().get(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        imageBytes = Uint8List.fromList(response.data);
      }

      // Guardar en galería
      try {
        await Gal.putImageBytes(
          imageBytes,
          name: "pago_qr_${DateTime.now().millisecondsSinceEpoch}",
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ QR guardado en galería exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('Error guardando con Gal: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('No se pudo guardar en la galería.')),
          );
        }
      }

    } catch (e) {
      print('Error downloading: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar: ${e.toString().split('\n').first}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
