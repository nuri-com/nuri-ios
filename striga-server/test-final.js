const https = require('https');
const crypto = require('crypto');

const API_KEY = '_TbS1cXGStMmYBJtcoYSA7we2lQUky_6TMo-aGLvWJM=';
const API_SECRET = '43jBa65VEoLC5O4O48pDruayz5Q43IlhgyGbkYPcMHE=';

// Test 1: Try ping first
function testPing() {
  const timestamp = Date.now().toString();
  const body = '{"ping":"pong"}';
  
  // Try with raw secret (not base64 decoded)
  const stringToSign = timestamp + 'POST' + '/ping' + body;
  const signature = crypto.createHmac('sha256', API_SECRET).update(stringToSign).digest('hex');
  
  console.log('=== PING TEST ===');
  console.log('Timestamp:', timestamp);
  console.log('String to sign:', stringToSign);
  console.log('Signature:', signature);
  
  const options = {
    method: 'POST',
    hostname: 'www.sandbox.striga.com',
    path: '/api/v1/ping',
    headers: {
      'Authorization': `HMAC ${timestamp}:${signature}`,
      'api-key': API_KEY,
      'Content-Type': 'application/json'
    }
  };
  
  const req = https.request(options, (res) => {
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
      console.log('Status:', res.statusCode);
      console.log('Response:', data);
      
      // If ping works, try create user
      if (res.statusCode === 200) {
        testCreateUser();
      }
    });
  });
  
  req.write(body);
  req.end();
}

// Test 2: Create user
function testCreateUser() {
  const timestamp = Date.now().toString();
  const body = JSON.stringify({
    firstName: "Test",
    lastName: "User",
    email: "test@example.com", 
    mobile: "+491701234567"
  });
  
  const stringToSign = timestamp + 'POST' + '/user/create' + body;
  const signature = crypto.createHmac('sha256', API_SECRET).update(stringToSign).digest('hex');
  
  console.log('\n=== CREATE USER TEST ===');
  console.log('Timestamp:', timestamp);
  console.log('Signature:', signature);
  
  const options = {
    method: 'POST',
    hostname: 'www.sandbox.striga.com',
    path: '/api/v1/user/create',
    headers: {
      'Authorization': `HMAC ${timestamp}:${signature}`,
      'api-key': API_KEY,
      'Content-Type': 'application/json'
    }
  };
  
  const req = https.request(options, (res) => {
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
      console.log('Status:', res.statusCode);
      console.log('Response:', data);
    });
  });
  
  req.write(body);
  req.end();
}

// Start with ping test
testPing();