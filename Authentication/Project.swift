import ProjectDescription

let project = Project(
    name: "Authentication",
    targets: [
        .target(
            name: "Authentication",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.nuri.authentication",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .default,
            sources: ["Authentication/Sources/**"]
        )
    ]
)
