// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WebcamSettings",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "WebcamSettings", targets: ["WebcamSettings"]),
        .executable(name: "WebcamSettingsRawProbe", targets: ["WebcamSettingsRawProbe"])
    ],
    targets: [
        .executableTarget(
            name: "WebcamSettings",
            dependencies: ["USBHostShim"],
            path: "Sources/WebcamSettings"
        ),
        .executableTarget(
            name: "WebcamSettingsRawProbe",
            path: "Sources/WebcamSettingsRawProbe"
        ),
        .target(
            name: "USBHostShim",
            path: "Sources/USBHostShim",
            publicHeadersPath: "include"
        ),
        .testTarget(
            name: "WebcamSettingsTests",
            dependencies: ["WebcamSettings"],
            path: "Tests/WebcamSettingsTests"
        )
    ]
)
