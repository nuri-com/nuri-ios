struct CountryDialCode: Equatable, Codable, Sendable {
    let country: String
    let dialCode: String

    enum CodingKeys: String, CodingKey {
        case country = "name"
        case dialCode = "dial_code"
    }
}
