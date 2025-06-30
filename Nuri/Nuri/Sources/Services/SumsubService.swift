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

    // Stores the last userId used to request a token so we can query applicant info later.
    private(set) var lastUserId: String?

    /// Generates a fresh applicant access token directly via Sumsub REST.
    /// Returns `nil` on any error.
    func fetchAccessToken(completion: @escaping (String?) -> Void) {
        #if DEBUG
        print("[SumsubService] Fetching access token…")
        #endif
        let userId     = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        lastUserId = userId
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

    /// Fetches applicant first + last name for the current userId via Sumsub REST.
    /// Calls completion(nil) on any error.
    func fetchApplicantName(completion: @escaping (String?) -> Void) {
        guard let userId = lastUserId else { completion(nil); return }

        let path = "/resources/applicants/-;externalUserId=\(userId)/one"
        let ts   = Int(Date().timeIntervalSince1970)
        let method = "GET"

        // Signature string per Sumsub docs
        let signaturePayload = "\(ts)\(method)\(path)"
        let key = SymmetricKey(data: Data(appSecret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(signaturePayload.utf8), using: key)
        let sigHex = mac.map { String(format: "%02x", $0) }.joined()

        var req = URLRequest(url: URL(string: "https://api.sumsub.com\(path)")!)
        req.httpMethod = method
        req.setValue(appToken, forHTTPHeaderField: "X-App-Token")
        req.setValue(sigHex,  forHTTPHeaderField: "X-App-Access-Sig")
        req.setValue(String(ts), forHTTPHeaderField: "X-App-Access-Ts")

        URLSession.shared.dataTask(with: req) { data, resp, err in
            #if DEBUG
            if let http = resp as? HTTPURLResponse {
                print("[SumsubService] fetchApplicantName status: \(http.statusCode)")
            }
            if let error = err {
                print("[SumsubService] fetchApplicantName network error: \(error.localizedDescription)")
            }
            if let data = data, let str = String(data: data, encoding: .utf8) {
                print("[SumsubService] fetchApplicantName response body: \(str)")
            }
            #endif
            guard err == nil,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let info = json["info"] as? [String: Any]
            else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            var firstName = info["firstName"] as? String
            var lastName  = info["lastName"]  as? String

            // Fallback: some accounts use fixedInfo dictionary
            if firstName == nil || lastName == nil {
                if let fixed = info["fixedInfo"] as? [String: Any] {
                    if firstName == nil {
                        firstName = fixed["firstName"] as? String ?? fixed["first_name"] as? String
                    }
                    if lastName == nil {
                        lastName = fixed["lastName"] as? String ?? fixed["last_name"] as? String
                    }
                }
            }

            let fn = firstName ?? ""
            let ln = lastName ?? ""
            let nameToReturn: String?
            if !fn.isEmpty {
                nameToReturn = fn
            } else if !ln.isEmpty {
                nameToReturn = ln // fallback (unlikely)
            } else {
                nameToReturn = nil
            }

            DispatchQueue.main.async {
                completion(nameToReturn?.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }.resume()
    }
#else
    /// In production you must fetch the token from your backend.
    func fetchAccessToken(completion: @escaping (String?) -> Void) {
        assertionFailure("Implement backend token fetch for RELEASE builds")
        completion(nil)
    }
#endif
} 