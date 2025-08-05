import Foundation
import CommonCrypto

// --- Configuration ---
let apiKey = "_TbS1cXGStMmYBJtcoYSA7we2lQUky_6TMo-aGLvWJM="
let apiSecret = "43jBa65VEoLC5O4O48pDruayz5Q43IlhgyGbkYPcMHE="
let baseUrl = "https://www.sandbox.striga.com/api"
let endpoint = "/v1/user/create"

// --- User Data ---
let uniqueEmail = "testuser.\(UUID().uuidString)@nuri.com"
let userData: [String: Any] = [
    "firstName": "Maximilian",
    "lastName": "Mustermann",
    "email": uniqueEmail,
    "mobile": [
        "countryCode": "+49",
        "number": "17612345678"
    ],
    "dateOfBirth": [
        "year": 1990,
        "month": 1,
        "day": 15
    ],
    "address": [
        "addressLine1": "Musterstrasse 1",
        "city": "Berlin",
        "postalCode": "10115",
        "country": "DE"
    ]
]

// --- HMAC Signature Generation (using CommonCrypto) ---
func generateHmac(time: String, body: String) -> String {
    let key = apiSecret.data(using: .utf8)!
    let message = "\(time)\(endpoint)\(body)".data(using: .utf8)!
    
    var hmac = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    key.withUnsafeBytes { keyBytes in
        message.withUnsafeBytes { messageBytes in
            CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), keyBytes.baseAddress, key.count, messageBytes.baseAddress, message.count, &hmac)
        }
    }
    
    return Data(hmac).map { String(format: "%02hhx", $0) }.joined()
}

// --- Main Execution ---
func runTest() {
    let currentTime = String(Int(Date().timeIntervalSince1970 * 1000))
    
    do {
        let jsonData = try JSONSerialization.data(withJSONObject: userData, options: [])
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        let hmacSignature = generateHmac(time: currentTime, body: jsonString)
        
        let url = URL(string: "\(baseUrl)\(endpoint)")!
        
        print("--- Test Script ---")
        print("Email: \(uniqueEmail)")
        print("Timestamp: \(currentTime)")
        print("HMAC Signature: \(hmacSignature)")
        print("--------------------")
        
        print("--- Simulating curl command ---")
        print("curl -X POST \"")
        print("  '\(url.absoluteString)' \"")
        print("  -H 'api-key: \(apiKey)' \"")
        print("  -H 'Authorization: HMAC \(currentTime):\(hmacSignature)' \"")
        print("  -H 'Content-Type: application/json' \"")
        print("  -d '\(jsonString)'")
        print("--------------------\n")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        request.setValue("HMAC \(currentTime):\(hmacSignature)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            print("--- Server Response ---")
            if let error = error {
                print("Error: \(error.localizedDescription)")
                exit(1)
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Status Code: \(httpResponse.statusCode)")
            }
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("Response Body:")
                print(responseString)
            }
            print("--------------------")
            exit(0)
        }
        
        task.resume()
        
    } catch {
        print("Error creating JSON: \(error)")
        exit(1)
    }
}

runTest()
dispatchMain()