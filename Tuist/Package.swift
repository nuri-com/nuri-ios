// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Nuri",
    dependencies: [
        .package(url: "https://github.com/SumSubstance/IdensicMobileSDK-iOS", from: "1.36.0"),
        .package(url: "https://github.com/privy-io/privy-ios", from: "2.0.0"),
    ]
)
