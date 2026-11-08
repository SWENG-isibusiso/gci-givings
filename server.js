const express = require('express');
const cors = require('cors');
const axios = require('axios');
require('dotenv').config({ quiet: true });

const app = express();

// ==================== MIDDLEWARE ====================
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(express.json());

const PAYSTACK_BASE = 'https://api.paystack.co';

function paystackHeaders() {
  return {
    Authorization: `Bearer ${process.env.PAYSTACK_SECRET_KEY}`,
    'Content-Type': 'application/json',
  };
}

// ==================== ROUTES ====================

// Health check: open https://YOUR-APP.vercel.app/api/test in a browser
app.get('/api/test', (req, res) => {
  res.send('GospelLife Backend is running successfully!');
});

// Initialize a Paystack transaction
app.post('/api/paystack-initialize', async (req, res) => {
  try {
    if (!process.env.PAYSTACK_SECRET_KEY) {
      console.error('PAYSTACK_SECRET_KEY is not set');
      return res.status(500).json({ status: false, message: 'Server is not configured for payments.' });
    }

    const { email, amount, paymentProvider, phone, accountNumber, category } = req.body || {};

    const numericAmount = Number(amount);
    if (!email || !Number.isFinite(numericAmount) || numericAmount <= 0) {
      return res.status(400).json({ status: false, message: 'A valid email and amount are required.' });
    }

    const payload = {
      email,
      amount: Math.round(numericAmount * 100), // KSh -> subunit
      currency: process.env.PAYSTACK_CURRENCY || 'KES',
      metadata: {
        category,
        paymentProvider,
        phone: phone || null,
        accountNumber: accountNumber || null,
        custom_fields: [
          { display_name: 'Giving Category', variable_name: 'category', value: category },
          { display_name: 'Payment Provider', variable_name: 'payment_provider', value: paymentProvider || 'Paystack' },
        ],
      },
    };

    // Where Paystack sends the donor after paying (your hosted web app URL)
    if (process.env.PAYSTACK_CALLBACK_URL) {
      payload.callback_url = process.env.PAYSTACK_CALLBACK_URL;
    }

    const paystackResponse = await axios.post(`${PAYSTACK_BASE}/transaction/initialize`, payload, {
      headers: paystackHeaders(),
    });

    return res.status(200).json(paystackResponse.data);
  } catch (error) {
    console.error('Paystack init error:', error.response ? error.response.data : error.message);
    return res.status(500).json({
      status: false,
      message: error.response?.data?.message || 'Failed to initialize payment with Paystack.',
    });
  }
});

// Verify a transaction (the Flutter app calls this after Paystack redirects back)
app.get('/api/paystack-verify/:reference', async (req, res) => {
  try {
    const reference = encodeURIComponent(req.params.reference);
    const r = await axios.get(`${PAYSTACK_BASE}/transaction/verify/${reference}`, {
      headers: paystackHeaders(),
    });

    const paid = r.data?.status === true && r.data?.data?.status === 'success';
    return res.status(200).json({
      status: paid,
      message: paid ? 'Payment verified' : `Payment not successful (${r.data?.data?.status || 'unknown'})`,
      data: r.data?.data,
    });
  } catch (error) {
    console.error('Paystack verify error:', error.response ? error.response.data : error.message);
    return res.status(500).json({
      status: false,
      message: error.response?.data?.message || 'Failed to verify payment.',
    });
  }
});

// ==================== START SERVER ====================
// Local only; Vercel runs the exported app as a serverless function.
if (process.env.NODE_ENV !== 'production') {
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => console.log(`Server live at http://localhost:${PORT}`));
}

module.exports = app;
