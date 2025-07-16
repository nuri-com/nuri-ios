import Foundation

public struct CreateUserResponse: Decodable {
    public let firstName: String
    public let lastName: String
    public let email: String
    public let mobile: Mobile
    public let address: Address

    public struct Mobile: Decodable {
        public let countryCode: String
        public let number: String
    }

    public struct Address: Decodable {
        public let addressLine1: String
        public let city: String
        public let country: String
        public let postalCode: String
    }
}
