import Combine

protocol VerifyCallViewModelType: AnyObject {
    var delegate: OnboardingScreenDelegate? { get set }
    func toViewModel() -> VerifyCallViewModel
}

protocol VerifyCallViewStateProviding {
    var viewState: VerifyCallViewState { get }
}

final class VerifyCallViewModel: ObservableObject, VerifyCallViewModelType, VerifyCallViewStateProviding {

    weak var delegate: (any OnboardingScreenDelegate)?

    @Published var viewState: VerifyCallViewState = .empty

    func toViewModel() -> VerifyCallViewModel {
        return self
    }
    
    init() {
        viewState = .init(
            title: "Automatic Verification",
            subtitle: "Nuri auto-verifies your account by calling your phone number",
            illustrationName: "phone_update",
            successMessage: nil
        )

        Task {
            try await Task.sleep(for: .seconds(2))
            await showSuccessMessage()
            try await Task.sleep(for: .seconds(2))
            await dismiss()
        }
    }

    @MainActor
    private func showSuccessMessage() {
        viewState.successMessage = "Verification successful"
    }

    @MainActor
    private func dismiss() {
        delegate?.didFinish(screen: .verificationByCall)
    }
}
