# Fastlane Setup Instructions

## Prerequisites

### 1. App Store Connect API Key
- **Key ID**: U5W7H8NLHM
- **Issuer ID**: 69a6de74-4a5e-47e3-e053-5b8c7c11a4d1
- **Team ID**: NSLWDP4W5G
- **Apple ID**: 6736962812
- **Bundle ID**: com.nuri.mobile-ios

### 2. Required Files (Keep these private!)
These files must exist in the fastlane directory but MUST be excluded from Git:
- `AuthKey_U5W7H8NLHM.p8` - App Store Connect API private key
- `api_key.json` - API key configuration (optional, for convenience)
- `api_key.p8` - Duplicate of AuthKey file (optional)

## Current Status

### ✅ Working
- API key authentication with App Store Connect
- Build number retrieval from TestFlight
- Archive creation with incremented build numbers
- Project generation with Tuist

### ❌ Needs Setup
- Provisioning profiles for export
- Code signing certificates

## Available Lanes

### 1. `fastlane deploy` (Automated deployment)
- Generates project with Tuist
- Connects using API key
- Gets latest build number from TestFlight
- Creates archive with incremented build
- **Currently fails at export due to missing provisioning profiles**

### 2. `fastlane archive` (Archive only)
- Creates .xcarchive without code signing
- Can be manually exported from Xcode Organizer
- **Best current option for TestFlight deployment**

### 3. `fastlane adhoc` (Development build)
- Creates development IPA for testing
- Uses automatic signing

## How to Deploy to TestFlight (Current Workaround)

1. Run archive creation:
   ```bash
   fastlane archive
   ```

2. Open Xcode and go to Window → Organizer (⌘⇧2)

3. Select the created archive

4. Click "Distribute App"

5. Choose "App Store Connect" and follow the wizard

## To Fix Automated Deployment

### Option 1: Manual Provisioning Profile
1. Go to Apple Developer Portal
2. Create an App Store distribution provisioning profile for `com.nuri.mobile-ios`
3. Download and install the profile
4. Update Fastfile with the profile name

### Option 2: Use Fastlane Match (Recommended)
1. Create a private Git repository for certificates
2. Run: `fastlane match init`
3. Configure with your Git repo URL
4. Run: `fastlane match appstore`
5. This will create and manage certificates automatically

### Option 3: Use Automatic Signing
Currently configured but may need:
- Xcode to be signed in with the Apple ID
- Valid development team selected in project settings

## Environment Variables (Optional)
You can set these to avoid hardcoding:
```bash
export APP_STORE_CONNECT_API_KEY_ID="U5W7H8NLHM"
export APP_STORE_CONNECT_API_KEY_ISSUER_ID="69a6de74-4a5e-47e3-e053-5b8c7c11a4d1"
export APP_STORE_CONNECT_API_KEY_KEY_FILEPATH="fastlane/AuthKey_U5W7H8NLHM.p8"
```

## Security Notes
- NEVER commit the .p8 private key files to Git
- Keep api_key.json private if you create one
- The .gitignore should include:
  - `fastlane/*.p8`
  - `fastlane/api_key.json`
  - `fastlane/AuthKey_*.p8`

## Troubleshooting

### "No profiles for 'com.nuri.mobile-ios' were found"
- Need to create or download provisioning profiles
- Can use automatic signing or Fastlane Match

### "Cannot find signing certificate"
- Ensure iOS Distribution certificate is in keychain
- May need to download from Apple Developer Portal

### Build number conflicts
- The deploy lane automatically increments build numbers
- If manual upload was done, may need to sync

## Next Steps for Full Automation
1. Set up Fastlane Match for certificate management
2. Or manually create and install provisioning profiles
3. Test the full `fastlane deploy` lane
4. Consider setting up CI/CD with GitHub Actions