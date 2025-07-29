import SwiftUI
import StrigaAPI

class CreatingCardViewModel: ObservableObject {

    @Published var viewState: CreatingCardViewState = .empty

    private func reduce(viewState: CreatingCardViewState, action: CreatingCardViewState.Action) -> CreatingCardViewState {
        var viewState = viewState
        switch action {
        case .finish:
            viewState.isFinished = true
        }
        return viewState
    }

    @MainActor
    private func updateViewState(action: CreatingCardViewState.Action) async {
        viewState = reduce(viewState: viewState, action: action)
    }

    func createCard() async {
        do {
            print("[Lukas] Creating card ....")
            let session = StrigaSession.shared
            guard let name = session.name, let userId = session.userId else {
                print("[Lukas] Session details missing")
                return
            }
            let password = generatePassword()
            print("[Lukas] generated password: \(password)")
            let response = try await StrigaService.shared.createCard(.init(
                nameOnCard: name,
                userId: userId,
                type: "VIRTUAL",
                threeDSecurePassword: password
            ))
            print("[Lukas] Card created \(response)")
            UserSettings().strigaUserId = userId
            await updateViewState(action: .finish)
        } catch {
            if let error = error as? ValidationErrorResponse, error.errorCode == "00002" { // password too weak
                print("[Lukas] Password too weak. Trying with a new password.")
                await createCard()
            } else {
                print("[Lukas] Error creating card: \(error)")
            }
        }
    }

    private func generatePassword() -> String {
        let allowedCharacters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!\"#;:?&*()+=/\\,.[]{}")
        let passwordLength = Int.random(in: 8...36)

        var password = ""
        for _ in 0..<passwordLength {
            if let randomChar = allowedCharacters.randomElement() {
                password.append(randomChar)
            }
        }

        return password
    }

}
