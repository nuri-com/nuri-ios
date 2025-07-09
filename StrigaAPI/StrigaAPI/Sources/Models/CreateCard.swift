public struct CreateCard: Encodable {
    public let nameOnCard: String
    public let userId: String
    public let address: Address
    public let type: String
    public let threeDSecurePassword: String

    public init(nameOnCard: String, userId: String, address: CreateCard.Address, type: String, threeDSecurePassword: String) {
        self.nameOnCard = nameOnCard
        self.userId = userId
        self.address = address
        self.type = type
        self.threeDSecurePassword = threeDSecurePassword
    }

    public struct Address: Encodable {
        public let addressLine1: String
        public let addressLine2: String
        public let postalCode: String
        public let city: String
        public let countryCode: String
        public let dispatchMethod: String

        public init(addressLine1: String, addressLine2: String, postalCode: String, city: String, countryCode: String, dispatchMethod: String) {
            self.addressLine1 = addressLine1
            self.addressLine2 = addressLine2
            self.postalCode = postalCode
            self.city = city
            self.countryCode = countryCode
            self.dispatchMethod = dispatchMethod
        }
    }
}
