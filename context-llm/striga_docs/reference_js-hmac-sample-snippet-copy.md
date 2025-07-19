---
title: PHP HMAC Sample Snippet
source_url: https://docs.striga.com/reference/js-hmac-sample-snippet-copy
scraped_at: 2025-07-18 17:55:51
---

# PHP HMAC Sample Snippet

Below is a simple PHP snippet using GuzzleHttp to the `/ping` endpoint. Please note the calculation of the timestamp is the UNIX timestamp in `milliseconds`

> 📘
>
> ### Calculating HMAC on Striga v1
>
> Please note that from v1 onwards, the root of the URL that includes `/api/v1` is NOT included in the calculation of the HMAC, unlike in v0.

PHP

```

<?php
require_once './autoload.php';
use GuzzleHttp\Client;
use GuzzleHttp\Psr7;
use GuzzleHttp\Exception\ClientException;

$client = new Client(['base_uri' => 'https://www.sandbox.striga.com/api/v1/']);
$SANDBOX_API_SECRET = '<YOUR-API-SECRET>';
$method = 'POST';
$body = ['ping' => 'pong'];
$TEST_ENDPOINT = '/ping';

function calcSig($body) {
  global $SANDBOX_API_SECRET, $method, $TEST_ENDPOINT;

  $mstime = floor(microtime(true) * 1000);
  $hmac = $mstime;
  $hmac .= $method;
  $hmac .= $TEST_ENDPOINT;

  $contentHash = md5(json_encode($body));
  $hmac .= $contentHash;

  $hmac = hash_hmac('sha256', $hmac, $SANDBOX_API_SECRET);

  $auth = 'HMAC ' . $mstime . ':' . $hmac;
  return $auth;
}

$headers = [
  'authorization' => calcSig($body),
  'api-key' => '<YOUR-API-KEY>',
  'Content-Type' => 'application/json',
];

echo print_r($headers);
try {
    $response = $client->request('POST', 'ping', [
        'headers' => $headers,
        'json' => $body
    ]);    
    echo $response->getBody();
} catch (ClientException $e) {
    echo Psr7\Message::toString($e->getRequest());
    echo Psr7\Message::toString($e->getResponse());
}

?>
```
