import SwiftUI
import StrigaAPI

class CreatingCardViewModel: ObservableObject {

    @Published var viewState: CreatingCardViewState = .empty
    private let cardService = CardCreationServiceProvider.shared.service

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
            guard let userId = session.userId else {
                print("[Lukas] Session userId missing")
                return
            }
            
            // Use firstName + lastName for card name
            let name: String
            if let firstName = session.firstName, let lastName = session.lastName {
                name = "\(firstName) \(lastName)"
                print("[Lukas] Using full name: \(name)")
            } else if let sessionName = session.name {
                name = sessionName
                print("[Lukas] Using session name: \(name)")
            } else {
                print("[Lukas] ERROR: No name available for card creation")
                return
            }
            let response = try await cardService.createCard(name: name, userId: userId)
            print("[Lukas] Card created \(response)")
            UserSettings().strigaUserId = userId
            UserSettings().strigaCardId = response.id
            UserSettings().strigaWalletId = response.parentWalletId
            
            // Post notification that card was created
            NotificationCenter.default.post(name: Notification.Name("CardCreatedSuccessfully"), object: nil)
            
            await updateViewState(action: .finish)
        } catch {
            print("[Lukas] Error creating card: \(error)")
            if let errorResponse = error as? ErrorResponse {
                print("[Lukas] Error details:")
                print("[Lukas] - Message: \(errorResponse.message)")
                print("[Lukas] - Code: \(errorResponse.errorCode)")
                print("[Lukas] - Details: \(errorResponse.errorDetails)")
            }
            // TODO: Show error to user and possibly retry
        }
    }


}
