// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "inject",
    products: [
        .executable(
            name: "inject",
            targets: ["inject"]
        ),
        .library(
            name: "Injection",
            targets: ["injection"]
        )
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "inject",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "injection",
            dependencies: [],
            path: "Injection/Injection"
        ),
        .testTarget(
            name: "injectTests",
            dependencies: ["inject"]
        )
    ]
)
