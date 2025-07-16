import Foundation

public struct CreateCardResponse: Decodable {
    public let name: String
    public let id: String
    public let type: String
    public let userId: String
    public let maskedCardNumber: String
    public let expiryData: String
    public let status: String
    public let address: Address
    public let isEnrolledFor3dSecure: Bool
    public let isCard3dSecureActivated: Bool
    public let security: Security
    public let activatedAt: String
    public let linkedAccountId: String
    public let parentWalletId: String
    public let createdAt: String
    public let fee: Fee

    public struct Address: Decodable {
        public let addressLine1: String
        public let postalCode: String
        public let city: String
        public let country: String
    }

    public struct Security: Decodable {
        public let contactlessEnabled: Bool
        public let withdrawalEnabled: Bool
        public let internetPurchaseEnabled: Bool
        public let overallLimitsEnabled: Bool
    }

    public struct Fee: Decodable {
        public let ourFee: String
        public let theirFee: String
        public let amount: String
        public let feeCurrency: String
        public let currency: String
        public let cardCreationFee: CardFee
        public let cardDeliveryFee: CardFee
        public let exchangeRate: String
    }

    public struct CardFee: Decodable {
        public let amount: String
        public let currency: String
    }
}
