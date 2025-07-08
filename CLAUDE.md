# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a native iOS application built with SwiftUI that integrates Bitcoin wallet functionality with Privy authentication and KYC services. The app uses modern iOS patterns and is configured for iOS 18.0+.

## Build System

This project uses [Tuist](https://github.com/tuist/tuist) for project generation and dependency management.

**Essential commands:**
- `tuist generate` - Generate Xcode project (required before opening in Xcode)
- `tuist clean` - Clean generated files
- Build and run using the "Nuri" scheme in Xcode after generation

## Architecture

### Core Components

- **Authentication**: Privy SDK integration for passkey-based authentication
- **Bitcoin Wallet**: BitcoinDevKit (BDK) for Bitcoin wallet operations with secure keychain storage
- **KYC/Identity**: Sumsub integration for identity verification
- **UI**: SwiftUI with custom design system components

### Project Structure

- `Nuri/` - Main application target
  - `Sources/Common/` - Shared utilities and validators
  - `Sources/Design System/` - UI components and styling
  - `Sources/Services/` - Core business logic services
  - `Sources/Views/` - SwiftUI views organized by feature
  - `Sources/Repositories/` - Data access layer
- `Authentication/` - Separate module for NFC/biometric authentication
- `Workspace.swift` - Tuist workspace configuration

### Key Services

- `PrivyManager` - Singleton managing Privy SDK authentication state
- `BitcoinWalletService` - Bitcoin wallet operations with BDK and keychain integration
- `PasskeyService` - Passkey authentication coordination
- `SumsubService` - KYC/identity verification

### Dependencies

External packages managed via Tuist/Package.swift:
- `IdensicMobileSDK` (Sumsub) - Identity verification
- `Privy` - Authentication and wallet services
- `BitcoinDevKit` - Bitcoin wallet functionality
- `KeychainAccess` - Secure storage

## Development Notes

### Security Considerations

- Bitcoin wallet mnemonics are stored in keychain with biometric protection
- Passkey authentication uses associated domains for nuri.com
- NFC entitlements configured for card reading
- App uses light mode only (UIUserInterfaceStyle: Light)

### Bundle Configuration

- Bundle ID: `com.nuri.passkeytest`
- URL scheme: `nuriwallet://`
- Development team: `MH2SRQ3N27`

### Permissions

The app requests permissions for:
- Camera (document scanning, QR codes)
- Microphone (video verification)
- Photo library (ID document upload)
- Location (identity verification)
- Face ID (liveness verification)
- NFC (card reading)