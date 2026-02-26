// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Dikta",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Dikta", targets: ["Dikta"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit", "0.9.0"..<"0.10.0"),
    ],
    targets: [
        .executableTarget(
            name: "Dikta",
            dependencies: [
                "WhisperKit",
            ],
            path: "Dikta",
            exclude: ["Resources/Info.plist", "Resources/Dikta.entitlements"],
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "DiktaTests",
            dependencies: [],
            path: "DiktaTests"
        )
    ]
)
