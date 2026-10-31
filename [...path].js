const express = require('express');
const cors = require('cors');
const axios = require('axios');

const app = express();

// Middleware
app.use(cors({ origin: '*' }));
app.use(express.json());

// Paystack initialize route
app.post('/api/paystack-initialize', async (req, res) => {
  try {
    const { email, amount } = req.body;
    console.log('📥 Received payment initialization for:', email);

    // Call Paystack API securely using environment secret key
    const paystackResponse = await axios.post(
      'https://api.paystack.co/transaction/initialize',
      {
        email,
        amount,
      },
      {
        headers: {
          Authorization: `Bearer ${process.env.PAYSTACK_SECRET_KEY}`,
          'Content-Type': 'application/json',
        },
      }
    );

    return res.status(200).json(paystackResponse.data);
  } catch (error) {
    console.error('Paystack Error:', error.response?.data || error.message);
    return res.status(500).json({ 
      success: false, 
      error: error.response?.data || error.message 
    });
  }
});

// CRITICAL: Export app for Vercel serverless runtime (No app.listen!)
module.exports = app;