// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KeyOpen",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "KeyOpenCore"),
        .testTarget(name: "KeyOpenCoreTests", dependencies: ["KeyOpenCore"]),
        .executableTarget(name: "KeyOpen", dependencies: ["KeyOpenCore"]),
    ]
)
