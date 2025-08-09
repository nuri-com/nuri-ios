import Foundation
import CryptoKit

class SignatureProvider {

    // MARK: - Dependencies

    private let configuration: StrigaConfiguration
    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    // MARK: - Initialization

    init(configuration: StrigaConfiguration) {
        self.configuration = configuration
    }

    // MARK: - Public

    func headers(for request: URLRequest, body: Data?) throws -> [String : String] {
        guard let path = request.url?.path,
              let method = request.httpMethod else {
            throw URLError(.badURL)
        }
        let bodyData = try body ?? jsonEncoder.encode(EmptyRequest())
        return try generateHeaders(for: path, method: method, body: bodyData)
    }

    // MARK: - Private

    private func generateHeaders(for path: String, method: String, body: Data) throws -> [String: String] {
        let validPath = makeValidPath(path)
        let timestamp = makeTimestamp()
        let md5Hex = makeMD5Hex(body: body)
        let stringToSign = [timestamp, method.uppercased(), validPath, md5Hex].joined()
        
        print("[SignatureProvider] Original path: \(path)")
        print("[SignatureProvider] Valid path for HMAC: \(validPath)")
        print("[SignatureProvider] Timestamp: \(timestamp)")
        print("[SignatureProvider] Method: \(method.uppercased())")
        print("[SignatureProvider] MD5 of body: \(md5Hex)")
        print("[SignatureProvider] String to sign: \(stringToSign)")
        
        let key = SymmetricKey(data: Data(configuration.secret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(stringToSign.utf8), using: key)
        let hexSignature = signature.map { String(format: "%02hhx", $0) }.joined()
        let authorization = "HMAC \(timestamp):\(hexSignature)"
        
        print("[SignatureProvider] HMAC signature: \(hexSignature)")
        
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
