// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StayDuo",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "StayDuo",
            path: "Sources/StayDuo",
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        ),
        .testTarget(
            name: "StayDuoTests",
            dependencies: ["StayDuo"],
            path: "Tests/StayDuoTests"
        )
    ]
)
