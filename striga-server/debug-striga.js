const https = require('https');
const crypto = require('crypto');

const API_KEY = '_TbS1cXGStMmYBJtcoYSA7we2lQUky_6TMo-aGLvWJM=';
const API_SECRET = '43jBa65VEoLC5O4O48pDruayz5Q43IlhgyGbkYPcMHE=';

console.log('🔍 STRIGA API DEBUGGING TOOL\n');

// Test different signature methods
async function testSignatureVariations() {
  const timestamp = Date.now().toString();
  const path = '/ping';
  const method = 'POST';
  const body = '{"ping":"pong"}';
  
  console.log('📋 Test Parameters:');
  console.log('Timestamp:', timestamp);
  console.log('Method:', method);
  console.log('Path:', path);
  console.log('Body:', body);
  console.log('\n');

  // Test 1: Raw secret (as provided)
  console.log('Test 1: Using raw API secret as-is');
  const sig1 = crypto.createHmac('sha256', API_SECRET).update(timestamp + method + path + body).digest('hex');
  console.log('Signature:', sig1);
  await makeRequest(timestamp, sig1, path, body);

  // Test 2: Base64 decoded secret
  console.log('\nTest 2: Using base64 decoded secret');
  const secretBuffer = Buffer.from(API_SECRET, 'base64');
  const sig2 = crypto.createHmac('sha256', secretBuffer).update(timestamp + method + path + body).digest('hex');
  console.log('Signature:', sig2);
  await makeRequest(timestamp, sig2, path, body);

  // Test 3: Without the = at the end
  console.log('\nTest 3: Secret without trailing =');
  const secretNoEquals = API_SECRET.replace(/=$/, '');
  const sig3 = crypto.createHmac('sha256', secretNoEquals).update(timestamp + method + path + body).digest('hex');
  console.log('Signature:', sig3);
  await makeRequest(timestamp, sig3, path, body);

  // Test 4: Different path format (with /api/v1)
  console.log('\nTest 4: Including /api/v1 in signature path');
  const fullPath = '/api/v1' + path;
  const sig4 = crypto.createHmac('sha256', API_SECRET).update(timestamp + method + fullPath + body).digest('hex');
  console.log('Signature:', sig4);
  await makeRequest(timestamp, sig4, path, body);

  // Test 5: Base64 signature instead of hex
  console.log('\nTest 5: Base64 encoded signature');
  const sig5 = crypto.createHmac('sha256', API_SECRET).update(timestamp + method + path + body).digest('base64');
  console.log('Signature:', sig5);
  await makeRequest(timestamp, sig5, path, body);

  // Test 6: Seconds instead of milliseconds
  console.log('\nTest 6: Using seconds timestamp');
  const timestampSeconds = Math.floor(Date.now() / 1000).toString();
  const sig6 = crypto.createHmac('sha256', API_SECRET).update(timestampSeconds + method + path + body).digest('hex');
  console.log('Timestamp (seconds):', timestampSeconds);
  console.log('Signature:', sig6);
  await makeRequest(timestampSeconds, sig6, path, body);
}

function makeRequest(timestamp, signature, path, body) {
  return new Promise((resolve) => {
    const options = {
      method: 'POST',
      hostname: 'www.sandbox.striga.com',
      path: '/api/v1' + path,
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
        console.log('Response:', res.statusCode, data.substring(0, 200));
        resolve();
      });
    });

    req.on('error', (error) => {
      console.error('Request error:', error.message);
      resolve();
    });

    req.write(body);
    req.end();
  });
}

// Also test what headers the server expects
async function testMissingAuth() {
  console.log('\n\n📋 Testing without authentication to see error message:');
  
  const options = {
    method: 'POST',
    hostname: 'www.sandbox.striga.com',
    path: '/api/v1/ping',
    headers: {
      'Content-Type': 'application/json'
    }
  };

  return new Promise((resolve) => {
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        console.log('No auth response:', res.statusCode, data);
        resolve();
      });
    });

    req.write('{"ping":"pong"}');
    req.end();
  });
}

// Run all tests
async function runAllTests() {
  await testSignatureVariations();
  await testMissingAuth();
  
  console.log('\n\n📌 DEBUGGING TIPS:');
  console.log('1. If you get "HMAC\'s did not match" - the signature calculation is wrong');
  console.log('2. If you get "Time difference too great" - timestamp format is correct but old');
  console.log('3. If you get 504 timeouts - likely missing required headers');
  console.log('4. If you get 401 with specific missing header message - that tells us what\'s needed');
}

runAllTests();