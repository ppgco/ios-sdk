// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "PPG_iOS_SDK",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        // Push Notifications SDK
        .library(
            name: "PPG_framework",
            targets: ["PPG_framework"]),
        // In-App Messages SDK
        .library(
            name: "PPG_InAppMessages",
            targets: ["PPG_InAppMessages"]),
    ],
    dependencies: [
        // Add your dependencies here if any
    ],
    targets: [
        // Push Notifications SDK Target
        .target(
            name: "PPG_framework",
            dependencies: [],
            path: "Sources/PPG_framework"),
        .testTarget(
            name: "PPG_frameworkTests",
            dependencies: ["PPG_framework"],
            path: "Tests/PPG_frameworkTests"),
        
        // In-App Messages SDK Target
        .target(
            name: "PPG_InAppMessages",
            dependencies: [],
            path: "Sources/PPG_InAppMessages",
            linkerSettings: [
                .linkedFramework("UIKit", .when(platforms: [.iOS])),
                .linkedFramework("WebKit", .when(platforms: [.iOS])),
                .linkedFramework("Foundation", .when(platforms: [.iOS]))
            ]),
        .testTarget(
            name: "PPG_InAppMessagesTests",
            dependencies: ["PPG_InAppMessages"],
            path: "Tests/PPG_InAppMessagesTests"),
    ]
)
