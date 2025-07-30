import ProjectDescription

let project = Project(
    name: "Nuri",
    targets: [
        .target(
            name: "Nuri",
            destinations: .iOS,
            product: .app,
            bundleId: "com.nuri.mobile-ios",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .extendingDefault(with: [
                "UIUserInterfaceStyle": "Light",
                "UIAppFonts": .array([
                    "Inter.ttf",
                    "Inter-Italic.ttf"
                ]),
                "NFCReaderUsageDescription": "Authentication with Passkey",
                "com.apple.developer.nfc.readersession.felica.systemcodes": .array([]),
                "com.apple.developer.nfc.readersession.iso7816.select-identifiers": .array([
                    "A000000151000000",
                    "A000000151041010",
                    "494445585F4C5F0101",
                    "4A4E45545F4C5F020101",
                    "A00000090501000101",
                    "A00000090501000301"
                ]),
                "UILaunchStoryboardName": "LaunchScreen",
                "ITSAppUsesNonExemptEncryption": .boolean(false),
                "NSCameraUsageDescription": "Camera access is needed to scan your documents and QR codes",
                "NSMicrophoneUsageDescription": "Microphone access is needed for video verification",
                "NSPhotoLibraryUsageDescription": "Photo library access is needed if you choose an existing image of your ID",
                "NSLocationWhenInUseUsageDescription": "Location is used to enhance identity verification",
                "NSLocationTemporaryUsageDescriptionDictionary": .dictionary(["DocumentVerification": "Location is required to confirm you are in an allowed country"]),
                "NSFaceIDUsageDescription": "Face ID is used to confirm your identity during liveness verification",
                "CFBundleURLTypes": .array([
                    .dictionary([
                        "CFBundleTypeRole": "Viewer",
                        "CFBundleURLSchemes": .array(["nuriwallet"])
                    ])
                ]),
                "NSAppTransportSecurity": .dictionary([
                    "NSAllowsArbitraryLoads": .boolean(false),
                    "NSAllowsLocalNetworking": .boolean(true),
                    "NSExceptionDomains": .dictionary([
                        "localhost": .dictionary([
                            "NSExceptionAllowsInsecureHTTPLoads": .boolean(true)
                        ])
                    ])
                ])
            ]),
            sources: ["Nuri/Sources/**"],
            resources: ["Nuri/Resources/**"],
            entitlements: .dictionary([
                "com.apple.developer.nfc.readersession.formats": .array([
                    "TAG"
                ]),
                "com.apple.developer.associated-domains": .array([
                    "webcredentials:nuri.com"
                ]),
                "application-identifier": "MH2SRQ3N27.com.nuri.mobile-ios",
                "keychain-access-groups": .array([
                    "$(AppIdentifierPrefix)com.nuri.mobile-ios"
                ]),
                "com.apple.developer.in-app-payments": .array([
                    "merchant.com.nuri.ios"
                ])
            ]),
            dependencies: [
                .project(target: "Authentication", path: "../Authentication"),
                .project(target: "StrigaAPI", path: "../StrigaAPI"),
                .external(name: "IdensicMobileSDK"),
                .external(name: "BitcoinDevKit"),
                .external(name: "KeychainAccess"),
            ],
            settings: .settings(
                base: [
                    "CODE_SIGN_ALLOW_ENTITLEMENTS_MODIFICATION": "YES",
                    "DEVELOPMENT_TEAM": "MH2SRQ3N27",
                    "MARKETING_VERSION": "1.0.0",
                    "CURRENT_PROJECT_VERSION": "1"
                ],
                defaultSettings: .recommended
            )
        )
    ]
)
