require('dotenv').config();
const express = require('express');
const axios = require('axios');
const cors = require('cors');
const { admin, db } = require('./firebase');

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3000;
const APPKEY = process.env.LIBELULA_APPKEY;
const PUBLIC_BASE_URL = process.env.PUBLIC_BASE_URL;

if (!APPKEY) console.warn('[WARN] LIBELULA_APPKEY no configurado');
if (!PUBLIC_BASE_URL) console.warn('[WARN] PUBLIC_BASE_URL no configurado');

// Mapas en memoria para compatibilidad rápida
const txMap = new Map();
const txByIdent = new Map();

app.get('/api/health', (_req, res) => res.json({ ok: true, now: new Date().toISOString() }));
app.get('/health', (_req, res) => res.json({ ok: true, now: new Date().toISOString() }));

// Crear deuda (cupo adicional o suscripción) — usado por Flutter
app.post('/api/pagos/cupo', async (req, res) => {
  try {
    const { caregiverId, email, amount = 0.01, description = 'Cupo adicional de paciente', lineas_detalle_deuda, items, lines, tipo_factura, moneda, planId } = req.body || {};
    if (!caregiverId || !email || !APPKEY || !PUBLIC_BASE_URL) {
      return res.status(400).json({ error: true, mensaje: 'Faltan parámetros requeridos' });
    }

    const finalLines = lineas_detalle_deuda || items || lines || [
      { concepto: description, cantidad: 1, costo_unitario: Number(amount), descuento_unitario: 0 }
    ];

    // Generar nuestro identificador único (como en el proyecto antiguo)
    const miIdentificador = `SUB-${caregiverId.substring(0, 8)}-${Date.now()}`;

    console.log(`[CREATE-DEBT] Creating debt for user ${caregiverId}, plan: ${planId}`);
    console.log(`[CREATE-DEBT] Our identifier: ${miIdentificador}`);

    const payload = {
      appkey: APPKEY,
      email_cliente: email,
      identificador_deuda: miIdentificador, // ← Usar identificador_deuda como en proyecto antiguo
      callback_url: `${PUBLIC_BASE_URL}/api/libelula/pago-exitoso`,
      url_retorno: `${PUBLIC_BASE_URL}/return`,
      descripcion: description,
      moneda: moneda || 'BOB',
      tipo_factura: tipo_factura,
      lineas_detalle_deuda: finalLines,
      lineas_metadatos: [
        { nombre: 'plan', dato: planId || 'cupo_adicional' },
        { nombre: 'cuidador_id', dato: caregiverId }
      ]
    };

    console.log('[CREATE-DEBT] Sending to Libélula:', JSON.stringify(payload, null, 2).substring(0, 500));

    const { data } = await axios.post('https://api.libelula.bo/rest/deuda/registrar', payload, {
      headers: { 'Content-Type': 'application/json' }
    });

    console.log('[CREATE-DEBT] Libélula response:', data);

    if (data.error) {
      console.error('[CREATE-DEBT] Libélula error:', data);
      return res.status(400).json({ error: true, mensaje: data.mensaje || 'Error Libélula' });
    }

    const libelulaTransactionId = data.id_transaccion;

    txMap.set(String(miIdentificador), { libelulaId: libelulaTransactionId });
    txByIdent.set(String(libelulaTransactionId), { ourId: miIdentificador });

    await db.collection('libelulaTransactions').doc(String(miIdentificador)).set({
      miIdentificador: String(miIdentificador),
      libelula_id_transaccion: String(libelulaTransactionId),
      caregiverId,
      planId: planId || null,
      amount: Number(amount),
      state: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log(`[CREATE-DEBT] ✅ Saved transaction. Our ID: ${miIdentificador}, Libélula ID: ${libelulaTransactionId}`);

    return res.json({ url: data.url_pasarela_pagos, id_transaccion: libelulaTransactionId, identificador: miIdentificador });
  } catch (err) {
    console.error('[CREATE-DEBT ERROR]', err.response?.data || err.message);
    return res.status(500).json({ error: true, mensaje: 'Error creando deuda' });
  }
});

// Callback de pago exitoso (como en el proyecto antiguo)
app.get('/api/libelula/pago-exitoso', async (req, res) => {
  const callbackData = req.method === 'POST' ? req.body : req.query;
  const miIdentificadorRecibido = callbackData.id_transaccion || callbackData.transaction_id;

  console.log('========================================');
  console.log('[WEBHOOK] 🎯 LIBÉLULA CALLBACK RECEIVED!');
  console.log(`[WEBHOOK] Our identifier received: ${miIdentificadorRecibido}`);
  console.log('[WEBHOOK] Full callback data:', JSON.stringify(callbackData, null, 2));
  console.log('========================================');

  if (!miIdentificadorRecibido) {
    console.error('[WEBHOOK] ❌ No transaction_id received');
    return res.status(400).send('Falta transaction_id');
  }

  try {
    const pagoExitoso = callbackData.error === '0' || callbackData.error === 0;
    let nuevoEstado = 'pending';
    let metodoPago = null;
    let invoiceUrl = null;

    if (pagoExitoso) {
      nuevoEstado = 'paid';
      metodoPago = callbackData.payment_method || callbackData.forma_pago || 'Libélula';

      if (callbackData.facturas_electronicas && callbackData.facturas_electronicas.length > 0) {
        invoiceUrl = callbackData.facturas_electronicas[0]?.url || null;
      } else if (callbackData.invoice_url) {
        invoiceUrl = callbackData.invoice_url;
      }

      console.log(`[WEBHOOK] ✅ Payment successful!`);
      console.log(`[WEBHOOK] Payment method: ${metodoPago}`);
      console.log(`[WEBHOOK] Invoice URL: ${invoiceUrl || 'N/A'}`);
    } else {
      nuevoEstado = 'failed';
      console.log(`[WEBHOOK] ❌ Payment failed. Error code: ${callbackData.error}`);
    }

    console.log(`[WEBHOOK] Searching for transaction: ${miIdentificadorRecibido}`);

    const txDoc = await db.collection('libelulaTransactions').doc(String(miIdentificadorRecibido)).get();

    if (!txDoc.exists) {
      console.error(`[WEBHOOK] ⚠️ Transaction not found: ${miIdentificadorRecibido}`);
      return res.status(404).send('Transaction not found');
    }

    const txData = txDoc.data();
    console.log('[WEBHOOK] Transaction found:', txData);

    const { caregiverId, planId, amount } = txData;

    await db.collection('libelulaTransactions').doc(String(miIdentificadorRecibido)).set({
      state: nuevoEstado,
      payment_method: metodoPago,
      invoice_url: invoiceUrl,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      callback_data: callbackData,
    }, { merge: true });

    console.log(`[WEBHOOK] Updated transaction state to: ${nuevoEstado}`);

    if (pagoExitoso && caregiverId) {
      console.log(`[WEBHOOK] Processing successful payment for user: ${caregiverId}`);

      const payRef = db.collection('payments').doc(String(miIdentificadorRecibido));
      const paySnap = await payRef.get();

      if (!paySnap.exists || paySnap.data()?.status !== 'paid') {
        await payRef.set({
          transaction_id: String(miIdentificadorRecibido),
          libelula_id: txData.libelula_id_transaccion,
          amount: amount,
          currency: 'BOB',
          status: 'paid',
          method: metodoPago,
          caregiverId: caregiverId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        console.log('[WEBHOOK] ✅ Created payment record');
      }

      if (planId && (planId.startsWith('plan_') || ['plan_1_person', 'plan_2_people', 'plan_3_people'].includes(planId))) {
        console.log(`[WEBHOOK] 🎯 SUBSCRIPTION purchase detected: ${planId}`);

        const planSlotsMap = {
          'plan_1_person': 1,
          'plan_2_people': 2,
          'plan_3_people': 3,
        };

        const additionalSlots = planSlotsMap[planId] || 1;
        const now = admin.firestore.Timestamp.now();
        const endDate = admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
        );

        const subscriptionData = {
          plan_id: planId,
          start_date: now,
          end_date: endDate,
          active_slots: additionalSlots,
          updated_at: now,
        };

        console.log('[WEBHOOK] Subscription data:', subscriptionData);

        const userRef = db.collection('users').doc(String(caregiverId));

        await userRef.set({
          subscription: subscriptionData,
        }, { merge: true });

        console.log('[WEBHOOK] ✅ Updated user subscription field');

        const historyRef = await userRef.collection('subscription_history').add({
          ...subscriptionData,
          price_paid: amount || 0,
          action: 'purchase',
          transaction_id: miIdentificadorRecibido,
        });

        console.log(`[WEBHOOK] ✅ Added to subscription_history: ${historyRef.id}`);
        console.log(`[SUBSCRIPTION] ✅✅✅ SUCCESS! Activated ${planId} for user ${caregiverId}`);
        console.log(`[SUBSCRIPTION] ${additionalSlots} slots active until ${endDate.toDate()}`);
      } else {
        console.log('[WEBHOOK] 📦 Legacy payment');
        const userRef = db.collection('users').doc(String(caregiverId));
        await db.runTransaction(async (tx) => {
          const doc = await tx.get(userRef);
          const data = doc.exists ? doc.data() : {};
          const add = Number(data?.additional_patient_slots || 0) + 1;
          const maxDefault = data?.max_patients_default ?? 2;
          tx.set(userRef, { additional_patient_slots: add, max_patients_default: maxDefault }, { merge: true });
        });
        console.log(`[LEGACY] Added 1 slot to user ${caregiverId}`);
      }
    } else if (!pagoExitoso) {
      console.log('[WEBHOOK] Payment failed, no user updates performed');
    } else {
      console.log('[WEBHOOK] ⚠️ No caregiverId found');
    }

    console.log('========================================');
    console.log('[WEBHOOK] ✅ Callback processed successfully');
    console.log('========================================');

    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    return res.status(200).send(`
      <html><body>
        <h2>Pago ${pagoExitoso ? 'Exitoso' : 'Fallido'}</h2>
        <p>ID: ${miIdentificadorRecibido}</p>
        <p>Estado: ${nuevoEstado}</p>
        <p>Método: ${metodoPago || 'N/A'}</p>
        ${planId ? `<p>Plan: ${planId}</p>` : ''}
        ${invoiceUrl ? `<p><a href="${invoiceUrl}" target="_blank">Ver factura</a></p>` : ''}
      </body></html>
    `);
  } catch (err) {
    console.error('[WEBHOOK ERROR] ❌❌❌', err.message);
    console.error('[WEBHOOK ERROR] Stack:', err.stack);
    return res.status(500).send('Error procesando callback');
  }
});

app.post('/api/libelula/pago-exitoso', async (req, res) => {
  return app._router.handle({ ...req, method: 'GET' }, res);
});

app.get('/return', (_req, res) => res.send('Gracias. Puedes cerrar esta pestaña.'));

app.post('/api/notifications/send', async (req, res) => {
  try {
    const { userId, title, body, data } = req.body;
    if (!userId || !title || !body) {
      return res.status(400).json({ error: true, mensaje: 'Faltan parámetros' });
    }

    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return res.status(404).json({ error: true, mensaje: 'Usuario no encontrado' });
    }

    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;

    if (!fcmToken) {
      return res.status(400).json({ error: true, mensaje: 'Usuario sin token FCM' });
    }

    const message = {
      notification: {
        title,
        body,
      },
      data: data || {},
      token: fcmToken,
    };

    await admin.messaging().send(message);
    return res.json({ success: true });
  } catch (e) {
    console.error('Error enviando notificación:', e);
    return res.status(500).json({ error: true, mensaje: e.message });
  }
});

app.listen(PORT, () => console.log(`Payments server listening on http://localhost:${PORT}`));
