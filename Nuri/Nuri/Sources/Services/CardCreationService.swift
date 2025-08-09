import Foundation
import StrigaAPI

// Protocol to abstract Striga card creation
protocol CardCreationServiceProtocol {
    func createCard(name: String, userId: String) async throws -> CardCreationResult
    func createUser(firstName: String, lastName: String, email: String, mobile: MobileInfo, address: AddressInfo, dateOfBirth: DateInfo) async throws -> String
    func verifyMobile(userId: String, verificationCode: String) async throws
    func startKYC(userId: String) async throws -> String
}

struct CardCreationResult {
    let id: String
    let parentWalletId: String
}

struct MobileInfo {
    let countryCode: String
    let number: String
}

struct AddressInfo {
    let addressLine1: String
    let city: String
    let country: String
    let postalCode: String
}

struct DateInfo {
    let year: Int32
    let month: Int32
    let day: Int32
}

// Mock implementation for the main target
class MockCardCreationService: CardCreationServiceProtocol {
    func createCard(name: String, userId: String) async throws -> CardCreationResult {
        // This would be replaced with actual Striga API call in a real implementation
        return CardCreationResult(id: "mock-card-id", parentWalletId: "mock-wallet-id")
    }
    
    func createUser(firstName: String, lastName: String, email: String, mobile: MobileInfo, address: AddressInfo, dateOfBirth: DateInfo) async throws -> String {
        // AGGRESSIVE LOGGING
        print("[GEMINI] CardCreationService.swift: MockCardCreationService.createUser called with firstName: \(firstName), lastName: \(lastName)")
        // Mock implementation
        return "mock-user-id"
    }
    
    func verifyMobile(userId: String, verificationCode: String) async throws {
        // Mock implementation
    }
    
    func startKYC(userId: String) async throws -> String {
        // Mock implementation
        return "mock-kyc-token"
    }
}

// Real Striga implementation
class StrigaCardCreationService: CardCreationServiceProtocol {
    private let striga = StrigaService.shared
    
    init() {
        // Configure Striga if not already configured
        if striga.configuration == nil {
            striga.configuration = StrigaCredentials.current
            print("[StrigaCardCreation] Configured with Striga credentials")
        }
    }
    
    func createCard(name: String, userId: String) async throws -> CardCreationResult {
        print("[StrigaCardCreation] Creating card for user: \(userId)")
        
        // Create ONE wallet for the user (this is the ONLY place we create a wallet)
        let walletResponse = try await striga.createWallet(.init(
            userId: userId
        ))
        
        print("[StrigaCardCreation] Wallet created: \(walletResponse.walletId)")
        
        // Generate a secure password for 3D Secure
        let password = generateSecurePassword()
        
        // Then create the card
        print("[StrigaCardCreation] Creating card with:")
        print("[StrigaCardCreation] - Name: \(name)")
        print("[StrigaCardCreation] - User ID: \(userId)")
        print("[StrigaCardCreation] - Parent Wallet ID: \(walletResponse.walletId)")
        print("[StrigaCardCreation] - Type: VIRTUAL")
        
        let cardResponse = try await striga.createCard(.init(
            nameOnCard: name,
            userId: userId,
            parentWalletId: walletResponse.walletId,
            type: "VIRTUAL",
            threeDSecurePassword: password
        ))
        
        print("[StrigaCardCreation] Card created: \(cardResponse.id)")
        
        return CardCreationResult(
            id: cardResponse.id,
            parentWalletId: walletResponse.walletId
        )
    }
    
    private func generateSecurePassword() -> String {
        // Use safer subset of allowed characters to avoid HMAC encoding issues
        // Avoiding: " \ / which can cause JSON/HMAC encoding problems
        let uppercase = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let lowercase = Array("abcdefghijklmnopqrstuvwxyz")
        let numbers = Array("0123456789")
        let special = Array("!#;:?&*()+=,.[]{}")
        
        // Use 16 characters for a strong password
        var password = ""
        
        // Ensure at least 2 of each type for strength
        password.append(contentsOf: [uppercase.randomElement()!, uppercase.randomElement()!])
        password.append(contentsOf: [lowercase.randomElement()!, lowercase.randomElement()!])
        password.append(contentsOf: [numbers.randomElement()!, numbers.randomElement()!])
        password.append(contentsOf: [special.randomElement()!, special.randomElement()!])
        
        // Fill remaining 8 characters
        let allCharacters = uppercase + lowercase + numbers + special
        for _ in 0..<8 {
            password.append(allCharacters.randomElement()!)
        }
        
        // Shuffle the password
        return String(password.shuffled())
    }
    
    func createUser(firstName: String, lastName: String, email: String, mobile: MobileInfo, address: AddressInfo, dateOfBirth: DateInfo) async throws -> String {
        // This is implemented in EnterSMSCodeViewModel
        throw NSError(domain: "StrigaCardCreation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Use EnterSMSCodeViewModel for user creation"])
    }
    
    func verifyMobile(userId: String, verificationCode: String) async throws {
        // This is implemented in EnterSMSCodeViewModel
        throw NSError(domain: "StrigaCardCreation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Use EnterSMSCodeViewModel for mobile verification"])
    }
    
    func startKYC(userId: String) async throws -> String {
        // This is implemented in EnterSMSCodeViewModel
        throw NSError(domain: "StrigaCardCreation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Use EnterSMSCodeViewModel for KYC"])
    }
}

// Singleton to provide the service
class CardCreationServiceProvider {
    static let shared = CardCreationServiceProvider()
    var service: CardCreationServiceProtocol = StrigaCardCreationService()
    
    private init() {}
}