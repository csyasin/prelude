// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "Prelude",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Prelude", targets: ["Prelude"])],
    targets: [
        .target(name: "PreludeCore"),
        .executableTarget(name: "Prelude", dependencies: ["PreludeCore"], resources: [
            .copy("Resources/preluderc"),
            .copy("Resources/PreludeMenuTemplate.png"),
            .copy("Resources/PreludeMenuOrbit.png"),
            .copy("Resources/PreludeMenuPanels.png")
        ]),
        .testTarget(name: "PreludeCoreTests", dependencies: ["PreludeCore"])
    ]
)
