// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Bridge",
    platforms: [
       .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Bridge",
            targets: ["Bridge"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Bridge",
            dependencies: [],
	          path: "Sources"),
        .testTarget(
            name: "BridgeTests",
            dependencies: ["Bridge"],
	          path: "Tests")
    ],
    swiftLanguageVersions: [.v5]
)
