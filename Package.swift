// swift-tools-version:5.9
import PackageDescription

// Deliberately no XCTest: Apple's Command Line Tools ship without it, and this
// project must build and test on a Mac that has never seen Xcode.app.
let package = Package(
    name: "MultiClock",
    platforms: [.macOS(.v10_15)],
    targets: [
        .target(name: "MultiClockCore", path: "Sources/MultiClockCore"),
        .executableTarget(name: "MultiClock", dependencies: ["MultiClockCore"], path: "Sources/MultiClock"),
        .executableTarget(name: "multiclock-check", dependencies: ["MultiClockCore"], path: "Sources/multiclock-check"),
    ]
)
