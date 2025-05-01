struct CountryDialCode: Equatable, Codable, Sendable {
    let country: String
    let countryCode: String
    let dialCode: String

    enum CodingKeys: String, CodingKey {
        case country = "name"
        case countryCode = "code"
        case dialCode = "dial_code"
    }
}
