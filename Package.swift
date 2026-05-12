// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NoukaiSDK",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "NoukaiSDK", targets: ["NoukaiSDK"]),
    ],
    targets: [
        .target(name: "NoukaiSDK"),
        .testTarget(
            name: "NoukaiSDKTests",
            dependencies: ["NoukaiSDK"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
