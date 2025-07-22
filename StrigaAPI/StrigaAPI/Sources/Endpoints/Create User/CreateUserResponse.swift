import Foundation

public struct CreateUserResponse: Decodable {
    public let userId: String
    public let email: String
    public let mobile: Mobile
    public let KYC: KYCInfo
    public let emailVerification: Verification
    public let mobileVerification: Verification
    public let missingFields: [String]

    public struct Mobile: Codable {
        public let countryCode: String
        public let number: String
    }

    public struct KYCInfo: Codable {
        public let emailVerified: Bool
        public let mobileVerified: Bool
        public let currentTier: Int?
        public let status: String
        public let tier0: Tier?
        public let tier1: Tier1?
        public let tier2: Tier?
        public let tier3: Tier?

        public struct Tier: Codable {
            public let eligible: Bool
            public let status: String
        }

        public struct Tier1: Codable {
            public let eligible: Bool
            public let status: String
            public let inboundLimitConsumed: Limits
            public let inboundLimitAllowed: Limits

            public struct Limits: Codable {
                public let all: String
                public let va: String
            }
        }
    }

    public struct Verification: Codable {
        public let dateExpires: String
    }
}
