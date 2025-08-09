# Nuri

## Project Setup
The Xcode project is generated using [Tuist](https://github.com/tuist/tuist).

After installing Tuist, run:

```bash
tuist generate
```

Then open the generated workspace and select the **Nuri** scheme.

## Building and Distribution

### Prerequisites

1. Install Fastlane if you haven't already:
   ```bash
   brew install fastlane
   ```

2. Make sure you have the correct signing certificates and provisioning profiles installed.

### Building with Fastlane

Fastlane provides several options for building the app:

#### 1. Build Archive for Manual Distribution (Recommended)

To build an archive that you can manually distribute through Xcode Organizer:

```bash
fastlane archive
```

This will create an archive at `./builds/Nuri.xcarchive`. After the build completes:
1. Open Xcode
2. Go to Window → Organizer (or press ⌘⇧2)
3. Select the "Archives" tab
4. Find your archive in the list
5. Click "Distribute App"
6. Choose "App Store Connect"
7. Follow the wizard to upload to TestFlight

#### 2. Build IPA Directly

To build an IPA file directly (requires proper signing configuration):

```bash
fastlane build_only
```

This creates an IPA at `./builds/Nuri-TestFlight.ipa`.

#### 3. Build and Upload to TestFlight Automatically

To build and upload directly to TestFlight:

```bash
fastlane beta
```

This will:
- Check that your git status is clean
- Increment the build number
- Build the app
- Upload to TestFlight
- Commit and push the version bump

### Manual Build with Xcode

If you prefer to build manually without Fastlane:

1. Open `Nuri.xcworkspace` in Xcode
2. Select the "Nuri" scheme
3. Choose "Any iOS Device" as the destination
4. Go to Product → Archive
5. Once the archive is complete, the Organizer will open
6. Click "Distribute App"
7. Choose "App Store Connect"
8. Follow the upload wizard

### Troubleshooting

#### Signing Issues
If you encounter signing issues:
- Ensure you have the correct Apple Distribution certificate installed
- Check that the provisioning profiles are up to date
- Verify the team ID and bundle identifier match your App Store Connect configuration

#### Build Failures
- Run `tuist clean` and `tuist generate` to regenerate the project
- Clean the build folder in Xcode (⇧⌘K)
- Delete DerivedData if necessary

## iCloud Backup
The project ships with an `ICloudBackupService` that encrypts the wallet seed
using a symmetric key stored in the user's iCloud Keychain. The key is generated
automatically and synced across devices, so no extra passphrase is required. Use
this service to create or restore a backup of the seed phrase in iCloud Drive.