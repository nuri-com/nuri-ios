# Automated TestFlight Deployment Instructions

## Prerequisites Check
All these should already be in place:
- ✅ API Key File: `fastlane/AuthKey_U5W7H8NLHM.p8`
- ✅ Team ID: `MH2SRQ3N27` (proud works GmbH)
- ✅ Bundle ID: `com.nuri.mobile-ios`
- ✅ Apple ID: `6736962812`

## One-Command Deployment

### Deploy to TestFlight
```bash
fastlane deploy
```

This single command will:
1. Generate Xcode project with Tuist
2. Authenticate with App Store Connect API
3. Get latest build number from TestFlight
4. Increment build number automatically
5. Download/verify provisioning profiles
6. Build the app archive
7. Sign with iOS Distribution certificate
8. Export IPA with proper signing
9. Upload to TestFlight
10. Make available for internal testing

## Configuration Details

### API Key Configuration
- **Key ID**: U5W7H8NLHM
- **Issuer ID**: 69a6de74-4a5e-47e3-e053-5b8c7c11a4d1  
- **Key File**: `fastlane/AuthKey_U5W7H8NLHM.p8`
- **Team ID**: MH2SRQ3N27

### Signing Configuration
- **Certificate**: Apple Distribution: proud works GmbH (MHP9RVVGQM)
- **Provisioning Profile**: com.nuri.mobile-ios AppStore
- **Signing Style**: Manual with automatic certificate management

## Troubleshooting

### If deployment fails:

1. **Certificate Issues**
   ```bash
   # Check if distribution certificate exists
   security find-identity -v -p codesigning | grep "Apple Distribution"
   
   # If missing, create it
   fastlane cert --api_key_path fastlane/api_key.json
   ```

2. **Provisioning Profile Issues**
   ```bash
   # Download latest provisioning profile
   fastlane sigh download_all --api_key_path fastlane/api_key.json
   ```

3. **Build Number Conflicts**
   ```bash
   # Check current TestFlight build number
   fastlane run latest_testflight_build_number api_key_path:fastlane/api_key.json
   ```

4. **Clean Build Issues**
   ```bash
   # Clean derived data and rebuild
   rm -rf ~/Library/Developer/Xcode/DerivedData
   tuist clean
   tuist generate
   ```

## Manual Fallback Options

### Archive Only (no upload)
```bash
fastlane archive
```
Then manually upload from Xcode Organizer

### Check Everything is Set Up
```bash
# Verify API key works
fastlane run app_store_connect_api_key \
  key_id:U5W7H8NLHM \
  issuer_id:69a6de74-4a5e-47e3-e053-5b8c7c11a4d1 \
  key_filepath:fastlane/AuthKey_U5W7H8NLHM.p8

# List certificates
security find-identity -v -p codesigning

# List provisioning profiles  
ls ~/Library/MobileDevice/Provisioning\ Profiles/
```

## Expected Output for Successful Deployment

```
📱 Current TestFlight build: [number]
🚀 Building version: [number+1]
▸ Processing Info.plist files...
▸ Compiling Swift files...
▸ Linking Nuri...
▸ ** ARCHIVE SUCCEEDED **
▸ ** EXPORT SUCCEEDED **
✅ Successfully uploaded build [number] to TestFlight!
```

## Files That Should NOT Be in Git
- `fastlane/AuthKey_U5W7H8NLHM.p8`
- `fastlane/api_key.json`
- `fastlane/*.p8`
- `fastlane/builds/`
- `*.mobileprovision`

## Quick Test Command
To verify everything works, just run:
```bash
fastlane deploy
```

Build will appear in App Store Connect within 5-10 minutes for processing.