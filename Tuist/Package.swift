// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Nuri",
    dependencies: [
        .package(url: "https://github.com/twostraws/CodeScanner", from: "2.5.2"),
        .package(path: "../context-llm/IdensicMobileSDK-iOS"),
    ]
)
