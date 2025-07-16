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
            data = Data(String("{}").utf8)
        }
        return try generateHeaders(for: path, method: method, body: data)
    }

    // MARK: - Private

    private func generateHeaders(for path: String, method: String, body: Data) throws -> [String: String] {
        let timestamp = makeTimestamp()
        let md5Hex = makeMD5Hex(body: body)
        let signature = makeSignature(timestamp: timestamp, method: method, path: path, md5Hex: md5Hex)
        let hexSignature = signature.map { String(format: "%02hhx", $0) }.joined()
        let authorization = "HMAC \(timestamp):\(hexSignature)"
        return [
            "authorization": authorization,
            "api-key": configuration.key,
            "Content-Type": "application/json"
        ]
    }

    private func makeTimestamp() -> String {
        let date = Date().timeIntervalSince1970
        let seconds = Int(date * 1000)
        let string = String(seconds)
        return string
    }

    private func makeMD5Hex(body: Data) -> String {
        let md5Hash = Insecure.MD5.hash(data: body)
        let md5Hex = md5Hash.map { String(format: "%02hhx", $0) }.joined()
        return md5Hex
    }

    private func makeSignature(timestamp: String, method: String, path: String, md5Hex: String) -> HMAC<SHA256>.MAC {
        let secret = Data(configuration.secret.utf8)
        let key = SymmetricKey(data: secret)
        var hmac = HMAC<SHA256>.init(key: key)
        hmac.update(data: Data(timestamp.utf8))
        hmac.update(data: Data(method.uppercased().utf8))
        hmac.update(data: Data(path.utf8))
        hmac.update(data: Data(md5Hex.utf8))
        return hmac.finalize()
    }
}
