import ProjectDescription

let dependencies = Dependencies(
    swiftPackageManager: SwiftPackageManagerDependencies(
        [
            .remote(url: "https://github.com/SumSubstance/IdensicMobileSDK-iOS", requirement: .upToNextMajor(from: "1.36.0")),
            .remote(url: "https://github.com/bitcoindevkit/bdk-swift", requirement: .upToNextMajor(from: "1.2.0")),
            .remote(url: "https://github.com/kishikawakatsumi/KeychainAccess", requirement: .upToNextMajor(from: "4.2.2")),
        ]
    ),
    platforms: [.iOS]
)