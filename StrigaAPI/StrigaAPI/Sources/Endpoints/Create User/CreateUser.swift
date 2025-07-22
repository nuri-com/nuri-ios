public struct CreateUser: Encodable {
    public let firstName: String
    public let lastName: String
    public let email: String
    public let mobile: Mobile
    public let address: Address?

    public init(firstName: String, lastName: String, email: String, mobile: CreateUser.Mobile, address: CreateUser.Address?) {
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.mobile = mobile
        self.address = address
    }

    public struct Mobile: Encodable {
        public let countryCode: String
        public let number: String

        public init(countryCode: String, number: String) {
            self.countryCode = countryCode
            self.number = number
        }
    }

    public struct Address: Encodable {
        public let addressLine1: String
        public let city: String
        public let country: String
        public let postalCode: String

        public init(addressLine1: String, city: String, country: String, postalCode: String) {
            self.addressLine1 = addressLine1
            self.city = city
            self.country = country
            self.postalCode = postalCode
        }
    }
}
