import Combine

protocol SetupCardExplanationViewModelType: AnyObject {
    var delegate: OnboardingScreenDelegate? { get set }
    func toViewModel() -> SetupCardExplanationViewModel
}

protocol SetupCardExplanationViewStateProviding {
    var viewState: SetupCardExplanationViewState { get }
}

final class SetupCardExplanationViewModel: ObservableObject, SetupCardExplanationViewModelType {
    weak var delegate: OnboardingScreenDelegate?

    @Published var viewState: SetupCardExplanationViewState = .empty

    init() {
        viewState = .init(
            title: "Scan Bitcoin Card &\nRegister Fingerprint",
            subtitle: "**Hold your biometric card against the NFC sensor** of your phone and touch the fingerprint sensor on the card **6-Times**.",
            illustrationName: "scan_card",
            continueButton: .init(
                text: "I'm ready to scan",
                action: { [weak self] in
                    self?.continueButtonPressed()
                }
            )
        )
    }

    func toViewModel() -> SetupCardExplanationViewModel {
        return self
    }

    private func continueButtonPressed() {
        delegate?.didFinish(screen: .setupCardExplanation)
    }
}
