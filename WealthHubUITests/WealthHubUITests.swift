import XCTest
import UIKit

final class WealthHubUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.buttons["banking.tab.wealth"].waitForExistence(timeout: 10))
        return app
    }

    func testBankingNavigationStartsOnWealthWithoutBottomTabs() throws {
        let app = launch()
        XCTAssertEqual(app.tabBars.count, 0)
        XCTAssertTrue(app.buttons["accountSelector"].exists)
        for name in ["home", "pay", "cards", "wealth"] {
            XCTAssertTrue(app.buttons["banking.tab.\(name)"].isHittable)
        }
        attachScreenshot(app, name: "Wealth overview")

        app.buttons["banking.tab.pay"].tap()
        let exploreWealth = app.buttons["banking.preview.openWealth"]
        XCTAssertTrue(exploreWealth.waitForExistence(timeout: 3))
        exploreWealth.tap()
        XCTAssertTrue(app.buttons["accountSelector"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.tabBars.count, 0)
    }

    func testConfirmRespondsAtEdgesAndRespectsDisabledState() throws {
        let app = launch()
        let title = app.staticTexts["accountSelector.title"]

        // Tap empty background near opposite corners, away from the centered title.
        for offset in [CGVector(dx: 0.04, dy: 0.18), CGVector(dx: 0.96, dy: 0.82)] {
            app.buttons["accountSelector"].tap()
            XCTAssertTrue(title.waitForExistence(timeout: 3))
            let confirm = app.buttons["Confirm"]
            XCTAssertTrue(confirm.isEnabled)
            confirm.coordinate(withNormalizedOffset: offset).tap()
            let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: title)
            XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 3), .completed)
        }

        app.buttons["accountSelector"].tap()
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        let global = app.buttons["accountSelector.global"]
        if global.value as? String != "Selected" { global.tap() }
        global.tap()
        let confirm = app.buttons["Confirm"]
        XCTAssertFalse(confirm.isEnabled)
        confirm.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.5)).tap()
        XCTAssertTrue(title.exists, "An empty selection must keep Confirm disabled across its full width.")

        global.tap()
        XCTAssertTrue(confirm.isEnabled)
        confirm.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.5)).tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: title)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 3), .completed)
    }

    func testOutlinedCancelRespondsOutsideItsTitle() throws {
        let app = launch()
        openAddPortfolio(in: app)
        app.buttons["portfolio.add.statement"].tap()
        let upload = app.navigationBars["Upload or scan a statement"]
        XCTAssertTrue(upload.waitForExistence(timeout: 3))
        let cancel = app.buttons["portfolio.statement.cancel"]
        scrollUntilHittable(cancel, in: app)
        cancel.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.2)).tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: upload)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 3), .completed)
        XCTAssertTrue(app.buttons["banking.tab.wealth"].isHittable)
    }

    func testSettingsShowsPrivacyPolicy() throws {
        let app = launch()
        defer { XCUIDevice.shared.orientation = .portrait }
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft
        }
        app.buttons["banking.menu.button"].tap()
        app.buttons["banking.menu.settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        let privacy = app.buttons["settings.privacy"]
        scrollUntilHittable(privacy, in: app)
        privacy.tap()
        XCTAssertTrue(app.navigationBars["Privacy policy"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["This prototype uses local demo data and does not connect to a bank or provide banking services."].exists)
        attachScreenshot(app, name: "Privacy policy")
    }

    func testAccountSelectionAndComparison() throws {
        let app = launch()
        app.buttons["accountSelector"].tap()
        XCTAssertTrue(app.staticTexts["accountSelector.title"].waitForExistence(timeout: 3))
        app.buttons["Hong Kong"].tap()
        let hongKongAccount = app.buttons.containing(.staticText, identifier: "HSBC One Investment Services").firstMatch
        scrollUntilHittable(hongKongAccount, in: app)
        hongKongAccount.tap()
        app.buttons["Confirm"].tap()
        XCTAssertTrue(app.staticTexts["2 accounts selected"].waitForExistence(timeout: 3))

        app.buttons["banking.menu.button"].tap()
        XCTAssertTrue(app.buttons["banking.menu.compare"].waitForExistence(timeout: 3))
        app.buttons["banking.menu.compare"].tap()
        XCTAssertTrue(app.staticTexts["Portfolio comparison"].waitForExistence(timeout: 3))
        let returns = app.segmentedControls.buttons["Return %"]
        scrollUntilHittable(returns, in: app)
        returns.tap()
        XCTAssertTrue(returns.isSelected)
        attachScreenshot(app, name: "Account comparison from banking menu")
    }

    func testAddStatementReviewCancelEditAndAnalyse() throws {
        let app = launch()
        openAddPortfolio(in: app)
        attachScreenshot(app, name: "Add a portfolio")
        app.buttons["portfolio.add.statement"].tap()
        XCTAssertTrue(app.navigationBars["Upload or scan a statement"].waitForExistence(timeout: 3))
        attachScreenshot(app, name: "Upload or scan a statement")
        let sample = app.buttons["portfolio.statement.sample"]
        scrollUntilHittable(sample, in: app)
        sample.tap()
        XCTAssertTrue(app.navigationBars["Extracted outcome"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["I’ve found 8 holdings in this statement:"].exists)
        attachScreenshot(app, name: "Extracted outcome")

        let firstHolding = app.buttons["portfolio.extracted.holding.00100"]
        scrollUntilHittable(firstHolding, in: app)
        firstHolding.tap()
        XCTAssertTrue(app.navigationBars["Edit holding"].waitForExistence(timeout: 3))
        let quantity = app.textFields["portfolio.holding.quantity"]
        XCTAssertEqual(quantity.value as? String, "300.0")
        replaceText(in: quantity, with: "900")
        XCTAssertEqual(quantity.value as? String, "900")
        XCTAssertTrue(app.buttons["portfolio.holding.save"].isEnabled)
        let averageCost = app.textFields["portfolio.holding.cost"]
        scrollUntilHittable(averageCost, in: app)
        replaceText(in: averageCost, with: "0")
        XCTAssertFalse(app.buttons["portfolio.holding.save"].isEnabled, "A missing average cost must not be accepted as a zero cost basis.")
        app.navigationBars["Edit holding"].buttons["Cancel"].tap()

        XCTAssertTrue(firstHolding.waitForExistence(timeout: 3))
        firstHolding.tap()
        XCTAssertTrue(app.navigationBars["Edit holding"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.textFields["portfolio.holding.quantity"].value as? String, "300.0", "Cancelling an edit must preserve the extracted draft.")
        app.navigationBars["Edit holding"].buttons["Cancel"].tap()

        let proceed = app.buttons["portfolio.extracted.proceed"]
        scrollUntilHittable(proceed, in: app)
        XCTAssertTrue(proceed.isEnabled)
        proceed.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.5)).tap()

        XCTAssertTrue(app.buttons["banking.tab.wealth"].waitForExistence(timeout: 5))
        let updated = app.descendants(matching: .any)["portfolio.analysis.updated"].firstMatch
        XCTAssertTrue(updated.waitForExistence(timeout: 8))
        let globalHoldings = app.buttons["portfolio.globalHoldings"]
        scrollUntilHittable(globalHoldings, in: app)
        XCTAssertTrue(globalHoldings.isHittable)
        attachScreenshot(app, name: "Statement included in Wealth analysis")

        scrollUntilHittable(app.buttons["accountSelector"], in: app, upwards: false)
        XCTAssertTrue(app.staticTexts["2 accounts selected"].exists)
        app.buttons["accountSelector"].tap()
        XCTAssertTrue(app.staticTexts["accountSelector.title"].waitForExistence(timeout: 3))
        app.buttons["Hong Kong"].tap()
        let importedAccount = app.buttons.containing(.staticText, identifier: "Statement portfolio")
        XCTAssertTrue(importedAccount.firstMatch.waitForExistence(timeout: 3))
        XCTAssertEqual(importedAccount.count, 1, "Proceed must create exactly one statement portfolio.")
    }

    func testAddingExistingGlobalHSBCAccountsDoesNotDuplicateThem() throws {
        let app = launch()
        openAddPortfolio(in: app)
        includeGlobalHSBCAccounts(in: app)

        // Add the same existing accounts again; the portfolio should still contain two HSBC accounts.
        let addHoldings = app.buttons["portfolio.addHoldings"]
        scrollUntilHittable(addHoldings, in: app)
        if addHoldings.frame.maxY > app.frame.height * 0.75 { app.swipeUp() }
        addHoldings.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        includeGlobalHSBCAccounts(in: app)
        scrollUntilHittable(app.buttons["accountSelector"], in: app, upwards: false)
        XCTAssertTrue(app.staticTexts["6 accounts selected"].exists)
        app.buttons["accountSelector"].tap()
        XCTAssertTrue(app.staticTexts["accountSelector.title"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons.containing(.staticText, identifier: "(068) Equity Investment Account").count, 1)
        app.buttons["Hong Kong"].tap()
        XCTAssertEqual(app.buttons.containing(.staticText, identifier: "HSBC One Investment Services").count, 1)
    }

    func testLinkedAccountsAndGlobalInvestmentViews() throws {
        let app = launch()
        app.buttons["wealth.viewDetails"].tap()
        XCTAssertTrue(app.buttons["giv.accounts"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["giv.totalValue"].label.contains("$"))
        XCTAssertTrue(app.buttons["giv.totalValue"].label.contains("SGD"))

        app.buttons["giv.accounts"].tap()
        XCTAssertTrue(app.staticTexts["accountSelector.title"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["DBS Account"].exists)
        attachScreenshot(app, name: "Linked Singapore accounts")
        app.buttons["accountSelector.market.hk"].tap()
        XCTAssertTrue(app.staticTexts["Standard Chartered Account"].exists)
        attachScreenshot(app, name: "Linked Hong Kong accounts")
        app.buttons["accountSelector.global"].tap()
        app.buttons["Confirm"].tap()
        XCTAssertTrue(app.buttons["giv.accounts"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["giv.accounts"].label.contains("All global accounts selected"))
        attachScreenshot(app, name: "GIV Markets by asset class")

        let regions = app.buttons["giv.markets.region"]
        scrollUntilHittable(regions, in: app)
        regions.tap()
        XCTAssertTrue(regions.isSelected)
        attachScreenshot(app, name: "GIV Markets by region")

        let performance = app.buttons["giv.tab.Performance"]
        scrollUntilHittable(performance, in: app, upwards: false)
        performance.tap()
        XCTAssertTrue(app.buttons["giv.performance.period.month"].waitForExistence(timeout: 3))
        let monthReturn = app.descendants(matching: .any)["giv.performance.return"].firstMatch.label
        app.buttons["giv.performance.period.year"].tap()
        XCTAssertTrue(app.buttons["giv.performance.period.year"].isSelected)
        XCTAssertNotEqual(monthReturn, app.descendants(matching: .any)["giv.performance.return"].firstMatch.label)
        let chart = app.descendants(matching: .any)["giv.performance.chart"].firstMatch
        scrollUntilHittable(chart, in: app)
        if chart.frame.maxY > app.frame.maxY - 60 { app.swipeUp() }
        attachScreenshot(app, name: "GIV Performance chart")
        let hsi = app.buttons["giv.performance.benchmark.HSI"]
        scrollUntilHittable(hsi, in: app)
        hsi.tap()
        XCTAssertTrue(hsi.isSelected)

        let analysis = app.buttons["giv.tab.Analysis"]
        scrollUntilHittable(analysis, in: app, upwards: false)
        analysis.tap()
        XCTAssertTrue(app.buttons["giv.analysis.Currency"].waitForExistence(timeout: 3))
        attachScreenshot(app, name: "GIV Currency exposure")
        app.buttons["giv.analysis.Region"].tap()
        XCTAssertTrue(app.buttons["giv.analysis.Region"].isSelected)
        attachScreenshot(app, name: "GIV Region exposure")
        app.buttons["giv.analysis.Sectors"].tap()
        XCTAssertTrue(app.buttons["giv.analysis.Sectors"].isSelected)
        attachScreenshot(app, name: "GIV Sector exposure")
        let scenario = app.buttons["giv.scenario"]
        scrollUntilHittable(scenario, in: app)
        scenario.tap()
        let equityShock = app.buttons["If equity markets drop by 15%"]
        XCTAssertTrue(equityShock.waitForExistence(timeout: 3))
        equityShock.tap()
        XCTAssertTrue(app.descendants(matching: .any)["giv.scenario.impact"].firstMatch.exists)
    }

    private func openAddPortfolio(in app: XCUIApplication) {
        let generate = app.buttons["portfolio.analysis.generate"]
        scrollUntilHittable(generate, in: app)
        generate.tap()
        let addHoldings = app.buttons["portfolio.addHoldings"]
        XCTAssertTrue(addHoldings.waitForExistence(timeout: 8))
        scrollUntilHittable(addHoldings, in: app)
        addHoldings.tap()
        XCTAssertTrue(app.buttons["portfolio.add.statement"].waitForExistence(timeout: 3))
    }

    private func includeGlobalHSBCAccounts(in app: XCUIApplication) {
        let hsbc = app.buttons["portfolio.add.hsbc"]
        XCTAssertTrue(hsbc.waitForExistence(timeout: 3))
        hsbc.tap()
        let confirm = app.buttons["portfolio.hsbc.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        XCTAssertTrue(confirm.isEnabled)
        confirm.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["banking.tab.wealth"].waitForExistence(timeout: 5))
        let updated = app.descendants(matching: .any)["portfolio.analysis.updated"].firstMatch
        XCTAssertTrue(updated.waitForExistence(timeout: 8))
    }

    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication, upwards: Bool = true, maximumSwipes: Int = 7, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<maximumSwipes {
            if element.exists && element.isHittable { return }
            if upwards { app.swipeUp() } else { app.swipeDown() }
        }
        XCTAssertTrue(element.exists && element.isHittable, "Expected element to become visible: \(element.identifier)", file: file, line: line)
    }

    private func replaceText(in field: XCUIElement, with text: String) {
        // Numeric values are right aligned; tap their trailing edge to place the caret after the value.
        field.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: -2, dy: 0)).tap()
        let current = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + text)
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        // Let short SwiftUI transitions settle before recording a visual reference.
        Thread.sleep(forTimeInterval: 0.4)
        // Full-screen capture avoids application-frame cropping after iPad rotation.
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
