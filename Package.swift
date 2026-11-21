// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DivineIntervention",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DivineIntervention",
            path: "Sources/DivineIntervention"
        )
    ]
)
