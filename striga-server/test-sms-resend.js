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
        console.log(`Response (${res.statusCode}):`, data.substring(0, 500));
        resolve();
      });
    });

    req.on('error', console.error);
    if (bodyString) req.write(bodyString);
    req.end();
  });
}

async function testSMSResend() {
  const userId = 'b1edebfa-5532-4f4c-b004-86ab28ef31c0';
  
  console.log('🔍 Testing SMS resend endpoints...\n');

  // Test different resend patterns
  await testEndpoint('POST', `/user/${userId}/resend-sms`);
  await testEndpoint('POST', `/user/resend-sms`, { userId });
  await testEndpoint('POST', `/user/${userId}/mobile/resend`);
  await testEndpoint('POST', `/user/resend-mobile`, { userId });
  await testEndpoint('POST', `/user/${userId}/resend-mobile-verification`);
  
  // Test if we can get user details to check verification status
  console.log('\n📋 Getting user details...');
  await testEndpoint('GET', `/user/${userId}`);
  await testEndpoint('POST', `/user/get`, { userId });
}

testSMSResend();