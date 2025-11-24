require('dotenv').config();
const express = require('express');
const axios = require('axios');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
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
const txMap = new Map(); // id_transaccion -> { identificador }
const txByIdent = new Map(); // identificador -> { id_transaccion }

app.get('/api/health', (_req, res) => res.json({ ok: true, now: new Date().toISOString() }));
app.get('/health', (_req, res) => res.json({ ok: true, now: new Date().toISOString() }));

// Crear deuda (cupo adicional) — usado por Flutter
app.post('/api/pagos/cupo', async (req, res) => {
  try {
    const { caregiverId, email, amount = 0.01, description = 'Cupo adicional de paciente' } = req.body || {};
    if (!caregiverId || !email || !APPKEY || !PUBLIC_BASE_URL) {
      return res.status(400).json({ error: true, mensaje: 'Faltan parámetros requeridos' });
    }

    const identificador = uuidv4();
    const payload = {
      appkey: APPKEY,
      email_cliente: email,
      identificador,
      callback_url: `${PUBLIC_BASE_URL}/api/libelula/pago-exitoso`,
      url_retorno: `${PUBLIC_BASE_URL}/return`,
      descripcion: description,
      moneda: 'BOB',
      lineas_detalle_deuda: [
        { concepto: description, cantidad: 1, costo_unitario: Number(amount), descuento_unitario: 0 }
      ],
      lineas_metadatos: [
        { nombre: 'plan', dato: 'cupo_adicional' },
        { nombre: 'cuidador_id', dato: caregiverId }
      ]
    };

    const { data } = await axios.post('https://api.libelula.bo/rest/deuda/registrar', payload, {
      headers: { 'Content-Type': 'application/json' }
    });

    if (data.error) return res.status(400).json({ error: true, mensaje: data.mensaje || 'Error Libélula' });

    txMap.set(String(data.id_transaccion), { identificador });
    txByIdent.set(String(identificador), { id_transaccion: String(data.id_transaccion) });

    await db.collection('libelulaTransactions').doc(String(data.id_transaccion)).set({
      id_transaccion: String(data.id_transaccion),
      identificador: String(identificador),
      caregiverId,
      state: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return res.json({ url: data.url_pasarela_pagos, id_transaccion: data.id_transaccion, identificador });
  } catch (err) {
    console.error('[create-debt error]', err.response?.data || err.message);
    return res.status(500).json({ error: true, mensaje: 'Error creando deuda' });
  }
});

// Callback de pago exitoso
app.get('/api/libelula/pago-exitoso', async (req, res) => {
  const { transaction_id, invoice_id, invoice_url } = req.query;
  try {
    const incoming = String(transaction_id || '');
    let identificador;
    let idTransaccion = incoming;
    let caregiverId = null;

    const byTx = txMap.get(incoming);
    if (byTx?.identificador) {
      identificador = byTx.identificador;
    } else {
      const snap = await db.collection('libelulaTransactions').doc(incoming).get();
      if (snap.exists) {
        const map = snap.data() || {};
        identificador = map.identificador;
        caregiverId = map.caregiverId || null;
      }
      if (!identificador) {
        const byIdent = txByIdent.get(incoming);
        if (byIdent?.id_transaccion) {
          identificador = incoming;
          idTransaccion = byIdent.id_transaccion;
        } else {
          const q = await db.collection('libelulaTransactions').where('identificador', '==', incoming).limit(1).get();
          if (!q.empty) {
            const doc = q.docs[0];
            identificador = incoming;
            idTransaccion = doc.id;
            caregiverId = doc.data()?.caregiverId || null;
          }
        }
      }
    }

    let pagada = false, valorTotal = null, formaPago = null;
    if (identificador) {
      const verifyPayload = { appkey: APPKEY, identificador };
      const { data } = await axios.post('https://api.libelula.bo/rest/deuda/consultar_deudas/por_identificador', verifyPayload, { headers: { 'Content-Type': 'application/json' } });
      const d = (data && Array.isArray(data.datos)) ? data.datos[0] : data;
      pagada = Boolean(d?.pagado);
      valorTotal = d?.valor_total ?? null;
      formaPago = d?.forma_pago ?? null;

      await db.collection('libelulaTransactions').doc(String(idTransaccion)).set({
        state: pagada ? 'paid' : 'processed',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      if (pagada) {
        const payRef = db.collection('payments').doc(String(idTransaccion));
        const paySnap = await payRef.get();
        if (!paySnap.exists || paySnap.data()?.status !== 'paid') {
          await payRef.set({
            transaction_id: String(idTransaccion),
            identificador: String(identificador),
            amount: valorTotal,
            currency: 'BOB',
            status: 'paid',
            method: formaPago,
            caregiverId: caregiverId,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });

          if (caregiverId) {
            const userRef = db.collection('users').doc(String(caregiverId));
            await db.runTransaction(async (tx) => {
              const doc = await tx.get(userRef);
              const data = doc.exists ? doc.data() : {};
              const add = Number(data?.additional_patient_slots || 0) + 1;
              const maxDefault = data?.max_patients_default ?? 2;
              tx.set(userRef, { additional_patient_slots: add, max_patients_default: maxDefault }, { merge: true });
            });
          }
        }
      }
    }

    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    return res.status(200).send(`
      <html><body>
        <h2>Pago procesado</h2>
        <p>transaction_id: ${idTransaccion || ''}</p>
        <p>pagado: ${String(pagada)}</p>
        <p>monto: ${valorTotal ?? ''} BOB</p>
        <p>forma_pago: ${formaPago ?? ''}</p>
        ${invoice_id ? `<p>invoice_id: ${invoice_id}</p>` : ''}
        ${invoice_url ? `<p><a href="${invoice_url}" target="_blank">Ver factura</a></p>` : ''}
      </body></html>
    `);
  } catch (err) {
    console.error('[callback error]', err.response?.data || err.message);
    return res.status(500).send('Error procesando callback');
  }
});

app.get('/return', (_req, res) => res.send('Gracias. Puedes cerrar esta pestaña.'));

// Enviar notificación push
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
