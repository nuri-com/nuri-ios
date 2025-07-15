const https = require('https');
const crypto = require('crypto');

const API_KEY = '_TbS1cXGStMmYBJtcoYSA7we2lQUky_6TMo-aGLvWJM=';
const API_SECRET = '43jBa65VEoLC5O4O48pDruayz5Q43IlhgyGbkYPcMHE=';

const timestamp = Date.now().toString();
const method = 'POST';
const path = '/ping';
const body = '{"ping":"pong"}';

// Create string to sign
const stringToSign = timestamp + method + path + body;
console.log('String to sign:', stringToSign);

// Generate HMAC signature
const signature = crypto
  .createHmac('sha256', API_SECRET)
  .update(stringToSign)
  .digest('hex');

console.log('Timestamp:', timestamp);
console.log('Signature:', signature);

const options = {
  'method': 'POST',
  'hostname': 'www.sandbox.striga.com',
  'path': '/api/v1/ping',
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
    console.log('Status:', res.statusCode);
    console.log('Response:', body.toString());
  });
});

req.on("error", (error) => {
  console.error(error);
});

req.write(body);
req.end();