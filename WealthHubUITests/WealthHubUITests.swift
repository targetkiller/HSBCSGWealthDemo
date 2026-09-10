import XCTest
import UIKit

final class WealthHubUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testCaptureAppStoreScreenshots() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["APP_STORE_SCREENSHOTS"] == "1",
                          "Run scripts/capture-app-store-screenshots.sh for the dedicated screenshot flow.")
        XCUIDevice.shared.orientation = .portrait
        var app = launch()
        if ProcessInfo.processInfo.environment["APP_STORE_SCREENSHOT_PAGE"] == "compare" {
            linkAllAvailableDemoAccounts(in: app)
            captureAppStoreComparison(in: app)
            return
        }
        attachAppStoreScreenshot(name: "01-Wealth")

        app.buttons["accountSelector"].tap()
        XCTAssertTrue(app.staticTexts["accountSelector.title"].waitForExistence(timeout: 3))
        app.buttons["accountSelector.global"].tap()
        attachAppStoreScreenshot(name: "02-Select-accounts")
        app.buttons["accountSelector.close"].tap()

        openAddPortfolio(in: app)
        attachAppStoreScreenshot(name: "03-Add-a-portfolio")
        app.buttons["portfolio.add.statement"].tap()
        let sample = app.buttons["portfolio.statement.sample"]
        scrollUntilHittable(sample, in: app)
        sample.tap()
        XCTAssertTrue(app.navigationBars["Extracted outcome"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["I’ve found 8 holdings in this statement:"].exists)
        attachAppStoreScreenshot(name: "04-Review-holdings")

        app.terminate()
        app = launch()
        linkAllAvailableDemoAccounts(in: app)
        app.buttons["wealth.viewDetails"].tap()
        XCTAssertTrue(app.buttons["giv.accounts"].waitForExistence(timeout: 5))
        app.buttons["giv.accounts"].tap()
        XCTAssertTrue(app.buttons["accountSelector.global"].waitForExistence(timeout: 3))
        app.buttons["accountSelector.global"].tap()
        app.buttons["Confirm"].tap()
        XCTAssertTrue(app.buttons["giv.accounts"].waitForExistence(timeout: 3))
        attachAppStoreScreenshot(name: "05-GIV-Markets")

        app.buttons["giv.tab.Performance"].tap()
        let ytd = app.buttons["giv.performance.period.ytd"]
        XCTAssertTrue(ytd.waitForExistence(timeout: 3))
        XCTAssertTrue(ytd.isSelected)
        let chart = app.descendants(matching: .any)["giv.performance.chart"].firstMatch
        scrollUntilHittable(chart, in: app)
        if chart.frame.maxY > app.frame.maxY - 40 { app.swipeUp() }
        attachAppStoreScreenshot(name: "06-GIV-Performance")

        // After scrolling the chart, XCTest can report a tab as hittable
        // while it is under the navigation bar. Reopen at the top instead.
        app.terminate()
        app = launch()
        linkAllAvailableDemoAccounts(in: app)
        app.buttons["wealth.viewDetails"].tap()
        XCTAssertTrue(app.buttons["giv.accounts"].waitForExistence(timeout: 5))
        app.buttons["giv.accounts"].tap()
        XCTAssertTrue(app.buttons["accountSelector.global"].waitForExistence(timeout: 3))
        app.buttons["accountSelector.global"].tap()
        app.buttons["Confirm"].tap()
        app.buttons["giv.tab.Analysis"].tap()
        XCTAssertTrue(app.buttons["giv.analysis.Currency"].waitForExistence(timeout: 3))
        attachAppStoreScreenshot(name: "07-GIV-Analysis")

        app.terminate()
        app = launch()
        linkAllAvailableDemoAccounts(in: app)
        captureAppStoreComparison(in: app)
    }

    private func captureAppStoreComparison(in app: XCUIApplication) {
        app.buttons["banking.menu.button"].tap()
        XCTAssertTrue(app.buttons["banking.menu.compare"].waitForExistence(timeout: 3))
        app.buttons["banking.menu.compare"].tap()
        let comparison = app.staticTexts["Portfolio comparison"]
        scrollUntilHittable(comparison, in: app)
        // Keep the chart heading below the sheet's navigation bar. A full-app
        // swipe is too long for the centered iPad sheet and skips the chart.
        let navigation = app.navigationBars["Compare accounts"]
        XCTAssertTrue(navigation.exists)
        let desiredTop = navigation.frame.maxY + 16
        for _ in 0..<4 {
            let distance = comparison.frame.minY - desiredTop
            if abs(distance) < 20 { break }
            let start = app.coordinate(withNormalizedOffset: .zero).withOffset(
                CGVector(dx: navigation.frame.midX, dy: navigation.frame.maxY + 280))
            let end = start.withOffset(CGVector(dx: 0, dy: -min(max(distance, -200), 200)))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertGreaterThan(comparison.frame.minY, navigation.frame.maxY - 10)
        attachAppStoreScreenshot(name: "08-Compare-accounts")
    }

    private func attachAppStoreScreenshot(name: String) {
        Thread.sleep(forTimeInterval: 0.8)
        let screen = XCUIScreen.main.screenshot()
        XCTAssertLessThan(screen.image.size.width, screen.image.size.height,
                          "App Store screenshots must stay in portrait orientation.")
        let attachment = XCTAttachment(screenshot: screen)
        attachment.name = "APPSTORE-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

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

    func testPortfolioEntryPagesReturnToCompactChooser() throws {
        let app = launch()
        openAddPortfolio(in: app)
        let chooserTitle = app.staticTexts["Add a portfolio"]
        let chooserTop = chooserTitle.frame.minY

        app.buttons["portfolio.add.statement"].tap()
        let introduction = app.staticTexts["How to provide your portfolio?"]
        XCTAssertTrue(introduction.waitForExistence(timeout: 3))
        XCTAssertTrue(introduction.isHittable)
        XCTAssertTrue(app.buttons["portfolio.statement.upload"].isHittable)
        attachScreenshot(app, name: "Statement introduction visible")

        app.buttons["portfolio.flow.back"].tap()
        XCTAssertTrue(app.buttons["portfolio.add.bank"].waitForExistence(timeout: 3))
        XCTAssertTrue(chooserTitle.isHittable)
        XCTAssertEqual(chooserTitle.frame.minY, chooserTop, accuracy: 3)

        app.buttons["portfolio.add.bank"].tap()
        let chooseBank = app.staticTexts["Choose a bank"]
        XCTAssertTrue(chooseBank.waitForExistence(timeout: 3))
        XCTAssertTrue(chooseBank.isHittable)
        XCTAssertTrue(app.buttons["portfolio.bank.DBS"].isHittable)
        let connect = app.buttons["portfolio.bank.connect"]
        XCTAssertFalse(connect.isEnabled)
        attachScreenshot(app, name: "Bank choices visible")
        let consent = app.switches["portfolio.bank.consent"]
        scrollUntilHittable(consent, in: app)
        consent.tap()
        XCTAssertTrue(connect.isEnabled)

        app.buttons["portfolio.flow.back"].tap()
        XCTAssertTrue(app.buttons["portfolio.add.bank"].waitForExistence(timeout: 3))
        XCTAssertEqual(chooserTitle.frame.minY, chooserTop, accuracy: 3)
        app.buttons["portfolio.add.bank"].tap()
        XCTAssertTrue(connect.waitForExistence(timeout: 3))
        XCTAssertFalse(connect.isEnabled, "Reopening a bank connection must start with fresh consent.")
        app.navigationBars["Other bank account"].buttons["portfolio.add.close"].tap()
        XCTAssertTrue(app.buttons["banking.tab.wealth"].isHittable)
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
        XCTAssertTrue(app.navigationBars["Extracted outcome"].buttons["portfolio.add.close"].exists)
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

    func testFUTUScreenshotUploadReviewCancelAndSaveAccount() throws {
        // Seed the simulator Photos library with the supplied screenshot as its newest
        // photo, then run with TEST_RUNNER_FUTU_SCREENSHOT_UI_TEST=1. The private image
        // stays outside the repository, and this flow uses the actual picker and OCR.
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FUTU_SCREENSHOT_UI_TEST"] == "1",
                          "Requires the supplied FUTU screenshot in the simulator Photos library.")
        let app = launch()
        openAddPortfolio(in: app)
        app.buttons["portfolio.add.statement"].tap()
        app.buttons["portfolio.statement.upload"].tap()
        let choosePhoto = app.buttons["Choose a photo"]
        XCTAssertTrue(choosePhoto.waitForExistence(timeout: 3))
        choosePhoto.tap()
        selectNewestStatementPhoto(in: app)
        XCTAssertTrue(app.navigationBars["Extracted outcome"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["I’ve found 2 holdings in this statement:"].exists)
        attachScreenshot(app, name: "FUTU screenshot recognised before confirmation")

        // Recognition creates a draft only: dismissing it must not add an account.
        app.buttons["portfolio.extracted.cancel"].tap()
        XCTAssertTrue(app.buttons["banking.tab.wealth"].waitForExistence(timeout: 5))
        scrollUntilHittable(app.buttons["accountSelector"], in: app, upwards: false)
        app.buttons["accountSelector"].tap()
        XCTAssertTrue(app.staticTexts["accountSelector.title"].waitForExistence(timeout: 3))
        for market in ["sg", "hk"] {
            app.buttons["accountSelector.market.\(market)"].tap()
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "FUTU")).count, 0,
                           "Cancelling recognition must not create a FUTU account in either market.")
        }
        app.buttons["accountSelector.close"].tap()

        let addHoldings = app.buttons["portfolio.addHoldings"]
        scrollUntilHittable(addHoldings, in: app)
        addHoldings.tap()
        app.buttons["portfolio.add.statement"].tap()
        // Verify the camera entry on devices with either a camera or the supported
        // library fallback, then use the same real screenshot for deterministic OCR.
        XCTAssertTrue(app.navigationBars["Upload or scan a statement"].waitForExistence(timeout: 3))
        let camera = app.buttons["portfolio.statement.camera"]
        var previousCameraFrame = CGRect.zero
        let cameraSettled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = camera.frame
            defer { previousCameraFrame = frame }
            return camera.exists && camera.isHittable && frame == previousCameraFrame && !frame.isEmpty
        }, object: camera)
        XCTAssertEqual(XCTWaiter.wait(for: [cameraSettled], timeout: 5), .completed,
                       "Wait for the reopened statement sheet to finish moving before tapping its camera action.")
        camera.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let savedPhoto = app.buttons["Choose a saved photo"]
        let shutter = app.buttons["PhotoCapture"]
        let cameraReady = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            savedPhoto.exists || shutter.exists
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [cameraReady], timeout: 10), .completed,
                       "The camera entry must open either the system camera or its photo-library fallback.")
        if savedPhoto.exists {
            savedPhoto.tap()
        } else {
            XCTAssertTrue(shutter.exists, "The system camera must expose its Take Picture control.")
            app.buttons["DismissImagePickerButton"].tap()
            let cameraDismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: shutter)
            XCTAssertEqual(XCTWaiter.wait(for: [cameraDismissed], timeout: 5), .completed)
            XCTAssertTrue(app.navigationBars["Upload or scan a statement"].waitForExistence(timeout: 3))
            app.buttons["portfolio.statement.upload"].tap()
            XCTAssertTrue(choosePhoto.waitForExistence(timeout: 3))
            choosePhoto.tap()
        }
        selectNewestStatementPhoto(in: app)
        XCTAssertTrue(app.navigationBars["Extracted outcome"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["I’ve found 2 holdings in this statement:"].exists)

        let accountEdit = app.buttons["portfolio.extracted.account.edit"]
        scrollUntilHittable(accountEdit, in: app, upwards: false)
        accountEdit.tap()
        XCTAssertTrue(app.navigationBars["Edit account"].waitForExistence(timeout: 3))
        let accountName = app.textFields["portfolio.extracted.account.name"]
        let institution = app.textFields["portfolio.extracted.account.institution"]
        XCTAssertTrue((accountName.value as? String ?? "").contains("FUTU"))
        XCTAssertEqual(institution.value as? String, "FUTU")
        let accountHierarchy = XCTAttachment(string: app.debugDescription)
        accountHierarchy.name = "Detected FUTU account editor accessibility hierarchy"
        accountHierarchy.lifetime = .keepAlways
        add(accountHierarchy)
        attachScreenshot(app, name: "Detected FUTU account details")
        assertClosedPickerValue("SGD", identifier: "portfolio.extracted.account.currency", in: app)
        assertClosedPickerValue("Singapore", identifier: "portfolio.extracted.account.market", in: app)
        let accountNumber = app.textFields["portfolio.extracted.account.number"]
        let detectedNumber = accountNumber.value as? String ?? ""
        XCTAssertTrue(detectedNumber.isEmpty || detectedNumber == accountNumber.placeholderValue,
                      "The cropped crypto footer must not supply a guessed number for the stock account.")
        replaceText(in: accountName, with: "FUTU Screenshot Portfolio")
        app.buttons["portfolio.extracted.account.save"].tap()
        XCTAssertTrue(app.navigationBars["Extracted outcome"].waitForExistence(timeout: 3))

        assertExtractedHolding("D05", quantity: 2, price: 77.08, cost: 57.30, currency: "SGD", in: app)
        assertExtractedHolding("KITT", quantity: 3, price: 0.699, cost: 362.88, currency: "USD", in: app)
        scrollUntilHittable(accountEdit, in: app, upwards: false)
        attachScreenshot(app, name: "Reviewed FUTU account with SGD and USD holdings")
        let proceed = app.buttons["portfolio.extracted.proceed"]
        XCTAssertTrue(proceed.isEnabled)
        proceed.tap()
        XCTAssertTrue(app.buttons["banking.tab.wealth"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["portfolio.analysis.updated"].firstMatch.waitForExistence(timeout: 8))

        scrollUntilHittable(app.buttons["accountSelector"], in: app, upwards: false)
        app.buttons["accountSelector"].tap()
        XCTAssertTrue(app.staticTexts["accountSelector.title"].waitForExistence(timeout: 3))
        app.buttons["accountSelector.market.sg"].tap()
        let importedAccount = app.buttons.containing(.staticText, identifier: "FUTU Screenshot Portfolio")
        scrollUntilHittable(importedAccount.firstMatch, in: app)
        XCTAssertEqual(importedAccount.count, 1, "Proceed must save exactly one account containing both currency positions.")
        XCTAssertEqual(importedAccount.firstMatch.value as? String, "Selected")
        attachScreenshot(app, name: "Confirmed FUTU account in account selector")
    }

    func testAddingExistingGlobalHSBCAccountsDoesNotDuplicateThem() throws {
        let app = launch()
        openAddPortfolio(in: app)
        includeGlobalHSBCAccounts(in: app)

        // Linked accounts disappear from the list of accounts still available to add.
        openAddPortfolio(in: app)
        app.buttons["portfolio.add.hsbc"].tap()
        let confirm = app.buttons["portfolio.hsbc.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        XCTAssertFalse(confirm.isEnabled)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "portfolio.hsbc.account.")).count, 0)
        app.navigationBars["Global HSBC accounts"].buttons["portfolio.add.close"].tap()
        XCTAssertTrue(app.buttons["banking.tab.wealth"].waitForExistence(timeout: 5))
        assertAccountInventory(singapore: [1, 2, 3], hongKong: [6, 7], in: app)
    }

    func testDemoAccountsLinkDuringSessionAndResetOnlyAfterColdLaunch() throws {
        let app = launch()
        assertAccountInventory(singapore: [1, 2], hongKong: [6], in: app)
        linkAllAvailableDemoAccounts(in: app)
        assertAccountInventory(singapore: [1, 2, 3, 4], hongKong: [6, 7, 8], in: app)
        attachScreenshot(app, name: "Seven demo accounts linked during the current session")

        XCUIDevice.shared.press(.home)
        let backgrounded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.state == .runningBackground || app.state == .runningBackgroundSuspended
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [backgrounded], timeout: 5), .completed)
        app.activate()
        XCTAssertTrue(app.buttons["banking.tab.wealth"].waitForExistence(timeout: 5))
        assertAccountInventory(singapore: [1, 2, 3, 4], hongKong: [6, 7, 8], in: app)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["banking.tab.wealth"].waitForExistence(timeout: 10))
        assertAccountInventory(singapore: [1, 2], hongKong: [6], in: app)
        let generate = app.buttons["portfolio.analysis.generate"]
        scrollUntilHittable(generate, in: app)
        XCTAssertTrue(generate.isEnabled, "A new launch must make the first analysis and add-account flow available again.")
        openAddPortfolio(in: app)
        includeGlobalHSBCAccounts(in: app)
        assertAccountInventory(singapore: [1, 2, 3], hongKong: [6, 7], in: app)
    }

    func testLinkedAccountsAndGlobalInvestmentViews() throws {
        let app = launch()
        linkAllAvailableDemoAccounts(in: app)
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

        let allocation = app.descendants(matching: .any)["giv.holdings.allocationBar"].firstMatch
        XCTAssertTrue(allocation.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["giv.markets.region"].exists)

        let performance = app.buttons["giv.tab.Performance"]
        scrollUntilHittable(performance, in: app, upwards: false)
        performance.tap()
        XCTAssertTrue(app.buttons["giv.performance.period.ytd"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["giv.performance.period.ytd"].isSelected)
        let ytdReturn = app.descendants(matching: .any)["giv.performance.return"].firstMatch.label
        app.buttons["giv.performance.period.year"].tap()
        XCTAssertTrue(app.buttons["giv.performance.period.year"].isSelected)
        XCTAssertNotEqual(ytdReturn, app.descendants(matching: .any)["giv.performance.return"].firstMatch.label)
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

    func testGlobalMarketsShowsAllocationBarAndVerticalHoldings() throws {
        let app = launch()
        linkAllAvailableDemoAccounts(in: app)
        app.buttons["wealth.viewDetails"].tap()
        XCTAssertTrue(app.buttons["giv.accounts"].waitForExistence(timeout: 5))
        selectAllGIVAccounts(in: app)

        let allocation = app.descendants(matching: .any)["giv.holdings.allocationBar"].firstMatch
        XCTAssertTrue(allocation.waitForExistence(timeout: 3))
        scrollUntilHittable(allocation, in: app)
        XCTAssertGreaterThan(allocation.frame.width, allocation.frame.height, "Asset allocation must use a horizontal bar.")
        XCTAssertFalse(app.buttons["giv.markets.region"].exists)
        XCTAssertFalse(app.buttons["giv.markets.asset"].exists)

        let stocks = app.buttons["giv.holdings.Stocks"]
        let bonds = app.buttons["giv.holdings.Bonds"]
        XCTAssertTrue(stocks.waitForExistence(timeout: 3))
        XCTAssertTrue(bonds.exists)
        XCTAssertGreaterThan(bonds.frame.minY, stocks.frame.maxY - 1, "Asset categories must form a vertical list.")
        XCTAssertEqual(stocks.frame.minX, bonds.frame.minX, accuracy: 2)
        XCTAssertEqual(stocks.frame.width, bonds.frame.width, accuracy: 2)
        let markets = app.descendants(matching: .any)["giv.holdings.markets.Stocks"].firstMatch
        XCTAssertTrue(markets.exists)
        XCTAssertTrue(markets.label.contains("SG"))
        XCTAssertTrue(markets.label.contains("HK"))
        let gain = app.descendants(matching: .any)["giv.holdings.gain.Stocks"].firstMatch
        XCTAssertTrue(gain.exists)
        XCTAssertFalse(gain.label.isEmpty)
        attachScreenshot(app, name: "GIV global Markets - allocation bar and vertical SG HK holdings")

        scrollUntilHittable(stocks, in: app)
        stocks.tap()
        let holding = app.staticTexts["NVIDIA"]
        XCTAssertTrue(holding.waitForExistence(timeout: 3), "An asset category must still expand to its underlying holdings.")
        attachScreenshot(app, name: "GIV global Markets - expanded stock holdings")
    }

    func testGlobalPerformanceDefaultsToYTDWithReferenceComparison() throws {
        let app = launch()
        linkAllAvailableDemoAccounts(in: app)
        app.buttons["wealth.viewDetails"].tap()
        XCTAssertTrue(app.buttons["giv.accounts"].waitForExistence(timeout: 5))
        selectAllGIVAccounts(in: app)
        app.buttons["giv.tab.Performance"].tap()

        let ytd = app.buttons["giv.performance.period.ytd"]
        XCTAssertTrue(ytd.waitForExistence(timeout: 3))
        XCTAssertTrue(ytd.isSelected, "The latest design opens Performance at year to date.")
        assertHSBCReference("HSBC reference: (068) Equity Investment Account · Singapore", in: app)
        XCTAssertTrue(app.buttons["giv.performance.benchmark.S&P 500"].isSelected)
        let tooltipElements = app.descendants(matching: .any)
            .matching(identifier: "giv.performance.tooltip")
        XCTAssertTrue(tooltipElements.firstMatch.exists)
        // SwiftUI can expose the VStack as combined labels or propagate its
        // identifier to separate texts. Scope both forms to the tooltip so the
        // legend cannot satisfy these assertions about the displayed returns.
        let tooltipText = tooltipElements.allElementsBoundByIndex.flatMap { element in
            [element.label] + element.descendants(matching: .staticText).allElementsBoundByIndex.map(\.label)
        }.joined(separator: "\n")
        for name in ["My total return", "HSBC reference portfolio", "S&P 500"] {
            XCTAssertTrue(tooltipText.contains(name), "The tooltip must expose \(name). Actual tooltip: \(tooltipText)")
        }
        attachScreenshot(app, name: "GIV global Performance - default YTD versus HSBC reference and S&P 500")
    }

    func testHSBCReferenceUsesSelectedSingaporeAndHongKongAccounts() throws {
        let app = launch()
        app.buttons["wealth.viewDetails"].tap()
        XCTAssertTrue(app.buttons["giv.accounts"].waitForExistence(timeout: 5))
        selectOnlyGIVAccount("10000000-0000-4000-8000-000000000002", market: "sg", in: app)
        app.buttons["giv.tab.Performance"].tap()
        assertHSBCReference("HSBC reference: (068) Equity Investment Account · Singapore", in: app)
        attachScreenshot(app, name: "Reference SG - Equity Investment Account overlaps HSBC reference")

        selectOnlyGIVAccount("10000000-0000-4000-8000-000000000006", market: "hk", in: app)
        assertHSBCReference("HSBC reference: HSBC One Investment Services · Hong Kong", in: app)
        attachScreenshot(app, name: "Reference HK - HSBC One Investment Services overlaps HSBC reference")
    }

    func testOtherBankPerformanceKeepsHSBCAndMarketBenchmarksEnabled() throws {
        let app = launch()
        connectOtherBank("DBS", in: app)
        scrollUntilHittable(app.buttons["wealth.viewDetails"], in: app, upwards: false)
        app.buttons["wealth.viewDetails"].tap()
        XCTAssertTrue(app.buttons["giv.accounts"].waitForExistence(timeout: 5))
        selectOnlyGIVAccount("10000000-0000-4000-8000-000000000004", market: "sg", in: app)
        XCTAssertTrue(app.buttons["giv.accounts"].label.contains("DBS Account"))
        app.buttons["giv.tab.Performance"].tap()

        assertHSBCReference("HSBC reference: (068) Equity Investment Account · Singapore", in: app)
        let marketBenchmark = app.buttons["giv.performance.benchmark.S&P 500"]
        XCTAssertTrue(marketBenchmark.isEnabled)
        XCTAssertTrue(marketBenchmark.isSelected, "The market benchmark must remain selected alongside HSBC when viewing only DBS.")
        let chart = app.descendants(matching: .any)["giv.performance.chart"].firstMatch
        XCTAssertTrue(chart.exists)
        attachScreenshot(app, name: "Reference SG - DBS versus HSBC reference and S&P 500")
    }

    func testHSBCReferenceFollowsPerformanceMarket() throws {
        let app = launch()
        app.buttons["wealth.viewDetails"].tap()
        XCTAssertTrue(app.buttons["giv.accounts"].waitForExistence(timeout: 5))
        app.buttons["giv.accounts"].tap()
        let global = app.buttons["accountSelector.global"]
        XCTAssertTrue(global.waitForExistence(timeout: 3))
        if global.value as? String != "Selected" { global.tap() }
        app.buttons["Confirm"].tap()
        app.buttons["giv.tab.Performance"].tap()

        let hongKong = app.buttons["giv.performance.market.Hong Kong"]
        XCTAssertTrue(hongKong.waitForExistence(timeout: 3))
        hongKong.tap()
        XCTAssertTrue(hongKong.isSelected)
        assertHSBCReference("HSBC reference: HSBC One Investment Services · Hong Kong", in: app)

        let singapore = app.buttons["giv.performance.market.Singapore"]
        scrollUntilHittable(hongKong, in: app, upwards: false)
        // The final market chip can be outside the horizontal viewport on iPhone.
        let marketStrip = app.scrollViews.containing(.button, identifier: "giv.performance.market.Singapore").allElementsBoundByIndex.last
        for _ in 0..<3 {
            if singapore.isHittable { break }
            marketStrip?.swipeLeft()
        }
        XCTAssertTrue(singapore.isHittable)
        singapore.tap()
        XCTAssertTrue(singapore.isSelected)
        assertHSBCReference("HSBC reference: (068) Equity Investment Account · Singapore", in: app)
    }

    private func selectAllGIVAccounts(in app: XCUIApplication) {
        let selector = app.buttons["giv.accounts"]
        scrollUntilHittable(selector, in: app, upwards: false)
        selector.tap()
        let global = app.buttons["accountSelector.global"]
        XCTAssertTrue(global.waitForExistence(timeout: 3))
        if global.value as? String != "Selected" { global.tap() }
        app.buttons["Confirm"].tap()
        XCTAssertTrue(selector.waitForExistence(timeout: 3))
        XCTAssertTrue(selector.label.contains("All global accounts selected"))
    }

    private func selectOnlyGIVAccount(_ id: String, market: String, in app: XCUIApplication) {
        let selector = app.buttons["giv.accounts"]
        scrollUntilHittable(selector, in: app, upwards: false)
        selector.tap()
        let global = app.buttons["accountSelector.global"]
        XCTAssertTrue(global.waitForExistence(timeout: 3))
        // Normalize any previous selection before selecting the one account.
        if global.value as? String != "Selected" { global.tap() }
        global.tap()
        app.buttons["accountSelector.market.\(market)"].tap()
        let account = app.buttons["accountSelector.account.\(id)"]
        scrollUntilHittable(account, in: app)
        account.tap()
        XCTAssertEqual(account.value as? String, "Selected")
        app.buttons["Confirm"].tap()
        XCTAssertTrue(selector.waitForExistence(timeout: 3))
    }

    private func assertHSBCReference(_ expectedSource: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let source = app.staticTexts["giv.performance.referenceSource"]
        XCTAssertTrue(source.waitForExistence(timeout: 3), file: file, line: line)
        XCTAssertEqual(source.label, expectedSource, file: file, line: line)
        let reference = app.buttons["giv.performance.benchmark.HSBC reference portfolio"]
        scrollUntilHittable(reference, in: app, file: file, line: line)
        XCTAssertTrue(reference.isSelected, "The HSBC reference must be enabled without tapping its legend.", file: file, line: line)
    }

    private func selectNewestStatementPhoto(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        // The system picker follows the device language, independently of the app.
        // Its asset identifier is stable in English and Chinese; the library shows
        // the newest seeded photo first, ahead of the simulator's stock photos.
        let photos = app.scrollViews["photosView_content_scroll_view"].images.matching(identifier: "PXGGridLayout-Info")
        guard photos.firstMatch.waitForExistence(timeout: 8) else {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Photo picker accessibility hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            attachScreenshot(app, name: "Photo picker needs seeded statement image")
            XCTFail("The native photo picker did not expose the seeded photo.", file: file, line: line)
            return
        }
        // Photos exposes thumbnails as virtual accessibility images, which XCTest
        // can resolve but cannot always hit-test. Tap the observed thumbnail centre.
        photos.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func assertExtractedHolding(_ symbol: String, quantity: Double, price: Double, cost: Double, currency: String,
                                        in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let holding = app.buttons["portfolio.extracted.holding.\(symbol)"]
        scrollUntilHittable(holding, in: app, file: file, line: line)
        holding.tap()
        XCTAssertTrue(app.navigationBars["Edit holding"].waitForExistence(timeout: 3), file: file, line: line)
        XCTAssertEqual(app.textFields["portfolio.holding.symbol"].value as? String, symbol, file: file, line: line)
        attachScreenshot(app, name: "Extracted \(symbol) holding details")
        assertClosedPickerValue(currency, identifier: "portfolio.holding.currency", in: app, file: file, line: line)
        for (field, expected) in [("quantity", quantity), ("price", price), ("cost", cost)] {
            let value = app.textFields["portfolio.holding.\(field)"].value as? String ?? ""
            XCTAssertEqual(Double(value) ?? .nan, expected, accuracy: 0.0001, "Incorrect extracted \(symbol) \(field)", file: file, line: line)
        }
        app.navigationBars["Edit holding"].buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Extracted outcome"].waitForExistence(timeout: 3), file: file, line: line)
    }

    private func assertClosedPickerValue(_ expected: String, identifier: String, in app: XCUIApplication,
                                         file: StaticString = #filePath, line: UInt = #line) {
        // SwiftUI can assign a Picker identifier to both its empty accessibility
        // container and its menu button. Only inspect this closed field and its
        // descendants, so another holding's currency cannot satisfy the assertion.
        let fields = app.descendants(matching: .any).matching(identifier: identifier)
        XCTAssertTrue(fields.firstMatch.waitForExistence(timeout: 3), file: file, line: line)
        let nodes = fields.allElementsBoundByIndex.flatMap { field in
            [field] + field.descendants(matching: .any).allElementsBoundByIndex
        }
        let fieldValues = Set(nodes.flatMap { node in [node.label, node.value as? String ?? ""] })
        XCTAssertTrue(fieldValues.contains(expected),
                      "Expected \(identifier) to display exactly \(expected); field accessibility values: \(fieldValues.sorted())",
                      file: file, line: line)
    }

    private func openAddPortfolio(in app: XCUIApplication) {
        let addHoldings = app.buttons["portfolio.addHoldings"]
        if !addHoldings.exists {
            let generate = app.buttons["portfolio.analysis.generate"]
            scrollUntilHittable(generate, in: app)
            generate.tap()
            XCTAssertTrue(addHoldings.waitForExistence(timeout: 8))
        }
        scrollUntilHittable(addHoldings, in: app)
        positionWealthButton(addHoldings, in: app)
        recordPortfolioAddGeometry(addHoldings, in: app, name: "Before opening Add a portfolio")
        attachScreenshot(app, name: "Add portfolio button fully visible before tapping")
        addHoldings.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let opened = app.buttons["portfolio.add.statement"].waitForExistence(timeout: 3)
        if !opened {
            attachScreenshot(app, name: "Add portfolio did not open after one tap")
            recordPortfolioAddGeometry(addHoldings, in: app, name: "Add a portfolio failed to open")
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Add portfolio presentation failure hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        XCTAssertTrue(opened)
    }

    private func positionWealthButton(_ button: XCUIElement, in app: XCUIApplication) {
        // isHittable can be true when only the top of this button is exposed above
        // the persistent help bar. Put its whole frame inside the scroll viewport.
        for _ in 0..<5 {
            let frame = button.frame
            let visible = portfolioVisibleBounds(in: app)
            if visible.contains(frame) && button.isHittable { return }
            let delta = frame.midY - visible.midY
            let distance = min(max(abs(delta), 60), visible.height * 0.55)
            let direction: CGFloat = delta >= 0 ? 1 : -1
            let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                dx: visible.midX - app.frame.minX,
                dy: visible.midY - app.frame.minY + direction * distance / 2))
            let end = start.withOffset(CGVector(dx: 0, dy: -direction * distance))
            XCTContext.runActivity(named: "Position Wealth button: \(button.identifier) \(frame) inside \(visible)") { _ in
                start.press(forDuration: 0.05, thenDragTo: end)
                recordPortfolioAddGeometry(button, in: app, name: "After positioning Add button")
            }
        }
        if portfolioVisibleBounds(in: app).contains(button.frame) && button.isHittable { return }
        recordPortfolioAddGeometry(button, in: app, name: "Add button could not become fully visible")
        attachScreenshot(app, name: "Add portfolio button remains outside the usable viewport")
        XCTAssertTrue(portfolioVisibleBounds(in: app).contains(button.frame) && button.isHittable,
                      "The entire Add button must be visible above the persistent help bar before tapping.")
    }

    private func portfolioVisibleBounds(in app: XCUIApplication) -> CGRect {
        let wealthTab = app.buttons["banking.tab.wealth"]
        let help = app.buttons["wealth.assistant.open"]
        let top = wealthTab.exists ? max(app.frame.minY + 20, wealthTab.frame.maxY + 12) : app.frame.minY + 20
        let bottom = help.exists ? help.frame.minY - 16 : app.frame.maxY - 40
        return CGRect(x: app.frame.minX + 8, y: top, width: app.frame.width - 16, height: max(1, bottom - top))
    }

    private func recordPortfolioAddGeometry(_ button: XCUIElement, in app: XCUIApplication, name: String) {
        let buttonGeometry = button.exists ? "button=\(button.frame), hittable=\(button.isHittable)" : "button absent"
        let geometry = "\(buttonGeometry), visible=\(portfolioVisibleBounds(in: app)), app=\(app.frame)"
        XCTContext.runActivity(named: "\(name): \(geometry)") { _ in
            let attachment = XCTAttachment(string: geometry)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func linkAllAvailableDemoAccounts(in app: XCUIApplication) {
        openAddPortfolio(in: app)
        includeGlobalHSBCAccounts(in: app)
        connectOtherBank("DBS", in: app)
        connectOtherBank("Standard Chartered", in: app)
        let details = app.buttons["wealth.viewDetails"]
        scrollUntilHittable(details, in: app, upwards: false)
        positionWealthButton(details, in: app)
    }

    private func connectOtherBank(_ bank: String, in app: XCUIApplication) {
        openAddPortfolio(in: app)
        app.buttons["portfolio.add.bank"].tap()
        let bankOption = app.buttons["portfolio.bank.\(bank)"]
        XCTAssertTrue(bankOption.waitForExistence(timeout: 3))
        scrollUntilHittable(bankOption, in: app)
        bankOption.tap()
        let connect = app.buttons["portfolio.bank.connect"]
        XCTAssertFalse(connect.isEnabled)
        let consent = app.switches["portfolio.bank.consent"]
        scrollUntilHittable(consent, in: app)
        consent.tap()
        XCTAssertTrue(connect.isEnabled)
        connect.tap()
        let proceed = app.buttons["portfolio.bank.proceed"]
        XCTAssertTrue(proceed.waitForExistence(timeout: 3))
        XCTAssertTrue(proceed.isEnabled)
        proceed.tap()
        XCTAssertTrue(app.buttons["banking.tab.wealth"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["portfolio.analysis.updated"].firstMatch.waitForExistence(timeout: 8))
    }

    private func includeGlobalHSBCAccounts(in app: XCUIApplication) {
        let hsbc = app.buttons["portfolio.add.hsbc"]
        XCTAssertTrue(hsbc.waitForExistence(timeout: 3))
        hsbc.tap()
        let confirm = app.buttons["portfolio.hsbc.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        let available = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "portfolio.hsbc.account."))
        XCTAssertEqual(available.count, 2, "Only the two unlinked HSBC portfolios should be offered.")
        for number in [3, 7] {
            let account = app.buttons["portfolio.hsbc.account.\(demoAccountID(number))"]
            XCTAssertTrue(account.exists)
            XCTAssertTrue(account.isSelected, "Available HSBC accounts must be selected by default.")
        }
        XCTAssertTrue(confirm.isEnabled)
        confirm.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["banking.tab.wealth"].waitForExistence(timeout: 5))
        let updated = app.descendants(matching: .any)["portfolio.analysis.updated"].firstMatch
        XCTAssertTrue(updated.waitForExistence(timeout: 8))
    }

    private func assertAccountInventory(singapore: [Int], hongKong: [Int], in app: XCUIApplication,
                                        file: StaticString = #filePath, line: UInt = #line) {
        let selector = app.buttons["accountSelector"]
        scrollUntilHittable(selector, in: app, upwards: false, file: file, line: line)
        selector.tap()
        XCTAssertTrue(app.staticTexts["accountSelector.title"].waitForExistence(timeout: 3), file: file, line: line)
        for (market, numbers) in [("sg", singapore), ("hk", hongKong)] {
            app.buttons["accountSelector.market.\(market)"].tap()
            let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "accountSelector.account."))
            let expected = Set(numbers.map { "accountSelector.account." + demoAccountID($0) })
            let actual = Set(rows.allElementsBoundByIndex.map(\.identifier))
            XCTAssertEqual(actual, expected, "Unexpected \(market) accounts in the current demo session.", file: file, line: line)
            XCTAssertEqual(rows.count, expected.count, "Each linked account must appear exactly once.", file: file, line: line)
        }
        app.buttons["accountSelector.close"].tap()
        XCTAssertTrue(app.buttons["banking.tab.wealth"].waitForExistence(timeout: 3), file: file, line: line)
    }

    private func demoAccountID(_ number: Int) -> String {
        "10000000-0000-4000-8000-" + String(format: "%012d", number)
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
