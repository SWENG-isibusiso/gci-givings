const express = require('express');
const cors = require('cors');
const axios = require('axios');

const app = express();

// Enable CORS for all origins
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
}));

app.options('*', cors());
app.use(express.json());

app.post('/api/paystack-initialize', async (req, res) => {
  try {
    const { email, amount, paymentProvider, phone, accountNumber, category } = req.body;
    
    const paystackResponse = await axios.post(
      'https://api.paystack.co/transaction/initialize',
      {
        email,
        amount: amount * 100, // Convert to kobo/cents
        callback_url: 'https://gci-givings.vercel.app',
        metadata: { paymentProvider, phone, accountNumber, category }
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
      status: false, 
      message: error.response?.data?.message || error.message 
    });
  }
});

module.exports = app;