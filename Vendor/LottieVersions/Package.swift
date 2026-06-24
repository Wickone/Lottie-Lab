// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LottieVersions",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "Lottie300", targets: ["Lottie300"]),
        .library(name: "Lottie350", targets: ["Lottie350"]),
        .library(name: "Lottie400", targets: ["Lottie400"]),
        .library(name: "Lottie461", targets: ["Lottie461"]),
    ],
    targets: [
        .target(
            name: "Lottie300",
            exclude: ["Public/MacOS"]
        ),
        .target(name: "Lottie350"),
        .target(name: "Lottie400"),
        .target(
            name: "Lottie461",
            exclude: [
                "Private/EmbeddedLibraries/README.md",
                "Private/EmbeddedLibraries/ZipFoundation/README.md",
                "Private/EmbeddedLibraries/EpoxyCore/README.md",
                "Private/EmbeddedLibraries/LRUCache/README.md",
            ],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
