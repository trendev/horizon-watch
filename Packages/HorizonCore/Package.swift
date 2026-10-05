// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "HorizonCore",
    platforms: [.watchOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "HorizonCore", targets: ["HorizonCore"])
    ],
    targets: [
        .target(name: "HorizonCore"),
        .testTarget(name: "HorizonCoreTests", dependencies: ["HorizonCore"])
    ]
)
