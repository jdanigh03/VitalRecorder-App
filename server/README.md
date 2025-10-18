# Backend de pagos Libélula (SoftwareApp/server)

Este servicio Node/Express registra deudas en Libélula y procesa callbacks para incrementar el cupo de pacientes del cuidador en Firebase.

## Requisitos
- Node 16+ y npm
- ngrok
- Cuenta de servicio de Firebase (JSON) o ADC configurado

## Configuración
1) Copia `.env.example` a `.env` y completa:
   - LIBELULA_APPKEY=
   - PUBLIC_BASE_URL= (tu URL https de ngrok)
   - PORT=3000
   - GOOGLE_APPLICATION_CREDENTIALS= ruta al JSON de servicio
   - FIREBASE_PROJECT_ID= opcional si usas ADC
2) Instala dependencias:
   npm install
3) Inicia en dev:
   npm run dev
4) ngrok:
   ngrok http 3000

## Rutas
- POST /api/pagos/cupo
  Body: { caregiverId, email }
  Respuesta: { url, id_transaccion, identificador }
- GET /api/libelula/pago-exitoso
  Callback de Libélula. Verifica pago, guarda en `payments/{transaction_id}` e incrementa `users/{caregiverId}.additional_patient_slots`.
- GET /api/health

## Integración Flutter
- En `lib/utils/payments_config.dart`, setea `paymentsApiBaseUrl` a tu URL de ngrok.
- El flujo UI ya abre el Paywall y solicita el cupo.
