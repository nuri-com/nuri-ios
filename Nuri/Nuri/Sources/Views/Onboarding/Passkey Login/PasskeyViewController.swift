// Hanko Passkey Login – Anonym (ohne E-Mail)
// Swift, UIKit, iOS 16+

import UIKit
import AuthenticationServices

class PasskeyViewController: UIViewController, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    let relyingPartyId = "passkeys.hanko.io"
    let hankoBaseURL = URL(string: "https://passkeys.hanko.io/4691f0bb-4166-4ebe-86e4-30bc31ce5f56")!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        let registerButton = UIButton(type: .system)
        registerButton.setTitle("Register with Passkey", for: .normal)
        registerButton.addTarget(self, action: #selector(registerWithPasskey), for: .touchUpInside)
        registerButton.frame = CGRect(x: 40, y: 200, width: 300, height: 50)
        view.addSubview(registerButton)

        let loginButton = UIButton(type: .system)
        loginButton.setTitle("Login with Passkey", for: .normal)
        loginButton.addTarget(self, action: #selector(loginWithPasskey), for: .touchUpInside)
        loginButton.frame = CGRect(x: 40, y: 300, width: 300, height: 50)
        view.addSubview(loginButton)
    }

    @objc func registerWithPasskey() {

        let url = hankoBaseURL.appendingPathComponent("/webauthn/register/start")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        request.httpBody = try? JSONEncoder().encode([:])
        print("start register with request \(request)")
        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else { print("Start register error: \(error!.localizedDescription)"); return }
            if let response = try? JSONDecoder().decode(HankoChallenge.self, from: data) {
                DispatchQueue.main.async {
                    self.handleRegistrationChallenge(response)
                }
            } else {
                print("data \(String(data: data, encoding: .utf8))")
            }
        }.resume()
    }

    func handleRegistrationChallenge(_ challenge: HankoChallenge) {
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: relyingPartyId)
        guard let challengeData = Data(base64Encoded: challenge.challenge) else { return }

        let request = provider.createCredentialRegistrationRequest(challenge: challengeData, name: "", userID: Data())
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    @objc func loginWithPasskey() {
        let url = hankoBaseURL.appendingPathComponent("/webauthn/authenticate/start")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        request.httpBody = try? JSONEncoder().encode([:])

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else { print("Start login error: \(error!.localizedDescription)"); return }
            if let response = try? JSONDecoder().decode(HankoChallenge.self, from: data) {
                DispatchQueue.main.async {
                    self.handleLoginChallenge(response)
                }
            }
        }.resume()
    }

    func handleLoginChallenge(_ challenge: HankoChallenge) {
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: relyingPartyId)
        guard let challengeData = Data(base64Encoded: challenge.challenge) else { return }

        let request = provider.createCredentialAssertionRequest(challenge: challengeData)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.view.window!
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
            print("✅ Registered with Passkey")
            // TODO: Send credential.response to /webauthn/register/finish
        } else if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
            print("✅ Logged in with Passkey")
            // TODO: Send credential.response to /webauthn/authenticate/finish
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ Authorization failed: \(error.localizedDescription)")
    }
}

struct HankoChallenge: Codable {
    let challenge: String
    // Add other fields as needed from Hanko response
}
