const https = require('https');

// Direct copy of their example with your keys
let options = {
   'method': 'POST',
   'hostname': 'www.sandbox.striga.com',
   'path': '/api/v1/ping',
   'headers': {
      'Authorization': 'HMAC 1752573127268:e37fbe408520c72ad2e0cab041069126cd0192415f5f4a356c33a4d562428125',
      'api-key': '_TbS1cXGStMmYBJtcoYSA7we2lQUky_6TMo-aGLvWJM='
   },
   'maxRedirects': 20
};

const req = https.request(options, (res) => {
   let chunks = [];

   res.on("data", (chunk) => {
      chunks.push(chunk);
   });

   res.on("end", (chunk) => {
      let body = Buffer.concat(chunks);
      console.log('Status:', res.statusCode);
      console.log('Response:', body.toString());
   });

   res.on("error", (error) => {
      console.error(error);
   });
});

let postData = '{"ping":"pong"}';

req.write(postData);

req.end();