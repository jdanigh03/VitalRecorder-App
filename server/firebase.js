const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

if (!admin.apps.length) {
  try {
    const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
    if (credPath && fs.existsSync(credPath)) {
      const serviceAccount = JSON.parse(fs.readFileSync(credPath, 'utf8'));
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: process.env.FIREBASE_PROJECT_ID || serviceAccount.project_id,
      });
    } else {
      // ADC (p. ej. Cloud Run) o variables de entorno de la máquina
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
        projectId: process.env.FIREBASE_PROJECT_ID,
      });
    }
  } catch (e) {
    console.error('[FIREBASE INIT ERROR]', e.message);
  }
}

const db = admin.firestore();

module.exports = { admin, db };
