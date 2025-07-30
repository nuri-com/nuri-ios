# Manual TestFlight Upload Instructions

Since automated upload is having authentication issues, here are your options:

## Option 1: Transporter App (Recommended)
1. Download "Transporter" from Mac App Store (free Apple app)
2. Open Transporter and sign in with Apple ID: proud@me.com
3. Drag and drop the IPA file: `./builds/Nuri-TestFlight.ipa`
4. Click "Deliver"
5. Enter 2FA code if prompted

## Option 2: Xcode Organizer
1. Open Xcode
2. Go to Window → Organizer
3. Click "Archives" tab
4. Select the archive from today (2025-07-26)
5. Click "Distribute App"
6. Choose "App Store Connect"
7. Follow the prompts

## Option 3: App-Specific Password with Fastlane
1. Go to https://appleid.apple.com/account/manage
2. Sign in and go to "Security"
3. Under "App-Specific Passwords" click "Generate Password"
4. Name it "Fastlane"
5. Copy the password and run:
   ```bash
   export FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
   fastlane upload_ipa
   ```

## Your Build Details
- **IPA Location**: /Users/eminmahrt/Developer/nuri-ios/builds/Nuri-TestFlight.ipa
- **Version**: 1.0.0
- **Build**: 1
- **Bundle ID**: com.nuri.mobile-ios
- **Team ID**: MH2SRQ3N27

The app is ready for upload\! It includes:
- Enhanced logging system
- Working passkey authentication  
- Logout functionality
- All recent fixes
