// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WebcamSettings",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "WebcamSettings", targets: ["WebcamSettings"])
    ],
    targets: [
        .executableTarget(
            name: "WebcamSettings",
            path: "Sources/WebcamSettings"
        ),
        .testTarget(
            name: "WebcamSettingsTests",
            dependencies: ["WebcamSettings"],
            path: "Tests/WebcamSettingsTests"
        )
    ]
)
