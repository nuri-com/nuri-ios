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

    container.register { container -> PhoneNumberViewModelType in
        PhoneNumberViewModel(
            dialCodesRepository: container.resolve()
        )
    }

    container.register { container -> DialCodesRepositoryType in
        DialCodesRepository()
    }
}
