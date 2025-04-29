struct DialCode: Equatable, Codable, Sendable {
    let country: String
    let code: String
    let dialCode: String

    enum CodingKeys: String, CodingKey {
        case country = "name"
        case code
        case dialCode = "dial_code"
    }
}
