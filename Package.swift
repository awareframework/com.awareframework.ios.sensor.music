// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "com.awareframework.ios.sensor.music",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "com.awareframework.ios.sensor.music",
            targets: [
                "com.awareframework.ios.sensor.music"
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/awareframework/com.awareframework.ios.core.git", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "com.awareframework.ios.sensor.music",
            dependencies: [
                .product(name: "com.awareframework.ios.core", package: "com.awareframework.ios.core", condition: .when(platforms: [.iOS]))
            ],
            path: "Sources/com.awareframework.ios.sensor.music"
        ),
        .testTarget(
            name: "com.awareframework.ios.sensor.musicTests",
            dependencies: [
                .target(name: "com.awareframework.ios.sensor.music")
            ],
            path: "Tests/com.awareframework.ios.sensor.musicTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
