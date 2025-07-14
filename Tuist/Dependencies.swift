import ProjectDescription

let dependencies = Dependencies(
    swiftPackageManager: [
        .remote(url: "https://github.com/SumSubstance/IdensicMobileSDK-iOS", requirement: .upToNextMajor(from: "1.36.0")),
        .remote(url: "https://github.com/bitcoindevkit/bdk-swift", requirement: .upToNextMajor(from: "1.2.0")),
        .remote(url: "https://github.com/kishikawakatsumi/KeychainAccess", requirement: .upToNextMajor(from: "4.2.2")),
        .remote(url: "https://github.com/Swinject/Swinject", requirement: .upToNextMajor(from: "2.8.4")),
    ],
    platforms: [.iOS]
)
