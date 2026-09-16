// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SarvamPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SarvamPlugin", type: .dynamic, targets: ["SarvamPlugin"])
    ],
    dependencies: [
        .package(path: "/Users/rishiraj/Downloads/typewhisper-mac/TypeWhisperPluginSDK")
    ],
    targets: [
        .target(
            name: "SarvamPlugin",
            dependencies: [
                .product(name: "TypeWhisperPluginSDK", package: "TypeWhisperPluginSDK"),
            ],
            path: "Sources/SarvamPlugin"
        )
    ]
)
