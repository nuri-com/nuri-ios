#\!/bin/bash
echo "Uploading Nuri app to TestFlight..."
echo "Version: 1.0 (Build 1)"
echo ""
echo "This will require Apple ID authentication."
echo "You may be prompted for a 2FA code."
echo ""

fastlane upload_ipa

echo ""
echo "After upload completes:"
echo "1. Go to App Store Connect"
echo "2. Select your app"
echo "3. Go to TestFlight tab"
echo "4. Wait for build processing (usually 15-30 minutes)"
echo "5. Add testers or test groups"
echo "6. Start testing\!"
