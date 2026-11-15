// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "InvoiceCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "InvoiceCore", targets: ["InvoiceCore"])],
    targets: [
        .target(name: "InvoiceCore"),
        .executableTarget(name: "invoice-samples", dependencies: ["InvoiceCore"]),
        .testTarget(name: "InvoiceCoreTests", dependencies: ["InvoiceCore"]),
    ]
)
