import StrigaAPI

class StrigaSession {
    static let shared = StrigaSession()
    var userId: String?
    var name: String?
    var address: CreateUser.Address?
}
