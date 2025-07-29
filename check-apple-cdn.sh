#!/bin/bash

echo "🔍 Checking Apple AASA Cache Status..."
echo "======================================"
echo ""

DIRECT=$(curl -s https://nuri.com/.well-known/apple-app-site-association | jq -r '.webcredentials.apps[0]')
CDN=$(curl -s https://app-site-association.cdn-apple.com/a/v1/nuri.com | jq -r '.webcredentials.apps[0]')

echo "✅ Direct from nuri.com:  $DIRECT"
echo "📦 Apple CDN cached:      $CDN"
echo ""

if [ "$DIRECT" == "$CDN" ]; then
    echo "🎉 Apple CDN is updated! You can switch back to com.nuri.mobile-ios"
else
    echo "⏳ Apple CDN still has old version. Keep using com.nuri.passkeytest"
fi