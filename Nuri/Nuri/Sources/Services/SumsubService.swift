import Foundation
#if canImport(UIKit)
import UIKit // For UIDevice.identifierForVendor
#endif
import CryptoKit

/// Provides Sumsub applicant access tokens for the Mobile SDK.
/// – DEBUG build: generates a fresh sandbox token on-device using the App Token + Secret.
/// – RELEASE build: expects your backend to supply the token.
final class SumsubService {

    static let shared = SumsubService()
    private init() {}

#if DEBUG
    // Your Sandbox App Token & Secret (safe in DEBUG only!)
    private let appToken  = "sbx:KPfLzjksGrj7tvuDGBo5vb4m.m9h1nVQGvq4HlLuCnWKqLhgoW1QJ9wbn"
    private let appSecret = "aRHUv6zVYzbPuzSxgwyrrjIcWc3tI0HO"

    /// Generates a fresh applicant access token directly via Sumsub REST.
    /// Returns `nil` on any error.
    func fetchAccessToken(completion: @escaping (String?) -> Void) {
        #if DEBUG
        print("[SumsubService] Fetching access token…")
        #endif
        let userId     = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let levelName  = "id-and-liveness"
        let ttlInSecs  = 10 * 60           // 10 minutes

        guard let bodyData = try? JSONSerialization.data(withJSONObject: [
            "ttlInSecs": ttlInSecs,
            "userId": userId,
            "levelName": levelName
        ], options: []) else {
            completion(nil)
            return
        }

        let path = "/resources/accessTokens/sdk"
        let ts   = Int(Date().timeIntervalSince1970)
        let method = "POST"

        // Build signature string
        var signaturePayload = "\(ts)\(method)\(path)"
        signaturePayload += String(data: bodyData, encoding: .utf8) ?? ""

        // HMAC-SHA256
        let key = SymmetricKey(data: Data(appSecret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(signaturePayload.utf8), using: key)
        let sigHex = mac.map { String(format: "%02x", $0) }.joined()

        // Build request
        var req = URLRequest(url: URL(string: "https://api.sumsub.com\(path)")!)
        req.httpMethod = method
        req.httpBody   = bodyData
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(appToken, forHTTPHeaderField: "X-App-Token")
        req.setValue(sigHex,  forHTTPHeaderField: "X-App-Access-Sig")
        req.setValue(String(ts), forHTTPHeaderField: "X-App-Access-Ts")

        let task = URLSession.shared.dataTask(with: req) { data, response, error in
            #if DEBUG
            if let http = response as? HTTPURLResponse {
                print("[SumsubService] HTTP status: \(http.statusCode)")
            }
            if let error = error {
                print("[SumsubService] Network error: \(error.localizedDescription)")
            }
            if let data = data, let str = String(data: data, encoding: .utf8) {
                print("[SumsubService] Response body: \(str)")
            }
            #endif
            guard error == nil,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["token"] as? String else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            DispatchQueue.main.async { completion(token) }
        }
        task.resume()
    }
#else
    /// In production you must fetch the token from your backend.
    func fetchAccessToken(completion: @escaping (String?) -> Void) {
        assertionFailure("Implement backend token fetch for RELEASE builds")
        completion(nil)
    }
#endif
} 