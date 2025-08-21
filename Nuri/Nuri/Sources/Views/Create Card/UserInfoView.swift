import SwiftUI
import StrigaAPI
import UIKit

struct UserInfoView: View {
    @StateObject private var viewModel = UserInfoViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var shouldDismissEntireFlow = false
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("KYC Approved!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Your account has been verified")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("User Information")
                    .font(.headline)
                    .padding(.bottom, 8)
                
                InfoRow(label: "User ID", value: viewModel.userId)
                InfoRow(label: "Name", value: viewModel.name)
                InfoRow(label: "Email", value: viewModel.email)
                InfoRow(label: "Phone", value: viewModel.phoneNumber)
                
                if !viewModel.walletId.isEmpty {
                    InfoRow(label: "Wallet ID", value: viewModel.walletId)
                }
                
                if !viewModel.cardId.isEmpty {
                    InfoRow(label: "Card ID", value: viewModel.cardId)
                }
                
                if !viewModel.iban.isEmpty {
                    InfoRow(label: "IBAN", value: viewModel.iban)
                }
                
                if !viewModel.btcAddress.isEmpty {
                    InfoRow(label: "BTC Address", value: String(viewModel.btcAddress.prefix(20)) + "...")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            VStack(spacing: 16) {
                if viewModel.walletId.isEmpty || viewModel.cardId.isEmpty {
                    // Show create button if either wallet OR card is missing
                    Button(action: {
                        Task {
                            await viewModel.createWalletAndCard()
                        }
                    }) {
                        HStack {
                            if viewModel.isCreating {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "creditcard.fill")
                            }
                            Text(viewModel.isCreating ? "Creating..." : "Create Wallet & Card")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isCreating ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isCreating)
                    
                    // Show status if wallet exists but card doesn't
                    if !viewModel.walletId.isEmpty && viewModel.cardId.isEmpty {
                        Text("⚠️ Wallet exists but card creation needed")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                } else {
                    // Only show success when BOTH wallet AND card exist
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Wallet & Card Created")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(12)
                }
                
                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                Button(action: {
                    // Dismiss the entire card creation flow, not just this view
                    dismissEntireFlow()
                }) {
                    Text((viewModel.walletId.isEmpty || viewModel.cardId.isEmpty) ? "Skip for Now" : "Continue to App")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
            }
            
            Spacer()
        }
        .padding()
        .navigationBarBackButtonHidden(true)
        .task {
            await viewModel.loadUserInfo()
        }
    }
    
    private func dismissEntireFlow() {
        // Use PostKYCCoordinator to properly dismiss to main app
        // This ensures we never go back to SMS screen
        PostKYCCoordinator.shared.dismissToMainApp()
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.footnote)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

class UserInfoViewModel: ObservableObject {
    @Published var userId = ""
    @Published var name = ""
    @Published var email = ""
    @Published var phoneNumber = ""
    @Published var walletId = ""
    @Published var cardId = ""
    @Published var iban = ""
    @Published var btcAddress = ""
    @Published var isCreating = false
    @Published var errorMessage = ""
    
    private let striga = StrigaService.shared
    private let cardService = CardCreationServiceProvider.shared.service
    
    @MainActor
    func loadUserInfo() async {
        // Load user info from session
        let session = StrigaSession.shared
        userId = session.userId ?? ""
        
        if let firstName = session.firstName, let lastName = session.lastName {
            name = "\(firstName) \(lastName)"
        } else {
            name = session.name ?? ""
        }
        
        email = session.email ?? ""
        
        if let phone = session.phoneNumber, let countryCode = session.phoneCountryCode {
            phoneNumber = "\(countryCode)\(phone)"
        }
        
        // Check if wallet/card already exists
        await checkExistingWalletAndCard()
    }
    
    @MainActor
    private func checkExistingWalletAndCard() async {
        guard !userId.isEmpty else { return }
        
        print("[UserInfo] Checking for existing wallet/card...")
        
        do {
            let walletsResponse = try await striga.getWallets(userId: userId)
            print("[UserInfo] Found \(walletsResponse.wallets.count) wallet(s)")
            
            if let wallet = walletsResponse.wallets.first {
                walletId = wallet.walletId
                print("[UserInfo] Found wallet: \(walletId)")
                
                // Check for card in ALL accounts
                let allAccounts = [
                    wallet.accounts.eur,
                    wallet.accounts.btc,
                    wallet.accounts.eth,
                    wallet.accounts.usdc,
                    wallet.accounts.usdt
                ].compactMap { $0 }
                
                for account in allAccounts {
                    if let linkedCard = account.linkedCardId,
                       linkedCard != "UNLINKED" && !linkedCard.isEmpty {
                        cardId = linkedCard
                        print("[UserInfo] Found card: \(cardId) in \(account.currency) account")
                        break
                    }
                }
                
                // Get wallet details for IBAN and BTC address
                let walletDetails = try await striga.getWallet(walletId, userId: userId)
                
                if let eurAccount = walletDetails.accounts.eur {
                    if eurAccount.enriched {
                        // Get IBAN from enrichment
                        let enrichResult = try await striga.enrichAccount(.init(
                            accountId: eurAccount.accountId,
                            userId: userId
                        ))
                        iban = enrichResult.iban ?? ""
                    }
                }
                
                if let btcAccount = walletDetails.accounts.btc {
                    if btcAccount.enriched {
                        // Get BTC address from enrichment
                        let enrichResult = try await striga.enrichAccount(.init(
                            accountId: btcAccount.accountId,
                            userId: userId
                        ))
                        btcAddress = enrichResult.blockchainDepositAddress ?? ""
                    }
                }
            }
        } catch {
            print("[UserInfo] Error checking existing wallet: \(error)")
        }
    }
    
    @MainActor
    func createWalletAndCard() async {
        guard !userId.isEmpty else {
            errorMessage = "No user ID found"
            return
        }
        
        // Check if both wallet and card already exist
        if !walletId.isEmpty && !cardId.isEmpty {
            errorMessage = "Wallet and card already exist"
            return
        }
        
        isCreating = true
        errorMessage = ""
        
        do {
            print("[UserInfo] Creating wallet and card for user: \(userId)")
            
            // Use CardCreationService to create card (which also creates wallet if needed)
            let cardResult = try await cardService.createCard(name: name, userId: userId)
            
            print("[UserInfo] Card created successfully: \(cardResult.id)")
            
            // Update UI with new IDs
            cardId = cardResult.id
            walletId = cardResult.parentWalletId
            
            // Save to UserSettings
            var settings = UserSettings()
            settings.strigaUserId = userId
            settings.strigaCardId = cardId
            settings.strigaWalletId = walletId
            
            // Save to session
            StrigaSession.shared.cardId = cardId
            
            // Reload to get IBAN and BTC address
            await checkExistingWalletAndCard()
            
            // Post notification
            NotificationCenter.default.post(name: Notification.Name("CardCreatedSuccessfully"), object: nil)
            
            print("[UserInfo] ✅ Wallet and card created successfully")
            
        } catch {
            print("[UserInfo] ❌ Error creating wallet/card: \(error)")
            errorMessage = "Failed to create wallet: \(error.localizedDescription)"
        }
        
        isCreating = false
    }
}