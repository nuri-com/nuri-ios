import Combine

final class VerifyCallViewModel: ObservableObject {

    @Published var viewState: VerifyCallViewState = .empty

    var completion: (() -> Void)?

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
        completion?()
    }
}
