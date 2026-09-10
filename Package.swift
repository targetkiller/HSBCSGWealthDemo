// swift-tools-version: 5.9
import PackageDescription

// Allows domain tests to run without an iOS simulator or code signing.
let package = Package(
    name: "WealthHubCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "WealthHubCore", targets: ["WealthHub"])],
    targets: [
        .target(
            name: "WealthHub",
            path: ".",
            exclude: [
                "README.md", "README.zh-CN.md", "Samples", "Screenshots", "WealthHub.xcodeproj",
                "WealthHubTests", "WealthHubUITests", "build", "docs", "project.yml", "scripts",
                "WealthHub/Assets.xcassets", "WealthHub/PrivacyInfo.xcprivacy",
                "WealthHub/AccountsView.swift", "WealthHub/AddAccountFlow.swift",
                "WealthHub/AddPortfolioSheet.swift", "WealthHub/BankingNavigation.swift",
                "WealthHub/CompareView.swift", "WealthHub/InvestmentViews.swift",
                "WealthHub/GIVPerformanceView.swift", "WealthHub/GIVAnalysisView.swift",
                "WealthHub/StatementExtractionService.swift", "WealthHub/WealthHubApp.swift",
                "WealthHub/WealthView.swift", "WealthHub/WealthSupportingViews.swift"
            ],
            sources: [
                "WealthHub/Models.swift", "WealthHub/PortfolioStore.swift", "WealthHub/StatementParser.swift",
                "WealthHub/SampleData.swift", "WealthHub/GIVPortfolioData.swift", "WealthHub/Theme.swift"
            ],
            resources: [.copy("Sample")]
        ),
        .testTarget(name: "WealthHubTests", dependencies: ["WealthHub"], path: "WealthHubTests")
    ]
)
