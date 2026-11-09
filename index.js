const express = require('express');
const cors = require('cors');
const axios = require('axios');
const crypto = require('crypto');
require('dotenv').config({ quiet: true });

const app = express();

// ==================== MIDDLEWARE ====================
// Phones (Android/iOS apps) don't use CORS; this only matters for the web version.
// Optional: set ALLOWED_ORIGINS="https://your-web-app.com" in Vercel to lock it down.
const allowedOrigins = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

app.use(cors({
  origin: allowedOrigins.length ? allowedOrigins : '*',
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// Keep the raw body: Paystack webhook signatures are computed over the exact raw bytes.
app.use(express.json({
  limit: '100kb',
  verify: (req, res, buf) => { req.rawBody = buf; },
}));

const PAYSTACK_BASE = 'https://api.paystack.co';
const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

function paystackHeaders() {
  return {
    Authorization: `Bearer ${process.env.PAYSTACK_SECRET_KEY}`,
    'Content-Type': 'application/json',
  };
}

const clip = (v, max) => (typeof v === 'string' ? v.trim().slice(0, max) : undefined);

// M-Pesa / Airtel -> show Paystack's mobile money screen.
// Bank -> don't restrict, so Paystack shows every method enabled on your account.
function channelsFor(provider) {
  if (provider === 'M-Pesa' || provider === 'Airtel Money') return ['mobile_money'];
  return undefined;
}

// ==================== OPTIONAL: FIRESTORE (webhook records payments even if the app is closed) ====================
let _db; // undefined = not tried yet, null = not configured
let _admin;
function getDb() {
  if (_db !== undefined) return _db;
  _db = null;
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!raw) return _db;
  try {
    _admin = require('firebase-admin');
    const cred = JSON.parse(raw);
    if (cred.private_key) cred.private_key = cred.private_key.replace(/\\n/g, '\n');
    if (!_admin.apps.length) _admin.initializeApp({ credential: _admin.credential.cert(cred) });
    _db = _admin.firestore();
  } catch (e) {
    console.error('Firebase admin setup failed:', e.message);
    _db = null;
  }
  return _db;
}

async function recordSuccessfulCharge(d) {
  const db = getDb();
  if (!db) {
    console.log('charge.success received for', d.reference, '(Firestore not configured, nothing saved)');
    return;
  }
  const meta = d.metadata && typeof d.metadata === 'object' ? d.metadata : {};
  await db.collection('contributions').doc(String(d.reference)).set({
    status: 'success',
    paymentReference: String(d.reference),
    amount: typeof d.amount === 'number' ? d.amount / 100 : null,
    currency: d.currency || null,
    channel: d.channel || null,
    email: d.customer?.email || null,
    donorName: meta.donorName || null,
    category: meta.category || null,
    paymentProvider: meta.paymentProvider || null,
    paidAt: d.paid_at || null,
    verifiedAt: _admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}

// ==================== ROUTES ====================

app.get('/', (req, res) => {
  res.json({ status: true, message: 'GospelLife Giving API is running' });
});

app.get('/api/test', (req, res) => {
  res.send('GospelLife Backend is running successfully!');
});

// Start a Paystack transaction
app.post('/api/paystack-initialize', async (req, res) => {
  try {
    if (!process.env.PAYSTACK_SECRET_KEY) {
      console.error('PAYSTACK_SECRET_KEY is not set');
      return res.status(500).json({ status: false, message: 'Payments are not set up on the server yet.' });
    }

    const body = req.body || {};
    const email = clip(body.email, 120);
    const amount = Number(body.amount);
    const category = clip(body.category, 60);
    const paymentProvider = clip(body.paymentProvider, 30);
    const donorName = clip(body.donorName, 80);
    const phone = clip(body.phone, 20);

    if (!email || !EMAIL_RE.test(email)) {
      return res.status(400).json({ status: false, message: 'A valid email address is required.' });
    }
    if (!Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({ status: false, message: 'A valid amount is required.' });
    }

    const payload = {
      email,
      amount: Math.round(amount * 100), // KSh -> cents (Paystack uses the smallest unit)
      currency: process.env.PAYSTACK_CURRENCY || 'KES',
      metadata: {
        category,
        paymentProvider,
        donorName,
        phone: phone || null,
        custom_fields: [
          { display_name: 'Giving Category', variable_name: 'category', value: category || '-' },
          { display_name: 'Payment Provider', variable_name: 'payment_provider', value: paymentProvider || 'Paystack' },
        ],
      },
    };

    const channels = channelsFor(paymentProvider);
    if (channels) payload.channels = channels;

    // Where Paystack sends the donor after paying (only useful for the web version)
    if (process.env.PAYSTACK_CALLBACK_URL) payload.callback_url = process.env.PAYSTACK_CALLBACK_URL;

    const r = await axios.post(`${PAYSTACK_BASE}/transaction/initialize`, payload, {
      headers: paystackHeaders(),
      timeout: 20000,
    });
    return res.status(200).json(r.data);
  } catch (error) {
    console.error('Paystack init error:', error.response ? error.response.data : error.message);
    return res.status(500).json({
      status: false,
      message: error.response?.data?.message || 'Could not start the payment. Please try again.',
    });
  }
});

// Check a transaction. Always trust THIS (server-to-Paystack), never the app's own "success".
// state: success | failed | pending | error
app.get('/api/paystack-verify/:reference', async (req, res) => {
  try {
    const reference = encodeURIComponent(req.params.reference);
    const r = await axios.get(`${PAYSTACK_BASE}/transaction/verify/${reference}`, {
      headers: paystackHeaders(),
      timeout: 20000,
    });

    const txStatus = r.data?.data?.status;
    let state = 'pending';
    if (r.data?.status === true && txStatus === 'success') state = 'success';
    else if (txStatus === 'failed' || txStatus === 'reversed') state = 'failed';

    return res.status(200).json({
      status: state === 'success',
      state,
      message: state === 'success' ? 'Payment verified' : `Payment not completed (${txStatus || 'unknown'})`,
      data: r.data?.data,
    });
  } catch (error) {
    const code = error.response?.status;
    console.error('Paystack verify error:', error.response ? error.response.data : error.message);
    if (code === 400 || code === 404) {
      // Paystack doesn't know this reference (yet)
      return res.status(404).json({ status: false, state: 'pending', message: 'Transaction not found yet.' });
    }
    return res.status(502).json({ status: false, state: 'error', message: 'Could not verify the payment right now.' });
  }
});

// Paystack calls this itself when a payment succeeds, even if the donor closed the app.
// Dashboard -> Settings -> API Keys & Webhooks -> Live/Test Webhook URL:
//   https://YOUR-API.vercel.app/api/paystack-webhook
app.post('/api/paystack-webhook', async (req, res) => {
  const secret = process.env.PAYSTACK_SECRET_KEY;
  const signature = req.get('x-paystack-signature');
  if (!secret || !signature || !req.rawBody) return res.sendStatus(401);

  const expected = crypto.createHmac('sha512', secret).update(req.rawBody).digest('hex');
  const a = Buffer.from(expected);
  const b = Buffer.from(String(signature));
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return res.sendStatus(401);

  try {
    const event = req.body || {};
    if (event.event === 'charge.success') await recordSuccessfulCharge(event.data || {});
    return res.sendStatus(200);
  } catch (e) {
    console.error('Webhook processing error:', e.message);
    return res.sendStatus(500); // Paystack will retry
  }
});

// ==================== FALLBACKS ====================
app.use((req, res) => {
  res.status(404).json({ status: false, message: 'Not found' });
});

app.use((err, req, res, next) => {
  console.error('Unhandled error:', err.message);
  const code = err.status && err.status >= 400 && err.status < 500 ? err.status : 500;
  res.status(code).json({ status: false, message: code === 500 ? 'Server error' : 'Bad request' });
});

// ==================== START ====================
// Local only; Vercel runs the exported app itself.
if (process.env.NODE_ENV !== 'production' && !process.env.VERCEL) {
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => console.log(`Server live at http://localhost:${PORT}`));
}

module.exports = app;
