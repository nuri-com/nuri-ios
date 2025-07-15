const express = require('express');
const bodyParser = require('body-parser');
const fetch = require('node-fetch');
const dotenv = require('dotenv');
const crypto = require('crypto');

dotenv.config();

const app = express();
const port = 3001;

// Logging middleware
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  if (req.body && Object.keys(req.body).length > 0) {
    const bodyCopy = { ...req.body };
    if (bodyCopy.apiKey) bodyCopy.apiKey = '***HIDDEN***';
    console.log('Request body:', JSON.stringify(bodyCopy, null, 2));
  }
  next();
});

app.use(bodyParser.json());
app.use(express.static('public'));

// API configuration
const STRIGA_API_BASE = 'https://www.sandbox.striga.com/api/v1';
const API_KEY = '_TbS1cXGStMmYBJtcoYSA7we2lQUky_6TMo-aGLvWJM=';
const API_SECRET = '43jBa65VEoLC5O4O48pDruayz5Q43IlhgyGbkYPcMHE=';

// Helper function to generate HMAC signature for Striga API
function generateSignature(timestamp, method, path, bodyString = '') {
  // Calculate MD5 hash of body
  const bodyHash = bodyString ? crypto.createHash('md5').update(bodyString).digest('hex') : '';
  
  // Create string to sign: timestamp + method + path + MD5(body)
  // IMPORTANT: path should NOT include /api/v1 prefix
  const stringToSign = timestamp + method + path + bodyHash;
  console.log('String to sign:', stringToSign);
  
  // Generate HMAC signature using API secret (NOT base64 decoded)
  const signature = crypto
    .createHmac('sha256', API_SECRET)
    .update(stringToSign)
    .digest('hex');
  
  return signature;
}

// Helper function to make Striga API calls
async function strigaRequest(method, endpoint, body = null, customApiKey = null) {
  const apiKey = customApiKey || API_KEY;
  const timestamp = Date.now().toString(); // Milliseconds, not seconds!
  const bodyString = body ? JSON.stringify(body) : '';
  
  // Generate HMAC signature - endpoint should NOT include /api/v1
  const signature = generateSignature(timestamp, method, endpoint, bodyString);
  
  const url = `${STRIGA_API_BASE}${endpoint}`;
  console.log(`Striga API request: ${method} ${url}`);
  console.log(`Timestamp (ms): ${timestamp}`);
  console.log(`Signature: ${signature}`);
  
  const headers = {
    'api-key': apiKey,
    'Authorization': `HMAC ${timestamp}:${signature}`,
    'Content-Type': 'application/json'
  };
  
  const options = { method, headers };
  if (body) {
    options.body = bodyString;
    console.log('Request payload:', JSON.stringify(body, null, 2));
  }

  try {
    const response = await fetch(url, options);
    const contentType = response.headers.get('content-type');
    let data;
    
    if (contentType && contentType.includes('application/json')) {
      data = await response.json();
    } else {
      // If not JSON, get the text response
      const text = await response.text();
      console.error(`Non-JSON response from Striga (${response.status}):`, text.substring(0, 500));
      data = { 
        error: 'Non-JSON response from API', 
        status: response.status,
        body: text.substring(0, 200) + '...' 
      };
    }
    
    console.log(`Striga API response (${response.status}):`, JSON.stringify(data, null, 2));
    return { status: response.status, data };
  } catch (error) {
    console.error('Striga API error:', error);
    return { status: 500, data: { error: error.message } };
  }
}

// Wrap all route handlers with error catching
const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

// Dashboard
app.get('/', (req, res) => {
  res.sendFile(__dirname + '/public/index.html');
});

// Serve signup page
app.get('/signup.html', (req, res) => {
  res.sendFile(__dirname + '/public/signup.html');
});

// Serve dashboard page
app.get('/dashboard.html', (req, res) => {
  res.sendFile(__dirname + '/public/dashboard.html');
});

// Ping endpoint to test authentication
app.post('/ping', asyncHandler(async (req, res) => {
  const { apiKey } = req.body;
  const response = await strigaRequest('POST', '/ping', { ping: 'pong' }, apiKey || API_KEY);
  res.json({ action: 'ping', ...response });
}));

// List all users
app.get('/list-users', asyncHandler(async (req, res) => {
  // Note: Striga API might not have a list users endpoint in sandbox
  // This is a mock implementation
  const users = global.createdUsers || [];
  res.json({ status: 200, data: { users } });
}));

// Store created users in memory (for demo purposes)
global.createdUsers = global.createdUsers || [];

// Routes now pull apiKey from body (optional, defaults to hardcoded)
app.post('/create-user', asyncHandler(async (req, res) => {
  const { apiKey, ...payload } = req.body;
  // Use /user/create (singular) not /users!
  const response = await strigaRequest('POST', '/user/create', payload, apiKey || API_KEY);
  
  // Store user if successfully created
  if (response.status === 201) {
    global.createdUsers.push({
      ...response.data,
      createdAt: new Date().toISOString()
    });
  }
  
  res.json({ action: 'create-user', ...response });
}));

app.post('/send-phone-otp', asyncHandler(async (req, res) => {
  // Note: This endpoint doesn't actually send SMS in Striga
  // SMS is sent automatically when user is created
  res.json({ 
    action: 'send-phone-otp', 
    status: 200, 
    data: { message: 'SMS is sent automatically on user creation' } 
  });
}));

app.post('/resend-phone-otp', asyncHandler(async (req, res) => {
  const { apiKey, userId } = req.body;
  // Correct endpoint is /user/resend-sms with userId in body
  const response = await strigaRequest('POST', `/user/resend-sms`, { userId }, apiKey || API_KEY);
  res.json({ action: 'resend-phone-otp', ...response });
}));

app.post('/verify-phone', asyncHandler(async (req, res) => {
  const { apiKey, userId, verificationCode } = req.body;
  // The correct endpoint is /user/verify-mobile with both userId and verificationCode
  const response = await strigaRequest('POST', `/user/verify-mobile`, { userId, verificationCode }, apiKey || API_KEY);
  
  // Update stored user if verification successful
  if (response.status === 200 && global.createdUsers) {
    const userIndex = global.createdUsers.findIndex(u => u.userId === userId);
    if (userIndex !== -1) {
      global.createdUsers[userIndex].KYC.mobileVerified = true;
    }
  }
  
  res.json({ action: 'verify-phone', ...response });
}));

app.post('/send-email-otp', asyncHandler(async (req, res) => {
  const { apiKey, userId, email } = req.body;
  const response = await strigaRequest('POST', `/user/verify-email`, { userId, email }, apiKey || API_KEY);
  res.json({ action: 'send-email-otp', ...response });
}));

app.post('/verify-email', asyncHandler(async (req, res) => {
  const { apiKey, userId, verificationCode } = req.body;
  const response = await strigaRequest('POST', `/user/verify-email/confirm`, { userId, verificationCode }, apiKey || API_KEY);
  res.json({ action: 'verify-email', ...response });
}));

app.post('/start-kyc', asyncHandler(async (req, res) => {
  const { apiKey, userId } = req.body;
  const response = await strigaRequest('POST', `/user/${userId}/kyc/start`, {}, apiKey || API_KEY);
  res.json({ action: 'start-kyc', ...response });
}));

app.post('/create-viban', asyncHandler(async (req, res) => {
  const { apiKey, userId } = req.body;
  const payload = { userId, currency: 'EUR' };
  const response = await strigaRequest('POST', '/wallet/create', payload, apiKey || API_KEY);
  res.json({ action: 'create-viban', ...response });
}));

app.post('/create-vcard', asyncHandler(async (req, res) => {
  const { apiKey, accountId } = req.body;
  const payload = { accountId, type: 'virtual', currency: 'EUR' };
  const response = await strigaRequest('POST', '/cards', payload, apiKey || API_KEY);
  res.json({ action: 'create-vcard', ...response });
}));

app.post('/create-btc-wallet', asyncHandler(async (req, res) => {
  const { apiKey, userId } = req.body;
  const payload = { userId, currency: 'BTC' };
  const response = await strigaRequest('POST', '/wallet/create', payload, apiKey || API_KEY);
  res.json({ action: 'create-btc-wallet', ...response });
}));

app.post('/simulate-deposit', asyncHandler(async (req, res) => {
  const { apiKey, walletId, amount } = req.body;
  // Placeholder simulation
  const simulatedResponse = { credited: true, eurAmount: amount * 50000 };
  res.json({ action: 'simulate-deposit', status: 200, data: simulatedResponse });
}));

// Global error handler
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({ 
    error: 'Internal server error', 
    message: err.message,
    action: req.url.substring(1)
  });
});

app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
  console.log('Logging is enabled - all requests and responses will be logged');
});
