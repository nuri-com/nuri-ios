import Combine

final class EnterSMSCodeViewModel: ObservableObject {

    @Published var viewState: EnterSMSCodeViewState = .empty

    var completion: (() -> Void)?

    init() {
        viewState = .init(
            title: "Automatic Verification",
            subtitle: "Nuri auto-verifies your account by calling your phone number",
            illustrationName: "phone_update",
            codeTextField: .init(
                label: "Code",
                text: "",
                placeholder: ""
            )
        )
    }
}
