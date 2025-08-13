import Foundation

public struct EnrichAccountResponse: Codable {
    public let accountId: String
    public let iban: String?
    public let bic: String?
    public let accountHolderName: String?
    public let bankCountry: String?
    public let bankName: String?
    public let currency: String
    public let blockchainDepositAddress: String?
    public let blockchainNetworks: [BlockchainNetwork]?
    
    private enum CodingKeys: String, CodingKey {
        case accountId
        case iban = "IBAN"
        case bic = "BIC"
        case accountHolderName
        case bankCountry
        case bankName
        case currency
        case blockchainDepositAddress
        case blockchainNetworks
    }
    
    public struct BlockchainNetwork: Codable {
        public let network: String
        public let blockchainDepositAddress: String
    }
}