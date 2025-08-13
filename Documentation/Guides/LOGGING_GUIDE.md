# Enhanced Logging Guide for Nuri Wallet

## Overview
The enhanced logging system provides detailed context for every log entry, making debugging much easier.

## Key Features

### 1. **Automatic Context Capture**
Every log automatically includes:
- **Timestamp** with milliseconds
- **Category** (Wallet, Passkey, Network, etc.)
- **File name** and **line number**
- **Function name** where the log was called
- **Log level** with visual indicators

### 2. **Example Output**
```
2025-07-26T14:23:45.123Z ✅ [Wallet/BitcoinWalletService:234] initialiseWallet() → Wallet initialized successfully
  userId: default-user
  balance: 6616 sats
```

### 3. **Performance Tracking**
```swift
// Automatically logs start, end, and duration
let balance = await Log.wallet.measure("Fetching balance") {
    return try await bitcoinWalletService.getBalance()
}
```

### 4. **Flow Tracking**
```swift
// Track multi-step operations
let flow = Log.passkey.flow("Authentication")

flow.step("Fetching auth options")
// ... do work ...

flow.step("Presenting passkey UI")
// ... do work ...

flow.complete(metadata: ["username": username])
```

## Migration Examples

### Before:
```swift
print("🔐 [PasskeyAuthenticationService] Starting passkey authentication flow...")
print("📡 [PasskeyAuthenticationService] Step 1: Fetching authentication options...")
```

### After:
```swift
Log.passkey.info("Starting passkey authentication flow")
Log.passkey.network("Fetching authentication options", metadata: ["step": 1])
```

### Complex Example - Before:
```swift
print("📦 [PasskeyAuthenticationService] Verification response status: \(httpResponse.statusCode)")
if !(200...299).contains(httpResponse.statusCode) {
    print("❌ [PasskeyAuthenticationService] Server error: \(httpResponse.statusCode)")
    if let errorString = String(data: data, encoding: .utf8) {
        print("📄 [PasskeyAuthenticationService] Error response: \(errorString)")
    }
}
```

### After:
```swift
Log.passkey.network("Verification response received", 
    metadata: ["status": httpResponse.statusCode])

if !(200...299).contains(httpResponse.statusCode) {
    let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
    Log.passkey.error("Server error", 
        metadata: [
            "status": httpResponse.statusCode,
            "response": errorString
        ])
}
```

## Security Benefits

1. **Sensitive Data Protection**: Use metadata instead of string interpolation
   ```swift
   // Bad - seed phrase could end up in logs
   print("Seed phrase: \(seedPhrase)")
   
   // Good - can be filtered/redacted
   Log.security.debug("Seed phrase status", 
       metadata: ["length": seedPhrase.count, "isValid": true])
   ```

2. **Structured Logging**: Makes it easier to:
   - Filter logs by category
   - Search for specific operations
   - Track performance issues
   - Correlate related operations

3. **Production Safety**: 
   - Debug logs only in DEBUG builds
   - Structured format for log aggregation
   - No accidental sensitive data exposure

## Categories

- `Log.app` - App lifecycle events
- `Log.wallet` - Bitcoin wallet operations
- `Log.passkey` - Passkey authentication
- `Log.network` - Network requests
- `Log.security` - Security-sensitive operations
- `Log.ui` - UI events
- `Log.state` - State management
- `Log.bitcoin` - Bitcoin-specific operations
- `Log.keychain` - Keychain operations

## Best Practices

1. **Use appropriate log levels**:
   - `debug()` - Detailed debugging info
   - `info()` - General information
   - `success()` - Successful operations
   - `warning()` - Potential issues
   - `error()` - Errors with context

2. **Include metadata** for complex data:
   ```swift
   Log.wallet.info("Transaction created", metadata: [
       "amount": transaction.amount,
       "fee": transaction.fee,
       "outputs": transaction.outputs.count
   ])
   ```

3. **Track flows** for multi-step operations:
   ```swift
   let flow = Log.wallet.flow("Send Bitcoin")
   flow.step("Validating inputs")
   flow.step("Creating transaction") 
   flow.step("Broadcasting")
   flow.complete(metadata: ["txid": transaction.id])
   ```

4. **Measure performance** for critical operations:
   ```swift
   await Log.network.measure("Blockchain sync") {
       try await syncWithBlockchain()
   }
   ```