// swift-tools-version: 6.4
import PackageDescription

let strictSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .treatAllWarnings(as: .error),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility")
]

let kernelSettings: [SwiftSetting] = strictSettings + [.strictMemorySafety()]

let packageDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/Aemi-Studio/aemi.git", revision: "bd5e4cf4441ca3ed1b424935142586ccaac0f835")
]

let package = Package(
    name: "AemiSearch",
    platforms: [.macOS(.v15), .iOS(.v18), .tvOS(.v18), .watchOS(.v11), .visionOS(.v2)],
    products: [
        .library(name: "AemiSearch", targets: ["AemiSearch"])
    ],
    dependencies: packageDependencies,
    targets: [
        .target(
            name: "AemiSearch",
            dependencies: [
                .product(name: "AemiInterner", package: "aemi"), .product(name: "AemiKernel", package: "aemi"),
                .product(name: "AemiText", package: "aemi")
            ],
            swiftSettings: kernelSettings
        ),
        .testTarget(name: "AemiSearchTests", dependencies: ["AemiSearch"], swiftSettings: strictSettings)
    ]
)

if Context.environment["AEMISEARCH_DEV"] != nil {
    package.targets.append(
        .executableTarget(name: "AemiSearchBench", dependencies: ["AemiSearch"], path: "Benchmarks/AemiSearchBench")
    )
}
