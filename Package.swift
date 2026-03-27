// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "agent-bar",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "agent-bar", targets: ["agent_bar"]),
    ],
    targets: [
        .executableTarget(
            name: "agent_bar",
            path: "Sources/agent-bar",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
    ]
)
