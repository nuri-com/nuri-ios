public struct CreateUserInput: Encodable {
    public let firstName: String
    public let lastName: String
    public let email: String
    public let mobile: Mobile
    public let address: Address

    public struct Mobile: Encodable {
        public let countryCode: String
        public let number: String
    }

    public struct Address: Encodable {
        public let addressLine1: String
        public let city: String
        public let country: String
        public let postalCode: String
    }
}
