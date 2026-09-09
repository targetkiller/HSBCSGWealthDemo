import XCTest
@testable import WealthHub

final class PortfolioTests: XCTestCase {
    func testMixedCurrencyValuationAndAllocation() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = PortfolioStore(defaults: defaults)
        store.currency = .CNY
        for account in store.accounts { store.deleteAccount(id: account.id) }
        let account = InvestmentAccount(name: "Test", institution: "Local", currency: .USD, colorIndex: 0, holdings: [
            .init(name: "Stock", symbol: "S", category: .stock, currency: .USD, quantity: 2, price: 100, averageCost: 80),
            .init(name: "Cash", symbol: "C", category: .cash, currency: .HKD, quantity: 100, price: 1, averageCost: 1)
        ])
        store.save(account)
        XCTAssertEqual(store.totalValue, 1532, accuracy: 0.001)
        XCTAssertEqual(store.totalProfit, 288, accuracy: 0.001)
        XCTAssertEqual(store.allocation().reduce(0) { $0 + $1.value }, store.totalValue, accuracy: 0.001)
        store.currency = .USD
        XCTAssertEqual(store.totalValue, 1532 / 7.2, accuracy: 0.001)
    }

    func testCRUDPersistsIncludingEmptyPortfolio() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = PortfolioStore(defaults: defaults)
        let account = InvestmentAccount(name: "New", institution: "Demo", currency: .CNY, colorIndex: 0)
        store.save(account)
        let holding = Holding(name: "Cash", symbol: "CNY", category: .cash, currency: .CNY, quantity: 500, price: 1, averageCost: 1)
        store.saveHolding(holding, accountID: account.id)
        XCTAssertEqual(PortfolioStore(defaults: defaults).accounts.last?.holdings.first?.value, 500)
        var updated = holding
        updated.quantity = 750
        store.saveHolding(updated, accountID: account.id)
        let persistedHoldings = PortfolioStore(defaults: defaults).accounts.last!.holdings
        XCTAssertEqual(persistedHoldings.count, 1)
        XCTAssertEqual(persistedHoldings.first?.value, 750)
        store.deleteHolding(id: holding.id, accountID: account.id)
        XCTAssertTrue(store.accounts.last!.holdings.isEmpty)
        for item in store.accounts { store.deleteAccount(id: item.id) }
        let restored = PortfolioStore(defaults: defaults)
        XCTAssertTrue(restored.accounts.isEmpty)
        XCTAssertNil(restored.totalReturn)
        XCTAssertEqual(restored.totalValue, 0)
    }

    func testStatementImportRejectsInvalidRowsAtomically() throws {
        XCTAssertEqual(try StatementParser.parse(StatementParser.template).count, 2)
        let header = "name,symbol,category,currency,quantity,price,averageCost\n"
        XCTAssertThrowsError(try StatementParser.parse(header + "Bad,X,Stocks,USD,-1,2,1"))
        XCTAssertThrowsError(try StatementParser.parse(header + "Bad,X,Stocks,USD,1,nan,1"))
        XCTAssertThrowsError(try StatementParser.parse(header + "Bad,X,Stocks,INVALID,1,2,1"))
        XCTAssertThrowsError(try StatementParser.parse(header + "Cash,SGD,Cash and FX,SGD,10,1,1\nBad,X,Stocks,USD,1,2"))
    }

    func testDefaultAccountsCoverBothMarketsAndAllAssetClasses() {
        let accounts = DemoData.accounts
        XCTAssertEqual(accounts.count, 8)
        XCTAssertEqual(accounts.filter { $0.market == "Singapore" }.count, 4)
        XCTAssertEqual(accounts.filter { $0.market == "Hong Kong" }.count, 4)
        XCTAssertEqual(Set(accounts.map(\.id)).count, 8)
        XCTAssertEqual(Set(accounts.compactMap(\.accountNumber)).count, 8)
        XCTAssertEqual(Set(accounts.map(\.institution)), ["HSBC", "DBS", "Standard Chartered"])
        let holdings = accounts.flatMap(\.holdings)
        XCTAssertGreaterThanOrEqual(holdings.count, 35)
        XCTAssertEqual(Set(holdings.map(\.category)), Set(AssetClass.allCases))
        XCTAssertEqual(Set(holdings.map(\.currency)), Set(Currency.allCases))
        XCTAssertTrue(holdings.allSatisfy { !($0.region ?? "").isEmpty && !($0.sector ?? "").isEmpty })
        XCTAssertTrue(holdings.allSatisfy { $0.quantity > 0 && $0.price > 0 && $0.averageCost > 0 })
    }

    func testCurrencyAmountsUseISOSuffixForFullAndCompactValues() {
        XCTAssertEqual(Currency.SGD.format(1234.5), "1,234.50 SGD")
        XCTAssertEqual(Currency.USD.format(-42.1), "-42.10 USD")
        XCTAssertEqual(Currency.HKD.format(1_234_000, compact: true), "1.23M HKD")
        XCTAssertEqual(Currency.CNY.format(1200, compact: true), "1.2K CNY")
        XCTAssertEqual(Currency.USD.format(0, compact: true), "0.00 USD")
        for currency in Currency.allCases {
            XCTAssertFalse(currency.format(100).contains("$"))
            XCTAssertFalse(currency.format(100, compact: true).contains("¥"))
        }
    }

    func testOldAccountJSONDecodesWithoutNewMetadata() throws {
        let data = Data("""
        {"id":"B1000000-0000-4000-8000-000000000001","name":"Legacy","institution":"HSBC","currency":"SGD","colorIndex":0,"note":"","market":"Singapore","holdings":[{"id":"B2000000-0000-4000-8000-000000000001","name":"Stock","symbol":"S","category":"Stocks","currency":"USD","quantity":2,"price":100,"averageCost":80}]}
        """.utf8)
        let account = try JSONDecoder().decode(InvestmentAccount.self, from: data)
        XCTAssertNil(account.accountNumber)
        XCTAssertNil(account.holdings.first?.region)
        XCTAssertNil(account.holdings.first?.sector)
        XCTAssertEqual(account.holdings.first?.value, 200)
    }

    func testLegacyMigrationPreservesEditsAndAddsMissingDefaultsOnce() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        var legacy = legacyAccounts()
        let originalEquityID = legacy[0].id
        legacy[0].name = "My edited growth portfolio"
        legacy[0].note = "Keep this note"
        legacy[0].currency = .CNY
        legacy[0].holdings.removeAll { $0.symbol == "AAPL" }
        legacy[0].holdings[0].price = 141.25
        legacy[0].holdings[0].region = "My custom region"
        let editedHoldingID = legacy[0].holdings[0].id
        let customHolding = Holding(name: "My private fund", symbol: "PRIVATE", category: .fund, currency: .SGD, quantity: 12, price: 500, averageCost: 450, region: "Japan", sector: "My sector")
        legacy[0].holdings.append(customHolding)
        let customAccount = InvestmentAccount(name: "User imported account", institution: "Local", currency: .USD, colorIndex: 4, holdings: [customHolding], accountNumber: "USER-001")
        try storeLegacySnapshot(legacy + [customAccount], in: defaults)

        let migrated = PortfolioStore(defaults: defaults)
        XCTAssertEqual(migrated.accounts.count, 9)
        XCTAssertEqual(migrated.currency, .CNY)
        XCTAssertTrue(migrated.hideAmounts)
        let equity = try XCTUnwrap(migrated.accounts.first { $0.id == originalEquityID })
        XCTAssertEqual(equity.name, "My edited growth portfolio")
        XCTAssertEqual(equity.note, "Keep this note")
        XCTAssertEqual(equity.currency, .CNY)
        XCTAssertEqual(equity.holdings.count, legacy[0].holdings.count)
        XCTAssertFalse(equity.holdings.contains { $0.symbol == "AAPL" })
        let edited = try XCTUnwrap(equity.holdings.first { $0.id == editedHoldingID })
        XCTAssertEqual(edited.price, 141.25)
        XCTAssertEqual(edited.region, "My custom region")
        XCTAssertEqual(edited.sector, "Technology")
        XCTAssertEqual(equity.holdings.first { $0.id == customHolding.id }, customHolding)
        XCTAssertEqual(migrated.accounts.first { $0.id == customAccount.id }, customAccount)
        XCTAssertEqual(migrated.accounts.first { $0.id == legacy[1].id }?.name, "HSBC One Investment Services")
        XCTAssertEqual(migrated.accounts.first { $0.id == legacy[2].id }?.name, "DBS Account")
        XCTAssertEqual(equity.accountNumber, "068-981234-001")

        let seedToRemove = DemoData.accounts[0].id
        migrated.deleteAccount(id: seedToRemove)
        let reopened = PortfolioStore(defaults: defaults)
        XCTAssertEqual(reopened.accounts.count, 8)
        XCTAssertFalse(reopened.accounts.contains { $0.id == seedToRemove }, "An account deleted after migration must not be restored on launch.")
        XCTAssertEqual(Set(reopened.accounts.map(\.id)).count, 8)
        let saved = try XCTUnwrap(defaults.data(forKey: "wealthhub.portfolio.v1"))
        let snapshot = try XCTUnwrap(JSONSerialization.jsonObject(with: saved) as? [String: Any])
        XCTAssertEqual(snapshot["seedVersion"] as? Int, 2)
    }

    func testLegacyMigrationDoesNotDuplicatePartiallyAvailableDefaults() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let equity = legacyAccounts()[0]
        try storeLegacySnapshot([equity], in: defaults)
        let migrated = PortfolioStore(defaults: defaults)
        XCTAssertEqual(migrated.accounts.count, 8)
        XCTAssertEqual(migrated.accounts.filter { $0.accountNumber == "068-981234-001" }.count, 1)
        XCTAssertEqual(migrated.accounts.first { $0.accountNumber == "068-981234-001" }?.id, equity.id)
        XCTAssertEqual(PortfolioStore(defaults: defaults).accounts, migrated.accounts)
    }

    func testLegacyEmptyPortfolioRemainsEmptyAfterUpgradeAndNewSave() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        try storeLegacySnapshot([], in: defaults)
        let migrated = PortfolioStore(defaults: defaults)
        XCTAssertTrue(migrated.accounts.isEmpty)
        XCTAssertTrue(PortfolioStore(defaults: defaults).accounts.isEmpty)
        let account = InvestmentAccount(name: "Only my account", institution: "Local", currency: .SGD, colorIndex: 0)
        migrated.save(account)
        XCTAssertEqual(PortfolioStore(defaults: defaults).accounts, [account])
    }

    private func legacyAccounts() -> [InvestmentAccount] {
        let definitions: [(index: Int, name: String, symbols: Set<String>)] = [
            (1, "Equity Investment Account", ["NVDA", "AAPL", "VOO", "USD"]),
            (5, "Hong Kong Investment Account", ["00700", "09988", "HKD"]),
            (3, "Wealth Portfolio", ["SGS", "GIF", "SGD"])
        ]
        return definitions.map { definition in
            var account = DemoData.accounts[definition.index]
            account.id = UUID()
            account.name = definition.name
            account.accountNumber = nil
            account.holdings = account.holdings.filter { definition.symbols.contains($0.symbol) }.map { holding in
                var old = holding
                old.region = nil
                old.sector = nil
                return old
            }
            return account
        }
    }

    private func storeLegacySnapshot(_ accounts: [InvestmentAccount], in defaults: UserDefaults) throws {
        struct LegacySnapshot: Encodable {
            let accounts: [InvestmentAccount]
            let currency: Currency
            let hideAmounts: Bool
        }
        let data = try JSONEncoder().encode(LegacySnapshot(accounts: accounts, currency: .CNY, hideAmounts: true))
        defaults.set(data, forKey: "wealthhub.portfolio.v1")
    }
}
