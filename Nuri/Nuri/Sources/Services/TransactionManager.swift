import Foundation
import BitcoinDevKit

/// Manages Bitcoin transaction creation, signing, and broadcasting
final class TransactionManager {
    static let shared = TransactionManager()
    
    // MARK: - Constants
    private let DEFAULT_FEE_RATE: UInt64 = 1 // 1 sat/vB default
    private let MIN_FEE_RATE: UInt64 = 1
    private let MAX_FEE_RATE: UInt64 = 1000
    
    // MARK: - Dependencies
    private let walletService: BitcoinWalletService
    
    private init(walletService: BitcoinWalletService = .shared) {
        self.walletService = walletService
    }
    
    // MARK: - Error Types
    enum TransactionError: Error, LocalizedError {
        case walletNotAvailable
        case invalidAddress(String)
        case invalidAmount(String)
        case insufficientFunds(available: UInt64, required: UInt64)
        case feeCalculationFailed
        case buildTransactionFailed(Error)
        case signingFailed(Error)
        case broadcastFailed(Error)
        case networkError(Error)
        
        var errorDescription: String? {
            switch self {
            case .walletNotAvailable:
                return "Bitcoin wallet is not available. Please ensure your wallet is initialized."
            case .invalidAddress(let address):
                return "Invalid Bitcoin address: \(address)"
            case .invalidAmount(let amount):
                return "Invalid amount: \(amount)"
            case .insufficientFunds(let available, let required):
                return "Insufficient funds. Available: \(available) sats, Required: \(required) sats"
            case .feeCalculationFailed:
                return "Failed to calculate transaction fee"
            case .buildTransactionFailed(let error):
                return "Failed to build transaction: \(error.localizedDescription)"
            case .signingFailed(let error):
                return "Failed to sign transaction: \(error.localizedDescription)"
            case .broadcastFailed(let error):
                return "Failed to broadcast transaction: \(error.localizedDescription)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Transaction Info
    struct TransactionInfo {
        let recipientAddress: String
        let amountSats: UInt64
        let feeSats: UInt64
        let totalSats: UInt64
        let feeRate: UInt64
        
        var amountBTC: Double {
            Double(amountSats) / 100_000_000.0
        }
        
        var feeBTC: Double {
            Double(feeSats) / 100_000_000.0
        }
        
        var totalBTC: Double {
            Double(totalSats) / 100_000_000.0
        }
    }
    
    // MARK: - Public API
    
    /// Validates a Bitcoin address
    func validateAddress(_ address: String) -> Bool {
        do {
            // Use the current network from wallet service
            let network: Network = .bitcoin // mainnet
            let _ = try Address(address: address, network: network)
            return true
        } catch {
            print("❌ [TransactionManager] Invalid address validation: \(error)")
            return false
        }
    }
    
    /// Validates transaction amount in satoshis
    func validateAmount(_ amountSats: UInt64) -> Bool {
        // Minimum amount is 546 satoshis (dust limit)
        let dustLimit: UInt64 = 546
        return amountSats >= dustLimit
    }
    
    /// Calculates transaction fee for given amount and fee rate
    func calculateFee(amountSats: UInt64, feeRate: UInt64 = 0) async throws -> UInt64 {
        print("🧮 [TransactionManager] Calculating fee for amount: \(amountSats) sats")
        
        let actualFeeRate = feeRate > 0 ? feeRate : DEFAULT_FEE_RATE
        
        guard let wallet = await getWallet() else {
            throw TransactionError.walletNotAvailable
        }
        
        // Get current balance to check if we have funds
        guard let balance = await walletService.getDetailedBalance() else {
            throw TransactionError.walletNotAvailable
        }
        
        if balance.confirmed < amountSats {
            throw TransactionError.insufficientFunds(
                available: balance.confirmed,
                required: amountSats
            )
        }
        
        do {
            // Create a dummy transaction to estimate size and fee
            let tempAddress = try await getCurrentAddress()
            let script = try Address(address: tempAddress, network: .bitcoin).scriptPubkey()
            
            let txBuilder = try TxBuilder()
                .addRecipient(
                    script: script,
                    amount: Amount.fromSat(satoshi: amountSats)
                )
                .feeRate(feeRate: FeeRate.fromSatPerVb(satVb: actualFeeRate))
                .finish(wallet: wallet)
            
            // Extract transaction to calculate actual fee
            let transaction = try txBuilder.extractTx()
            
            // Calculate fee by getting transaction details
            let sentReceived = wallet.sentAndReceived(tx: transaction)
            let fee = sentReceived.sent.toSat() - amountSats
            
            print("✅ [TransactionManager] Calculated fee: \(fee) sats at \(actualFeeRate) sat/vB")
            return fee
            
        } catch {
            print("❌ [TransactionManager] Fee calculation failed: \(error)")
            throw TransactionError.feeCalculationFailed
        }
    }
    
    /// Builds transaction info with fee calculation
    func buildTransactionInfo(
        recipientAddress: String,
        amountSats: UInt64,
        feeRate: UInt64 = 0
    ) async throws -> TransactionInfo {
        
        print("🔧 [TransactionManager] Building transaction info")
        print("   📍 Recipient: \(recipientAddress)")
        print("   💰 Amount: \(amountSats) sats")
        
        // Validate inputs
        guard validateAddress(recipientAddress) else {
            throw TransactionError.invalidAddress(recipientAddress)
        }
        
        guard validateAmount(amountSats) else {
            throw TransactionError.invalidAmount("\(amountSats) sats")
        }
        
        let actualFeeRate = feeRate > 0 ? feeRate : DEFAULT_FEE_RATE
        
        // Calculate fee
        let feeSats = try await calculateFee(amountSats: amountSats, feeRate: actualFeeRate)
        let totalSats = amountSats + feeSats
        
        // Verify we have enough funds including fee
        guard let balance = await walletService.getDetailedBalance() else {
            throw TransactionError.walletNotAvailable
        }
        
        if balance.confirmed < totalSats {
            throw TransactionError.insufficientFunds(
                available: balance.confirmed,
                required: totalSats
            )
        }
        
        let transactionInfo = TransactionInfo(
            recipientAddress: recipientAddress,
            amountSats: amountSats,
            feeSats: feeSats,
            totalSats: totalSats,
            feeRate: actualFeeRate
        )
        
        print("✅ [TransactionManager] Transaction info built:")
        print("   💰 Amount: \(amountSats) sats (\(transactionInfo.amountBTC) BTC)")
        print("   💸 Fee: \(feeSats) sats (\(transactionInfo.feeBTC) BTC)")
        print("   📊 Total: \(totalSats) sats (\(transactionInfo.totalBTC) BTC)")
        print("   ⚡ Fee rate: \(actualFeeRate) sat/vB")
        
        return transactionInfo
    }
    
    /// Sends Bitcoin transaction
    func sendTransaction(
        recipientAddress: String,
        amountSats: UInt64,
        feeRate: UInt64 = 0
    ) async throws -> String {
        
        print("🚀 [TransactionManager] Starting Bitcoin transaction")
        print("   📍 To: \(recipientAddress)")
        print("   💰 Amount: \(amountSats) sats")
        
        // Build transaction info (validates inputs and calculates fee)
        let transactionInfo = try await buildTransactionInfo(
            recipientAddress: recipientAddress,
            amountSats: amountSats,
            feeRate: feeRate
        )
        
        guard let wallet = await getWallet() else {
            throw TransactionError.walletNotAvailable
        }
        
        guard let esploraClient = await getEsploraClient() else {
            throw TransactionError.walletNotAvailable
        }
        
        do {
            // Sync wallet before creating transaction
            print("🔄 [TransactionManager] Syncing wallet before transaction...")
            _ = try await walletService.syncAndGetBalance()
            
            // Build transaction
            print("🔧 [TransactionManager] Building transaction...")
            let psbt = try buildTransaction(
                wallet: wallet,
                recipientAddress: recipientAddress,
                amountSats: amountSats,
                feeRate: transactionInfo.feeRate
            )
            
            // Sign transaction
            print("✍️ [TransactionManager] Signing transaction...")
            let signedPsbt = try signTransaction(wallet: wallet, psbt: psbt)
            
            // Extract final transaction
            print("📤 [TransactionManager] Extracting transaction...")
            let transaction = try signedPsbt.extractTx()
            let txId = transaction.computeTxid()
            
            // Broadcast transaction
            print("📡 [TransactionManager] Broadcasting transaction...")
            try broadcastTransaction(esploraClient: esploraClient, transaction: transaction)
            
            print("✅ [TransactionManager] Transaction sent successfully!")
            print("   🆔 Transaction ID: \(txId)")
            
            return txId
            
        } catch let error as WalletError {
            throw TransactionError.buildTransactionFailed(error)
        } catch let error as SignerError {
            throw TransactionError.signingFailed(error)
        } catch let error as EsploraError {
            throw TransactionError.broadcastFailed(error)
        } catch {
            throw TransactionError.networkError(error)
        }
    }
    
    // MARK: - Private Methods
    
    private func getWallet() async -> Wallet? {
        return walletService.getWallet()
    }
    
    private func getEsploraClient() async -> EsploraClient? {
        return walletService.getEsploraClient()
    }
    
    private func getCurrentAddress() async throws -> String {
        guard let address = walletService.currentAddress() else {
            throw TransactionError.walletNotAvailable
        }
        return address
    }
    
    private func buildTransaction(
        wallet: Wallet,
        recipientAddress: String,
        amountSats: UInt64,
        feeRate: UInt64
    ) throws -> Psbt {
        
        let script = try Address(address: recipientAddress, network: .bitcoin).scriptPubkey()
        
        let txBuilder = try TxBuilder()
            .addRecipient(
                script: script,
                amount: Amount.fromSat(satoshi: amountSats)
            )
            .feeRate(feeRate: FeeRate.fromSatPerVb(satVb: feeRate))
            .finish(wallet: wallet)
        
        return txBuilder
    }
    
    private func signTransaction(wallet: Wallet, psbt: Psbt) throws -> Psbt {
        let isSigned = try wallet.sign(psbt: psbt)
        
        if !isSigned {
            throw TransactionError.signingFailed(WalletError.notSigned)
        }
        
        return psbt
    }
    
    private func broadcastTransaction(esploraClient: EsploraClient, transaction: Transaction) throws {
        try esploraClient.broadcast(transaction: transaction)
    }
}

// MARK: - Extensions

private extension WalletError {
    static let notSigned = WalletError.generic(message: "Transaction not fully signed")
}