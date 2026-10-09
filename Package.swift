// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "Prelude",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Prelude", targets: ["Prelude"])],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")
    ],
    targets: [
        .target(name: "PreludeCore"),
        .executableTarget(name: "Prelude", dependencies: ["PreludeCore", .product(name: "Sparkle", package: "Sparkle")], resources: [
            .copy("Resources/preluderc"),
            .copy("Resources/PreludeMenuTemplate.png")
        ], linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "PreludeCoreTests", dependencies: ["PreludeCore"])
    ]
)
