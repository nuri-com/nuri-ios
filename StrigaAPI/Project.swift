import ProjectDescription

let project = Project(
    name: "StrigaAPI",
    targets: [
        .target(
            name: "StrigaAPI",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.nuri.striga",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .default,
            sources: ["StrigaAPI/Sources/**"]
        )
    ]
)
