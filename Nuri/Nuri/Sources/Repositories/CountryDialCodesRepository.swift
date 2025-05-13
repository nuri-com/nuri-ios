import Combine
import Foundation

protocol CountryDialCodesRepositoryType {
    var dialCodes: [CountryDialCode] { get }
}

final class CountryDialCodesRepository: CountryDialCodesRepositoryType {

    var dialCodes: [CountryDialCode] = []

    init() {
        do {
            dialCodes = try loadDialCodes()
        } catch {
            print(error)
        }
    }

    private func loadDialCodes() throws -> [CountryDialCode] {
        guard let url = Bundle.main.url(forResource: "dial-codes", withExtension: "json") else {
            throw BundleError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([CountryDialCode].self, from: data)
    }
}

enum BundleError: Error {
    case fileNotFound
}
