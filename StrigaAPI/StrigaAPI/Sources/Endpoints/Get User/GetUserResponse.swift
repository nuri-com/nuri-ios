import Foundation

public struct GetUserResponse: Decodable {
    public let userId: String
    public let email: String
    public let firstName: String
    public let lastName: String
    public let mobile: Mobile?
    public let dateOfBirth: DateOfBirth?
    public let address: Address?
    public let createdAt: String
    public let KYC: KYCInfo
    
    public struct Mobile: Decodable {
        public let countryCode: String
        public let number: String
    }
    
    public struct DateOfBirth: Decodable {
        public let year: Int
        public let month: Int
        public let day: Int
    }
    
    public struct Address: Decodable {
        public let addressLine1: String
        public let addressLine2: String?
        public let city: String
        public let country: String
        public let postalCode: String
        public let state: String?
    }
    
    public struct KYCInfo: Decodable {
        public let status: String
        public let rejectionReasons: [String]?
    }
}