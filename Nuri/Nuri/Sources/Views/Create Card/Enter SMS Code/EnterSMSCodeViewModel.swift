import Combine
import StrigaAPI
import IdensicMobileSDK

final class EnterSMSCodeViewModel: ObservableObject {

    var striga = StrigaService.shared

    @Published var viewState: EnterSMSCodeViewState = .empty

    init() {
        viewState = .init(
            title: "SMS Verification",
            subtitle: "We've sent you a code to your phone number",
            illustrationName: "phone_update",
            codeTextField: .init(
                label: "Code",
                text: "",
                placeholder: "Verification Code",
                textChangeHandler: .init { [weak self] text in
                    self?.handleTextChange(text)
                }
            ),
            isLoadingAnimationActive: false,
            showKYC: false,
            isCreatingCard: false
        )
    }

    private func reduce(viewState: EnterSMSCodeViewState, action: EnterSMSCodeViewState.Action) -> EnterSMSCodeViewState {
        var viewState = viewState
        switch action {
        case .startLoadingAnimation:
            viewState.isLoadingAnimationActive = true
        case .showKYC:
            viewState.showKYC = true
        case .showCreatingCardView:
            viewState.isCreatingCard = true
        }
        return viewState
    }

    @MainActor
    private func updateViewState(action: EnterSMSCodeViewState.Action) async {
        viewState = reduce(viewState: viewState, action: action)
    }

    private func handleTextChange(_ text: String) {
        if text.count == 6 {
            sendVerifySMSRequest(code: text)
        }
    }

    private func sendVerifySMSRequest(code: String) {
        guard let userId = StrigaSession.shared.userId else {
            print("[Lukas] No Striga user id")
            return
        }
        print("[Lukas] Verifiying your mobile number...")
        Task {
            await updateViewState(action: .startLoadingAnimation)
            do {
                try await striga.verifyMobile(.init(
                    userId: userId,
                    verificationCode: code
                ))
                let response = try await striga.startKYC(.init(userId: userId))
                await presentKYC(token: response.token)
            } catch {
                print("[Lukas] Error: \(error)")
            }
        }
    }

    @MainActor
    private func presentKYC(token: String) async {
        let sdk = SNSMobileSDK(
            accessToken: token
        )
        guard sdk.isReady else {
            print("Initialization failed: " + sdk.verboseStatus)
            return
        }
        sdk.tokenExpirationHandler { onComplete in
            print("[Lukas] Token expired")
            onComplete("")
        }
        sdk.present()
        sdk.verificationHandler { [weak self] (isApproved) in
            print("[Lukas] verificationHandler: Applicant is " + (isApproved ? "approved" : "finally rejected"))
            if isApproved {
                Task {
                    await self?.updateViewState(action: .showCreatingCardView)
                }
            }
        }
    }
}
