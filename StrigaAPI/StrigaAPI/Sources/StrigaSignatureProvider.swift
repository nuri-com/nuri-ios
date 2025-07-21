import Foundation
import CryptoKit

class StrigaSignatureProvider {

    // MARK: - Dependencies

    private let configuration: StrigaConfiguration

    // MARK: - Initialization

    init(configuration: StrigaConfiguration) {
        self.configuration = configuration
    }

    // MARK: - Public

    func headers<E: Encodable>(for request: URLRequest, body: E?) throws -> [String : String] {
        guard let path = request.url?.path,
              let method = request.httpMethod else {
            throw URLError(.badURL)
        }
        let data: Data
        if let body = body {
            data = try JSONEncoder().encode(body)
        } else {
            data = try JSONEncoder().encode(EmptyRequest())
        }
        return try generateHeaders(for: path, method: method, body: data)
    }

    // MARK: - Private

    private func generateHeaders(for path: String, method: String, body: Data) throws -> [String: String] {
        let validPath = makeValidPath(path)
        print("[Striga] \(validPath)")
        let timestamp = makeTimestamp()
        let md5Hex = makeMD5Hex(body: body)
        let stringToSign = [timestamp, method.uppercased(), validPath, md5Hex].joined()
        let key = SymmetricKey(data: Data(configuration.secret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(stringToSign.utf8), using: key)
        let hexSignature = signature.map { String(format: "%02hhx", $0) }.joined()
        let authorization = "HMAC \(timestamp):\(hexSignature)"
        return [
            "Authorization": authorization,
            "api-key": configuration.key,
            "Content-Type": "application/json"
        ]
    }

    private func makeTimestamp() -> String {
        let timestamp = Date().timeIntervalSince1970
        let seconds = Int(timestamp * 1000)
        return String(seconds)
    }

    private func makeMD5Hex(body: Data) -> String {
        let md5Hash = Insecure.MD5.hash(data: body)
        let md5Hex = md5Hash.map { String(format: "%02hhx", $0) }.joined()
        return md5Hex
    }

    private func makeValidPath(_ path: String) -> String {
        let pattern = #"^/api/v[0-9]+"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(location: 0, length: path.utf16.count)
            let modifiedPath = regex.stringByReplacingMatches(in: path, options: [], range: range, withTemplate: "")
            return modifiedPath.isEmpty ? "/" : modifiedPath
        }
        return path
    }
}
