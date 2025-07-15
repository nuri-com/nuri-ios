const https = require('https');
const crypto = require('crypto');

const API_KEY = '_TbS1cXGStMmYBJtcoYSA7we2lQUky_6TMo-aGLvWJM=';
const API_SECRET = '43jBa65VEoLC5O4O48pDruayz5Q43IlhgyGbkYPcMHE=';

async function testEndpoint(method, path, body = null) {
  const timestamp = Date.now().toString();
  const bodyString = body ? JSON.stringify(body) : '';
  const bodyHash = bodyString ? crypto.createHash('md5').update(bodyString).digest('hex') : '';
  const stringToSign = timestamp + method + path + bodyHash;
  const signature = crypto.createHmac('sha256', API_SECRET).update(stringToSign).digest('hex');

  console.log(`\nTesting: ${method} ${path}`);
  if (body) console.log('Body:', JSON.stringify(body, null, 2));

  return new Promise((resolve) => {
    const options = {
      method,
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
        console.log(`Response (${res.statusCode}):`, data.substring(0, 300));
        resolve();
      });
    });

    req.on('error', console.error);
    if (bodyString) req.write(bodyString);
    req.end();
  });
}

async function findSMSEndpoints() {
  const userId = 'b1edebfa-5532-4f4c-b004-86ab28ef31c0';
  
  console.log('🔍 Testing possible SMS endpoints...\n');

  // Test different endpoint variations
  await testEndpoint('POST', `/user/${userId}/send-sms`);
  await testEndpoint('POST', `/user/${userId}/resend-sms`);
  await testEndpoint('POST', `/user/${userId}/send-mobile-otp`);
  await testEndpoint('POST', `/user/${userId}/verify-mobile`, { verificationCode: '123456' });
  await testEndpoint('POST', `/users/${userId}/send-sms`);
  await testEndpoint('POST', `/send-sms`, { userId });
  await testEndpoint('POST', `/resend-sms`, { userId });
  
  // Try the verify endpoint without code to see if it triggers SMS
  await testEndpoint('POST', `/user/verify-mobile`, { userId });
  
  // Try mobile number verification endpoint
  await testEndpoint('POST', `/user/${userId}/mobile/verify`);
  await testEndpoint('POST', `/user/${userId}/mobile/send-verification`);
}

findSMSEndpoints();