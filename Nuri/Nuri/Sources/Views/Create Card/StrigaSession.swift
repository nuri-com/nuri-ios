import Foundation

class StrigaSession {
    static let shared = StrigaSession()
    var userId: String?
    var cardId: String?
    var firstName: String?
    var lastName: String?
    var name: String? // Keep for backward compatibility
    var email: String?
    var phoneNumber: String?
    var phoneCountryCode: String?
    var address: Address?
    var dateOfBirth: Date?
    
    struct Address {
        let addressLine1: String
        let city: String
        let country: String
        let postalCode: String
    }
    
    struct Date {
        let year: Int32
        let month: Int32
        let day: Int32
    }
}
