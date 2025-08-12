import Foundation

public struct CardResponse: Decodable {
    public let name: String
    public let id: String
    public let type: String
    public let userId: String
    public let maskedCardNumber: String
    public let expiryData: String
    public let status: String
    public let address: Address?
    public let isEnrolledFor3dSecure: Bool
    public let isCard3dSecureActivated: Bool?
    public let security: Security?
    public let activatedAt: String?
    public let linkedAccountId: String
    public let parentWalletId: String
    public let linkedAccountCurrency: String
    public let lastLinkedAccountId: String?
    public let createdAt: String
    public let limits: Limits?
    public let blockType: String?
    
    // Computed properties to extract month/year from expiryData
    public var expiryMonth: Int {
        // Parse "2027-08-31T23:59:59Z" to get month
        let dateFormatter = ISO8601DateFormatter()
        if let date = dateFormatter.date(from: expiryData) {
            let calendar = Calendar.current
            return calendar.component(.month, from: date)
        }
        return 1  // Default January if parsing fails
    }
    
    public var expiryYear: Int {
        // Parse "2027-08-31T23:59:59Z" to get year
        let dateFormatter = ISO8601DateFormatter()
        if let date = dateFormatter.date(from: expiryData) {
            let calendar = Calendar.current
            return calendar.component(.year, from: date)
        }
        return 2027  // Default if parsing fails
    }

    public struct Address: Decodable {
        public let addressLine1: String
        public let addressLine2: String
        public let city: String
        public let postalCode: String
        public let country: String
        public let dispatchMethod: String
    }

    public struct Security: Decodable {
        public let contactlessEnabled: Bool
        public let withdrawalEnabled: Bool
        public let internetPurchaseEnabled: Bool
        public let overallLimitsEnabled: Bool
    }

    public struct Limits: Decodable {
        public let dailyPurchase: Int
        public let dailyWithdrawal: Int
        public let dailyInternetPurchase: Int
        public let dailyContactlessPurchase: Int
        public let weeklyPurchase: Int
        public let weeklyWithdrawal: Int
        public let weeklyInternetPurchase: Int
        public let weeklyContactlessPurchase: Int
        public let monthlyPurchase: Int
        public let monthlyWithdrawal: Int
        public let monthlyInternetPurchase: Int
        public let monthlyContactlessPurchase: Int
        public let transactionPurchase: Int
        public let transactionWithdrawal: Int
        public let transactionInternetPurchase: Int
        public let transactionContactlessPurchase: Int
        public let dailyOverallPurchase: Int
        public let weeklyOverallPurchase: Int
        public let monthlyOverallPurchase: Int

        public let dailyContactlessPurchaseAvailable: Int
        public let dailyContactlessPurchaseUsed: Int
        public let dailyInternetPurchaseAvailable: Int
        public let dailyInternetPurchaseUsed: Int
        public let dailyOverallPurchaseAvailable: Int
        public let dailyOverallPurchaseUsed: Int
        public let dailyPurchaseAvailable: Int
        public let dailyPurchaseUsed: Int
        public let dailyWithdrawalAvailable: Int
        public let dailyWithdrawalUsed: Int

        public let monthlyContactlessPurchaseAvailable: Int
        public let monthlyContactlessPurchaseUsed: Int
        public let monthlyInternetPurchaseAvailable: Int
        public let monthlyInternetPurchaseUsed: Int
        public let monthlyOverallPurchaseAvailable: Int
        public let monthlyOverallPurchaseUsed: Int
        public let monthlyPurchaseAvailable: Int
        public let monthlyPurchaseUsed: Int
        public let monthlyWithdrawalAvailable: Int
        public let monthlyWithdrawalUsed: Int

        public let weeklyContactlessPurchaseAvailable: Int
        public let weeklyContactlessPurchaseUsed: Int
        public let weeklyInternetPurchaseAvailable: Int
        public let weeklyInternetPurchaseUsed: Int
        public let weeklyOverallPurchaseAvailable: Int
        public let weeklyOverallPurchaseUsed: Int
        public let weeklyPurchaseAvailable: Int
        public let weeklyPurchaseUsed: Int
        public let weeklyWithdrawalAvailable: Int
        public let weeklyWithdrawalUsed: Int
    }
}
