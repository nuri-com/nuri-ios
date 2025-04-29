import Combine
import Foundation

protocol DialCodesRepositoryType {
    var dialCodes: [DialCode] { get }
}

final class DialCodesRepository: DialCodesRepositoryType {

    var dialCodes: [DialCode] = []

    init() {
        do {
            dialCodes = try loadDialCodes()
        } catch {
            print(error)
        }
    }

    private func loadDialCodes() throws -> [DialCode] {
        guard let url = Bundle.main.url(forResource: "dial-codes", withExtension: "json") else {
            throw BundleError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([DialCode].self, from: data)
    }
}

enum BundleError: Error {
    case fileNotFound
}
