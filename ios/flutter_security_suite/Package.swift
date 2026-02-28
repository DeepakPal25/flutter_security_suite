// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "flutter_security_suite",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(name: "flutter_security_suite", targets: ["flutter_security_suite"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "flutter_security_suite",
            dependencies: [],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
