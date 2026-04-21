// swift-tools-version: 6.1

import PackageDescription

var package = Package(
    name: "NimbusMolocoKit",
    platforms: [.iOS(.v13)],
    products: [
        .library(
           name: "NimbusMolocoKit",
           targets: ["NimbusMolocoKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/moloco/moloco-sdk-ios-spm", from: "4.4.1")
    ],
    targets: [
        .target(
            name: "NimbusMolocoKit",
            dependencies: [
                .product(name: "NimbusKit", package: "nimbus-ios-sdk"),
                .product(name: "MolocoSDK", package: "moloco-sdk-ios-spm"),
            ]
        ),
        .testTarget(
            name: "NimbusMolocoKitTests",
            dependencies: ["NimbusMolocoKit"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
    ]
)

package.dependencies.append(.package(url: "https://github.com/adsbynimbus/nimbus-ios-sdk", from: "3.0.0-rc.1"))
