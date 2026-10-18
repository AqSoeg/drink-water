// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DrinkWater",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "HydrationCore", targets: ["HydrationCore"])],
    targets: [
        .target(name: "HydrationCore"),
        .testTarget(name: "HydrationCoreTests", dependencies: ["HydrationCore"])
    ]
)
