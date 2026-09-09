// swift-tools-version: 5.9
import PackageDescription

// Allows domain tests to run without an iOS simulator or code signing.
let package = Package(
    name: "WealthHubCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "WealthHubCore", targets: ["WealthHub"])],
    targets: [
        .target(name: "WealthHub", path: "WealthHub", exclude: ["Assets.xcassets", "AccountsView.swift", "AddAccountFlow.swift", "AddPortfolioSheet.swift", "BankingNavigation.swift", "CompareView.swift", "InvestmentViews.swift", "GIVPortfolioData.swift", "GIVPerformanceView.swift", "GIVAnalysisView.swift", "StatementExtractionService.swift", "Theme.swift", "WealthHubApp.swift", "WealthView.swift", "WealthSupportingViews.swift"], sources: ["Models.swift", "PortfolioStore.swift", "StatementParser.swift"]),
        .testTarget(name: "WealthHubTests", dependencies: ["WealthHub"], path: "WealthHubTests")
    ]
)
