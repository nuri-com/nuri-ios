#!/bin/bash

echo "🔑 Fastlane API Key Setup"
echo "========================="
echo ""
echo "This script will help you set up App Store Connect API authentication"
echo ""

# Check if API key already exists
if [ -f "api_key.json" ]; then
    echo "⚠️  Warning: api_key.json already exists!"
    read -p "Do you want to overwrite it? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 1
    fi
fi

# Get Key ID
echo "Step 1: Enter your App Store Connect API Key ID"
echo "(You can find this in App Store Connect > Users and Access > Keys)"
read -p "Key ID: " KEY_ID

# Get Issuer ID
echo ""
echo "Step 2: Enter your Issuer ID"
echo "(You can find this at the top of the Keys page in App Store Connect)"
read -p "Issuer ID: " ISSUER_ID

# Get P8 file path
echo ""
echo "Step 3: Enter the path to your .p8 key file"
echo "(The file you downloaded from App Store Connect)"
read -p "Path to .p8 file: " P8_PATH

# Check if P8 file exists
if [ ! -f "$P8_PATH" ]; then
    echo "❌ Error: File not found at $P8_PATH"
    exit 1
fi

# Copy P8 file to fastlane directory
cp "$P8_PATH" "./api_key.p8"

# Read P8 file content
P8_CONTENT=$(cat "$P8_PATH")

# Create api_key.json
cat > api_key.json <<EOF
{
  "key_id": "$KEY_ID",
  "issuer_id": "$ISSUER_ID",
  "key": "$P8_CONTENT",
  "duration": 1200,
  "in_house": false
}
EOF

echo ""
echo "✅ API key configuration created successfully!"
echo ""
echo "Files created:"
echo "  - api_key.json (configuration file)"
echo "  - api_key.p8 (key file)"
echo ""
echo "🚀 You can now deploy to TestFlight by running:"
echo "  fastlane deploy"
echo ""
echo "⚠️  Remember: These files contain sensitive credentials."
echo "They are already in .gitignore and should NEVER be committed to git!"