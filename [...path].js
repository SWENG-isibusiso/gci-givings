const express = require('express');
const cors = require('cors');
const axios = require('axios');
require('dotenv').config({ quiet: true });

const app = express();


app.use(cors({
  origin: '*', // Allow requests from any origin
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'], // Allow only GET and POST methods
  allowedHeaders: ['Content-Type', 'Authorization'], // Allow only specific
}))

// ==================== MIDDLEWARE ====================
app.use(cors());
app.use(express.json());

// ==================== ROUTES ====================

// 1. Health Check Route (Use this to test http://localhost:3000 in your browser)
app.get('/api/test', (req, res) => {
  res.send('🚀 GospelLife Backend is running successfully!');
});

// 2. Main Paystack Initialization Endpoint
app.post('/api/paystack-initialize', async (req, res) => {
  try {
    const { email, amount, paymentProvider, phone, accountNumber, category } = req.body;

    console.log(`\n📥 Received Payment Request:`);
    console.log(`   - Category: ${category}`);
    console.log(`   - Amount: KSh ${amount}`);
    console.log(`   - Email: ${email}`);

    // Build payload for Paystack API
    const payload = {
      email: email,
      amount: Math.round(amount * 100), // Convert KSh to cents/subunits
      metadata: {
        category: category,
        paymentProvider: paymentProvider,
        phone: phone || null,
        accountNumber: accountNumber || null,
        custom_fields: [
          {
            display_name: 'Giving Category',
            variable_name: 'category',
            value: category,
          },
          {
            display_name: 'Payment Provider',
            variable_name: 'payment_provider',
            value: paymentProvider || 'Paystack',
          },
        ],
      },
    };

    // Call Paystack API using Axios
    const paystackResponse = await axios.post(
      'https://api.paystack.co/transaction/initialize',
      payload,
      {
        headers: {
          Authorization: `Bearer ${process.env.PAYSTACK_SECRET_KEY}`,
          'Content-Type': 'application/json',
        },
      }
    );

    console.log('✅ Paystack Authorization URL Generated Successfully!');
    return res.status(200).json(paystackResponse.data);

  } catch (error) {
    const errorMessage = error.response ? error.response.data : error.message;
    console.error('❌ Paystack Error:', errorMessage);

    return res.status(500).json({
      status: false,
      message: error.response?.data?.message || 'Failed to initialize payment with Paystack.',
    });
  }
});

// ==================== START SERVER ====================
// Only run app.listen locally (Vercel handles this automatically)
if (process.env.NODE_ENV !== 'production') {
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => {
    console.log(`🚀 Paystack Server live at http://localhost:${PORT}`);
  });
}

// CRITICAL: This allows Vercel to run your Express app as a serverless function
module.exports = app;