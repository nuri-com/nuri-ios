# Nuri

## Project Setup
The Xcode project is generated using [Tuist](https://github.com/tuist/tuist).

After installing Tuist, run:

```bash
tuist generate
```

Then open the generated workspace and select the **Nuri** scheme.

## iCloud Backup
The project ships with an `ICloudBackupService` that encrypts the wallet seed
using a symmetric key stored in the user's iCloud Keychain. The key is generated
automatically and synced across devices, so no extra passphrase is required. Use
this service to create or restore a backup of the seed phrase in iCloud Drive.

