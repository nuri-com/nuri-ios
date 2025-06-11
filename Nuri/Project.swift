import ProjectDescription

let project = Project(
    name: "Nuri",
    targets: [
        .target(
            name: "Nuri",
            destinations: .iOS,
            product: .app,
            bundleId: "com.nuri.nuri-ios",
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
                "UILaunchScreen": .dictionary([
                    "UIImageName": ""
                ])
            ]),
            sources: ["Nuri/Sources/**"],
            resources: ["Nuri/Resources/**"],
            entitlements: .dictionary([
                "com.apple.developer.nfc.readersession.formats": .array([
                    "NDEF",
                    "TAG"
                ]),
                "com.apple.developer.associated-domains": .array([
                    "webcredentials:nuri.com"
                ])
            ]),
            dependencies: [
                .project(target: "Authentication", path: "../Authentication"),
            ],
            settings: .settings(
                base: .init()
                    .automaticCodeSigning(devTeam: "7NF2K7X2U6")
            )
        )
    ]
)
