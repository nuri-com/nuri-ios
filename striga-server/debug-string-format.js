const crypto = require('crypto');
const https = require('https');

const API_KEY = '_TbS1cXGStMmYBJtcoYSA7we2lQUky_6TMo-aGLvWJM=';
const API_SECRET = '43jBa65VEoLC5O4O48pDruayz5Q43IlhgyGbkYPcMHE=';

console.log('🔍 Testing different string-to-sign formats\n');

async function testStringFormats() {
  const timestamp = Date.now().toString();
  const method = 'POST';
  const path = '/ping';
  const body = '{"ping":"pong"}';
  
  // Different string formats to test
  const formats = [
    {
      name: 'Format 1: timestamp+method+path+body',
      string: timestamp + method + path + body
    },
    {
      name: 'Format 2: With spaces',
      string: timestamp + ' ' + method + ' ' + path + ' ' + body
    },
    {
      name: 'Format 3: With newlines',
      string: timestamp + '\n' + method + '\n' + path + '\n' + body
    },
    {
      name: 'Format 4: Just timestamp+path+body',
      string: timestamp + path + body
    },
    {
      name: 'Format 5: With colons',
      string: timestamp + ':' + method + ':' + path + ':' + body
    },
    {
      name: 'Format 6: Lowercase method',
      string: timestamp + 'post' + path + body
    },
    {
      name: 'Format 7: Empty body for ping',
      string: timestamp + method + path
    },
    {
      name: 'Format 8: MD5 hash of body',
      string: timestamp + method + path + crypto.createHash('md5').update(body).digest('hex')
    }
  ];

  for (const format of formats) {
    console.log(`\nTesting: ${format.name}`);
    console.log(`String to sign: "${format.string}"`);
    
    const signature = crypto.createHmac('sha256', API_SECRET).update(format.string).digest('hex');
    console.log(`Signature: ${signature}`);
    
    await makeRequest(timestamp, signature, path, body);
  }
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
        const error = data.includes('did not match') ? '❌ HMAC mismatch' : 
                     data.includes('Time difference') ? '⏰ Time issue' :
                     res.statusCode === 200 ? '✅ SUCCESS!' : '❓ Other error';
        console.log(`Result: ${error} (${res.statusCode})`);
        if (res.statusCode === 200 || !data.includes('did not match')) {
          console.log('Full response:', data);
        }
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

// Also let's check the exact error from their example
async function checkExampleSignature() {
  console.log('\n\n📋 Checking the example signature:');
  const exampleTimestamp = '1752573127268';
  const exampleSignature = 'e37fbe408520c72ad2e0cab041069126cd0192415f5f4a356c33a4d562428125';
  
  // Try to reverse engineer what string produces this signature
  const testStrings = [
    exampleTimestamp + 'POST' + '/ping' + '{"ping":"pong"}',
    exampleTimestamp + 'POST' + '/api/v1/ping' + '{"ping":"pong"}',
    exampleTimestamp + 'POST' + 'ping' + '{"ping":"pong"}',
  ];
  
  for (const str of testStrings) {
    const sig = crypto.createHmac('sha256', API_SECRET).update(str).digest('hex');
    if (sig === exampleSignature) {
      console.log('✅ FOUND MATCHING FORMAT!');
      console.log('String:', str);
      return;
    }
  }
  console.log('❌ Could not reproduce example signature - might be using different secret');
}

async function run() {
  await testStringFormats();
  await checkExampleSignature();
}

run();