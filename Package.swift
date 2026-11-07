// swift-tools-version: 6.0
import PackageDescription

// Supplemental host tests for portable business logic. The iOS app uses the native .xcodeproj.
let package = Package(
    name: "CoordinatorNavigationDemoCoreVerification",
    platforms: [.macOS(.v13)],
    products: [],
    targets: [
        .target(name: "CoordinatorNavigationDemo", path: ".",
            exclude: ["App", "Features", "Core/Navigation", "Core/DependencyInjection", "Core/Session", "Core/Alerts/AlertPresentation.swift", "CoordinatorNavigationDemoTests", "CoordinatorNavigationDemoUITests", "CoordinatorNavigationDemo.xcodeproj", "docs", "README.md"],
            sources: ["Domain", "Data", "Core/DeepLinks", "Core/Alerts/AppAlert.swift"]),
        .testTarget(name: "PortableCoreTests", dependencies: ["CoordinatorNavigationDemo"],
            path: "CoordinatorNavigationDemoTests", exclude: ["ArchitectureTests.swift", "RouterLifecycleTests.swift", "NavigationReliabilityTests.swift", "TestSupport"],
            sources: ["DomainTests.swift", "IntentProcessorTests.swift", "AppAlertQueueTests.swift"])
    ],
    swiftLanguageModes: [.v5]
)
