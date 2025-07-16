import Foundation

public struct InitiateBankTransferResponse: Codable {
    public let challengeId: String
    public let dateExpires: String
    public let transaction: TransactionDetails
    public let feeEstimate: FeeEstimate

    public struct TransactionDetails: Codable {
        public let syncedOwnerId: String
        public let sourceAccountId: String
        public let iban: String
        public let bic: String
        public let amount: String
        public let memo: String
        public let status: String
        public let txType: String
        public let parentWalletId: String
        public let currency: String
    }

    public struct FeeEstimate: Codable {
        public let totalFee: String
        public let networkFee: String
        public let ourFee: String
        public let theirFee: String
        public let feeCurrency: String
        public let fixedFeeDetails: FixedFeeDetails
        public let percentageFeeDetails: PercentageFeeDetails

        public struct FixedFeeDetails: Codable {
            public let amount: String
            public let exchangeRate: String
            public let appliedFeeCents: String
        }

        public struct PercentageFeeDetails: Codable {
            public let amount: String
            public let appliedFeeBps: String
        }
    }
}
