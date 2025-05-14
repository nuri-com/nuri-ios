protocol OnboardingScreenDelegate: AnyObject {
    func didFinish(screen: OnboardingScreen)
}

enum OnboardingScreen: Equatable {
    case login
    case phoneNumber
    case verificationByCall
    case setupCardExplanation
    case setupCard
}
