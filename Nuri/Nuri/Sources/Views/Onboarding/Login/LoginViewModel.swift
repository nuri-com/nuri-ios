import Combine
import AuthenticationServices

protocol LoginViewModelDelegate: OnboardingScreenDelegate {
    func presentationAnchor() -> UIWindow
}

protocol LoginViewModelType: AnyObject {
    var delegate: LoginViewModelDelegate? { get set }
    func toViewModel() -> LoginViewModel
}

protocol LoginViewStateProviding {
    var viewState: LoginViewState { get }
}

final class LoginViewModel: NSObject, ObservableObject, LoginViewModelType, LoginViewStateProviding {

    weak var delegate: (any LoginViewModelDelegate)?

    var viewState: LoginViewState = .empty

    override init() {
        super.init()

        viewState = .init(
            title: "Sign up or Login",
            subtitle: "Using Passkey",
            illustration: "",
            emailTextField: .init(label: "", text: "", placeholder: "Email", submitHandler: .init { [weak self] in
                self?.startRegistration()
            }),
            orLabel: "- or -",
            passkeyButton: .init(text: "Sign In using Passkey", action: .init { [weak self] in
                self?.startPasskeyLogin()
            })
        )
    }

    var challenge: Data?

    private func startRegistration() {
        let email = viewState.emailTextField.text.trimmingCharacters(in: .whitespaces)
        guard email.count > 5 else {
            return
        }

        let bytes = [UInt32](repeating: 0, count: 32).map { _ in arc4random() }
        let challenge = Data(bytes: bytes, count: 32)
        let securityKeyProvider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(relyingPartyIdentifier: "nuri.com")
        let securityKeyRequest = securityKeyProvider.createCredentialRegistrationRequest(
            challenge: challenge,
            displayName: email,
            name: email,
            userID: email.data(using: .utf8)!
        )
        securityKeyRequest.credentialParameters = [ ASAuthorizationPublicKeyCredentialParameters(algorithm: ASCOSEAlgorithmIdentifier.ES256) ]
        let authController = ASAuthorizationController(authorizationRequests: [securityKeyRequest])
        authController.delegate = self
        authController.presentationContextProvider = self
        authController.performRequests()
    }

    private func startPasskeyLogin() {
        PasskeyAuthCoordinator.shared.start { [weak self] result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self?.delegate?.didFinish(screen: .login)
                }
            case .failure(let error):
                print("Passkey auth failed: \(error)")
            }
        }
    }

    func toViewModel() -> LoginViewModel {
        return self
    }
}

struct ClientData: Decodable {
    let type: String
    let challenge: String
    let origin: URL
}

extension LoginViewModel: ASAuthorizationControllerDelegate {

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        print("did complete: \(authorization)")
        print("provider: \(authorization.provider.description)")
        print("credential: \(authorization.credential.description)")

        if let registration = authorization.credential as? ASAuthorizationSecurityKeyPublicKeyCredentialRegistration {
            print(String(data: registration.credentialID, encoding: .utf8) ?? "no credential id")
            print(registration.transports)
            print(String(data: registration.rawClientDataJSON, encoding: .utf8) ?? "no raw client data")
            self.challenge = (try? JSONDecoder().decode(ClientData.self, from: registration.rawClientDataJSON)).flatMap({ $0.challenge.data(using: .utf8) })
        } else if let credentialAssertion = authorization.credential as? ASAuthorizationSecurityKeyPublicKeyCredentialAssertion {
            print("A passkey was used to sign in: \(credentialAssertion)")
            delegate?.didFinish(screen: .login)
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: any Error) {
        print("Error \(error)")
    }
}

extension LoginViewModel: ASAuthorizationControllerPresentationContextProviding {

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        delegate!.presentationAnchor()
    }
}
