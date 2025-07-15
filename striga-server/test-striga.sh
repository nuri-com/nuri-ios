#!/bin/bash
API_KEY="_TbS1cXGStMmYBJtcoYSA7we2lQUky_6TMo-aGLvWJM="
SECRET="43jBa65VEoLC5O4O48pDruayz5Q43IlhgyGbkYPcMHE="
BASE="https://www.sandbox.striga.com/api/v1"
TS=$(($(date +%s%N)/1000000))
BODY='{"firstName":"Ada","lastName":"Lovelace","email":"ada@example.com","mobile":"+491701234567"}'
SIG=$(printf "%sPOST/user/create%s" "$TS" "$BODY" | \
      openssl dgst -sha256 -hmac "$SECRET" -binary | base64)

echo "Timestamp: $TS"
echo "Signature: $SIG"
echo "Body: $BODY"

curl -i -X POST "$BASE/user/create" \
  -H "x-striga-api-key: $API_KEY" \
  -H "x-striga-timestamp: $TS" \
  -H "x-striga-signature: $SIG" \
  -H "Content-Type: application/json" \
  -d "$BODY"