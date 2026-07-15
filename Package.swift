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
        .library(name: "WhisperFeatures", targets: ["WhisperFeatures"])
    ],
    targets: [
        .target(name: "WhisperDomain"),
        .target(name: "WhisperClients", dependencies: ["WhisperDomain"]),
        .target(name: "WhisperFeatures", dependencies: ["WhisperDomain", "WhisperClients"]),
        .testTarget(name: "WhisperContractTests", dependencies: ["WhisperDomain", "WhisperClients"]),
        .testTarget(name: "WhisperFeatureTests", dependencies: ["WhisperDomain", "WhisperClients", "WhisperFeatures"])
    ]
)
