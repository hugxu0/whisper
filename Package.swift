// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Whisper",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "WhisperDomain", targets: ["WhisperDomain"]),
        .library(name: "WhisperClients", targets: ["WhisperClients"]),
        .library(name: "WhisperFeatures", targets: ["WhisperFeatures"]),
        .library(name: "WhisperSocketIO", targets: ["WhisperSocketIO"]),
        .library(name: "WhisperApp", targets: ["WhisperApp"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/socketio/socket.io-client-swift.git",
            exact: "16.1.1"
        )
    ],
    targets: [
        .target(name: "WhisperDomain"),
        .target(name: "WhisperClients", dependencies: ["WhisperDomain"]),
        .target(name: "WhisperFeatures", dependencies: ["WhisperDomain", "WhisperClients"]),
        .target(
            name: "WhisperSocketIO",
            dependencies: [
                "WhisperClients",
                .product(name: "SocketIO", package: "socket.io-client-swift")
            ]
        ),
        .target(
            name: "WhisperApp",
            dependencies: [
                "WhisperDomain",
                "WhisperClients",
                "WhisperFeatures",
                "WhisperSocketIO"
            ],
            exclude: ["README.md"]
        ),
        .testTarget(name: "WhisperContractTests", dependencies: ["WhisperDomain", "WhisperClients"]),
        .testTarget(
            name: "WhisperFeatureTests",
            dependencies: ["WhisperDomain", "WhisperClients", "WhisperFeatures"],
            exclude: ["README.md"]
        )
    ]
)
