# Pagos Libélula en SoftwareApp (Flutter + Firebase)

Guía específica para integrar pagos de Libélula en SoftwareApp: cobrar 30 Bs por cupo adicional de paciente, usar ngrok como intermediario de callbacks y persistir en Firebase.


## Contexto de SoftwareApp
- App: Flutter (carpeta `SoftwareApp/`)
- Estado/datos: Firebase (Firestore)
- Backend: no existe uno propio; usaremos un microservicio Node/Express local con ngrok para callbacks de Libélula. En producción, se puede desplegar a Cloud Run/Functions.


## Flujo resumido
1) La app solicita un cupo adicional (30 Bs).
2) El microservicio registra la deuda en Libélula y retorna `url_pasarela_pagos`.
3) La app abre esa URL (WebView o navegador).
4) Libélula hace GET al `callback_url` del microservicio (`/api/libelula/pago-exitoso`).
5) El microservicio verifica pago y escribe en Firestore: `payments/{transaction_id}` y suma +1 slot al cuidador.
6) La app detecta el cambio en Firestore y actualiza el límite efectivo.


## Estructura de datos en Firestore
- `caregivers/{caregiverId}`
  - `additional_patient_slots`: number (default 0)
  - `current_patients_count`: number (maintenerlo actualizado)
  - `max_patients_default`: number (2)
  - `limit_effective` = `max_patients_default` + `additional_patient_slots` (se puede calcular en cliente)
- `payments/{transaction_id}`
  - `caregiverId`, `amount`, `currency` ("BOB"), `status` ("paid"|"pending"|"failed"), `method`, `identificador`, `invoice_id`, `invoice_url`, `createdAt`
- `libelulaTransactions/{transaction_id}` (opcional)
  - `identificador`, `caregiverId`, `createdAt`, `state`: "pending"|"paid"|"failed"


## Lógica de negocio (límite de pacientes)
- Por defecto: 2 pacientes por cuidador.
- Cada pago exitoso de 30 Bs otorga +1 `additional_patient_slots`.
- Validar antes de asignar paciente:
  - `puedeAgregar = current_patients_count < (2 + additional_patient_slots)`
  - Si no puede, mostrar Paywall/Beneficios y CTA para pagar.


## Microservicio Node/Express + ngrok (intermediario)
- Variables de entorno:
  - `LIBELULA_APPKEY` (pruebas/producción)
  - `PUBLIC_BASE_URL` (en dev: URL https de ngrok; en prod: dominio público)
  - Firebase Admin: `GOOGLE_APPLICATION_CREDENTIALS` o cargar JSON de servicio.

- Endpoints:
  - `POST /api/pagos/cupo` → registra deuda (30 Bs) y retorna `{ url, id_transaccion, identificador }`
  - `GET /api/libelula/pago-exitoso` → verifica y escribe en Firestore, suma +1 slot, redirige a `/pagos/exito`

- Registrar Deuda (payload tipo):
```bash path=null start=null
curl -X POST https://api.libelula.bo/rest/deuda/registrar \
  -H 'Content-Type: application/json' \
  -d '{
    "appkey": "{{LIBELULA_APPKEY}}",
    "email_cliente": "cliente@example.com",
    "identificador": "{{UUID_INTENCION}}",
    "callback_url": "{{PUBLIC_BASE_URL}}/api/libelula/pago-exitoso",
    "url_retorno": "{{PUBLIC_BASE_URL}}/pagos/exito",
    "descripcion": "Desbloqueo de cupo para paciente adicional",
    "moneda": "BOB",
    "lineas_detalle_deuda": [
      { "concepto": "Cupo adicional de paciente (cuidador)", "cantidad": 1, "costo_unitario": 30, "descuento_unitario": 0 }
    ],
    "lineas_metadatos": [
      { "nombre": "plan", "dato": "cupo_adicional" },
      { "nombre": "cuidador_id", "dato": "{{CUIDADOR_ID}}" }
    ]
  }'
```

- Verificación de pago: usar `POST https://api.libelula.bo/rest/deuda/consultar_deudas/por_identificador` con `{ appkey, identificador }` y confirmar `pagado: true`.


## Integración en Flutter

### Servicio de pagos (lib/services/payment_service.dart)
- Responsabilidades: pedir URL de pago al microservicio y abrirla; escuchar Firestore para reflejar cambios de cupos.

```dart path=null start=null
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class PaymentService {
  final FirebaseFirestore _db;
  final String baseApiUrl; // p.ej. https://<subdominio>.ngrok.app

  PaymentService(this._db, {required this.baseApiUrl});

  Future<Uri?> solicitarCupoAdicional({
    required String caregiverId,
    required String emailCliente,
  }) async {
    final resp = await http.post(
      Uri.parse('$baseApiUrl/api/pagos/cupo'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'caregiverId': caregiverId,
        'email': emailCliente,
      }),
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final url = data['url'] as String?;
      if (url != null) return Uri.parse(url);
    }
    return null;
  }

  Future<void> abrirPasarela(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('No se pudo abrir la pasarela de pagos');
    }
  }
}
```

### Pantallas/UX
- Paywall/Beneficios (`lib/screens/payments/paywall_beneficios_screen.dart`): muestra beneficios y CTA.
- Procesando (`lib/screens/payments/pago_procesando_screen.dart`): explica que puede demorar.
- Éxito (`lib/screens/payments/pago_exito_screen.dart`): confirma +1 cupo, botón “Añadir paciente”.


### Validación de límite antes de asignar paciente
- En `PacienteService` o en la capa de UI antes de llamar a `asignarCuidador`:
```dart path=null start=null
Future<bool> puedeAgregarPaciente(String caregiverId) async {
  final doc = await FirebaseFirestore.instance
      .collection('caregivers')
      .doc(caregiverId)
      .get();
  final data = doc.data() ?? {};
  final current = (data['current_patients_count'] ?? 0) as int;
  final addSlots = (data['additional_patient_slots'] ?? 0) as int;
  final maxDefault = (data['max_patients_default'] ?? 2) as int;
  final limit = maxDefault + addSlots;
  return current < limit;
}
```
- Si retorna `false`, navegar al Paywall y disparar el flujo de pago.


## Puesta en marcha (dev)
1) Crear microservicio Node/Express con endpoints mencionados; configurar Firebase Admin.
2) Ejecutar `ngrok http 3000` y exportar `PUBLIC_BASE_URL` con esa URL https.
3) En Flutter, setear `baseApiUrl` al dominio de ngrok.
4) Probar un pago con cuenta de prueba; verificar que Firestore se actualiza y la app refleja el nuevo límite.


## Producción
- Desplegar el microservicio a Cloud Run/Functions con HTTPS público.
- Actualizar `PUBLIC_BASE_URL` en el servicio.
- Usar `LIBELULA_APPKEY` de producción.


## Plan accionable para SoftwareApp
1) Backend
   - Implementar microservicio con: `/api/pagos/cupo` y `/api/libelula/pago-exitoso` (ver guía general en `docs/pagos-libelula.md`).
   - Persistir `transaction_id → identificador → caregiverId` para verificación e idempotencia.
   - Job de conciliación diario vía `/rest/deuda/consultar_pagos`.
2) Flutter
   - Crear `lib/services/payment_service.dart` y configurar `baseApiUrl`.
   - Añadir Paywall/Procesando/Éxito bajo `lib/screens/payments/`.
   - Integrar validación de límite antes de asignar paciente.
   - Mostrar contador `x / (2 + additional_patient_slots)` en UI de pacientes/cuidador.
3) Firebase
   - Asegurar campos en `caregivers` y `payments` como arriba.
   - Reglas: sólo backend puede incrementar `additional_patient_slots`.
4) QA
   - Pruebas E2E con distintos canales de pago.
   - Verificar reintentos de callback (idempotencia) y conciliación.


## Referencias Libélula (v2.145)
- Registrar deuda: POST `https://api.libelula.bo/rest/deuda/registrar`
- Pago exitoso (tu backend): GET `/api/libelula/pago-exitoso?transaction_id=...`
- Consultar pagos: POST `https://api.libelula.bo/rest/deuda/consultar_pagos`
- Consultar deudas por identificador: POST `https://api.libelula.bo/rest/deuda/consultar_deudas/por_identificador`
- Moneda: ISO 4217 → usar BOB (Bs)
