import Foundation

public struct StartHostedCardSession: Encodable {
    public let userId: String
    public let ip: String
    
    public init(userId: String, ipAddress: String) {
        self.userId = userId
        self.ip = ipAddress
    }
    
    // Alternative init for clarity
    public init(userId: String, ip: String) {
        self.userId = userId
        self.ip = ip
    }
}

public struct StartHostedCardSessionResponse: Decodable {
    public let sessionId: String?
    public let expiresAt: String?
    public let name: String? // Error name if present
    public let level: String? // Error level if present
    
    public var isError: Bool {
        return name != nil && sessionId == nil
    }
    
    public var errorMessage: String? {
        return name
    }
}
