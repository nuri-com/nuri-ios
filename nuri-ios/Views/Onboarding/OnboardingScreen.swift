protocol OnboardingScreenDelegate: AnyObject {
    func didFinish(screen: OnboardingScreen)
}

enum OnboardingScreen: Equatable {
    case phoneNumber
    case verificationByCall
    case setupCardExplanation
}
