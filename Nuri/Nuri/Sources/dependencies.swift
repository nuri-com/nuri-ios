func injectDependencies(into container: ContainerType) {

    container.register { container -> RootWireframeType in
        RootWireframe(
            onboardingWireframe: container.resolve()
        )
    }

    container.register { container -> OnboardingWireframeType in
        OnboardingWireframe(
            container: container
        )
    }

    container.register { container -> CountryDialCodesRepositoryType in
        CountryDialCodesRepository()
    }

    container.register { container -> VerifyCallViewModelType in
        VerifyCallViewModel()
    }

    container.register { container -> SetupCardExplanationViewModelType in
        SetupCardExplanationViewModel()
    }

    container.register { container -> LoginViewModelType in
        LoginViewModel()
    }
}
