// swift-tools-version: 6.4
import PackageDescription

// Same strictness as the Aemi family: Swift 6 mode, warnings as errors, the upcoming features that tighten existentials and imports.
let strictSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .treatAllWarnings(as: .error),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility")
]

// The index reads text from anywhere (tool output, web pages), so every unsafe construct in it must be marked `unsafe`.
let kernelSettings: [SwiftSetting] = strictSettings + [.strictMemorySafety()]

// Aemi supplies the term dictionary (AemiInterner), the SIMD substring search (AemiKernel) and the bounded edit distance (AemiText).
// Pinned to the revision the rest of the family pins, since SwiftPM resolves one revision per package in a graph.
let packageDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/Aemi-Studio/aemi.git", revision: "0bae2edb1a89bd3d931fb3122c2184cc5c368834")
]

let package = Package(
    name: "AemiSearch",
    platforms: [.macOS(.v15), .iOS(.v18), .tvOS(.v18), .watchOS(.v11), .visionOS(.v2)],
    products: [
        .library(name: "AemiSearch", targets: ["AemiSearch"])
    ],
    dependencies: packageDependencies,
    targets: [
        // No Foundation: documents are UTF-8 bytes, terms are interned, scores are BM25 (roadmap of ask, t209).
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

// The benchmark over a corpus of documents (one per line of a file), dev-only:
//   AEMISEARCH_DEV=1 swift run -c release AemiSearchBench CORPUS [QUERY...]
if Context.environment["AEMISEARCH_DEV"] != nil {
    package.targets.append(
        .executableTarget(name: "AemiSearchBench", dependencies: ["AemiSearch"], path: "Benchmarks/AemiSearchBench")
    )
}
