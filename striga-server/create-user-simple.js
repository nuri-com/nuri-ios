const https = require('https');
const crypto = require('crypto');

const API_KEY = '_TbS1cXGStMmYBJtcoYSA7we2lQUky_6TMo-aGLvWJM=';
const API_SECRET = '43jBa65VEoLC5O4O48pDruayz5Q43IlhgyGbkYPcMHE=';

// Get current timestamp in milliseconds
const timestamp = Date.now().toString();

// Body for creating user
const body = JSON.stringify({
  firstName: "Test",
  lastName: "User", 
  email: "test@example.com",
  mobile: "+491701234567"
});

// Create signature: timestamp + method + path + body
const stringToSign = timestamp + 'POST' + '/user/create' + body;
const signature = crypto
  .createHmac('sha256', API_SECRET)
  .update(stringToSign)
  .digest('hex');

console.log('Timestamp:', timestamp);
console.log('Signature:', signature);

const options = {
  'method': 'POST',
  'hostname': 'www.sandbox.striga.com',
  'path': '/api/v1/user/create',
  'headers': {
    'Authorization': `HMAC ${timestamp}:${signature}`,
    'api-key': API_KEY,
    'Content-Type': 'application/json'
  }
};

const req = https.request(options, (res) => {
  let chunks = [];

  res.on("data", (chunk) => {
    chunks.push(chunk);
  });

  res.on("end", () => {
    let body = Buffer.concat(chunks);
    console.log('\nStatus:', res.statusCode);
    console.log('Response:', body.toString());
  });
});

req.on("error", (error) => {
  console.error(error);
});

req.write(body);
req.end();