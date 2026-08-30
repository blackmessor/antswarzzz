// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Antswarzzz",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.executable(name: "Antswarzzz", targets: ["Antswarzzz"])],
    targets: [.executableTarget(name: "Antswarzzz", path: "Sources/Antswarzzz")]
)
