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
        let catalog = try SampleCatalog.load(directory: SampleData.directory)
        let exported = try StatementParser.parse(catalog.statementCSV(in: "csv-file-export"))
        XCTAssertEqual(exported.map(\.symbol), ["AAPL", "VOO", "SGS", "SGD"])
        let header = "name,symbol,category,currency,quantity,price,averageCost\n"
        XCTAssertThrowsError(try StatementParser.parse(header + "Bad,X,Stocks,USD,-1,2,1"))
        XCTAssertThrowsError(try StatementParser.parse(header + "Bad,X,Stocks,USD,1,nan,1"))
        XCTAssertThrowsError(try StatementParser.parse(header + "Bad,X,Stocks,INVALID,1,2,1"))
        XCTAssertThrowsError(try StatementParser.parse(header + "Cash,SGD,Cash and FX,SGD,10,1,1\nBad,X,Stocks,USD,1,2"))
    }

    func testDefaultAccountsCoverBothMarketsAndAllAssetClasses() {
        let accounts = SampleData.accounts
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

        let seedToRemove = SampleData.accounts[0].id
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

    func testSampleCSVSupportsSpreadsheetQuotingAndLineEndings() throws {
        let csv = "\u{FEFF}id,name,note,tags\r\nfirst,\"Global, income\",\"A \"\"quoted\"\" note\r\ncontinued\", USD | HKD \r\nsecond,Cash,,\r\n"
        let rows = try SampleCSV.parse(csv, source: "quoted.csv")
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].id, "first")
        XCTAssertEqual(rows[0].lineNumber, 2)
        XCTAssertEqual(rows[0].string("name"), "Global, income")
        XCTAssertEqual(rows[0].string("note").replacingOccurrences(of: "\r\n", with: "\n"), "A \"quoted\" note\ncontinued")
        XCTAssertEqual(rows[0].list("tags"), ["USD", "HKD"])
        XCTAssertEqual(rows[1].string("note"), "")
        XCTAssertTrue(rows[1].list("tags").isEmpty)
    }

    func testSampleCSVRejectsMalformedSpreadsheetRows() {
        let invalidCSVs = [
            "id,name,name\nfirst,A,B\n",
            "id,,name\nfirst,A,B\n",
            "id,name\nfirst\n",
            "id,name\nfirst,A,extra\n",
            "id,name\nfirst,\"unfinished\n",
            "id,name\nfirst,\"A\"unexpected\n"
        ]
        for csv in invalidCSVs {
            XCTAssertThrowsError(try SampleCSV.parse(csv, source: "broken.csv")) { error in
                XCTAssertTrue(error.localizedDescription.contains("broken.csv"), error.localizedDescription)
            }
        }
    }

    func testSampleCatalogKeepsSeedIdentifiersStableAndClonesTemplateIdentifiers() throws {
        let first = try SampleCatalog.load(directory: SampleData.directory)
        let second = try SampleCatalog.load(directory: SampleData.directory)
        XCTAssertEqual(first.accounts, second.accounts)
        let seedHoldingIDs = Set(first.accounts.flatMap(\.holdings).map(\.id))
        XCTAssertEqual(seedHoldingIDs.count, first.accounts.flatMap(\.holdings).count)

        let accountA = first.makeAccount(template: "linked-account")
        let accountB = first.makeAccount(template: "linked-account")
        XCTAssertFalse(accountA.holdings.isEmpty)
        XCTAssertNotEqual(accountA.id, accountB.id)
        XCTAssertEqual(accountA.holdings.map(\.symbol), accountB.holdings.map(\.symbol))
        XCTAssertTrue(Set(accountA.holdings.map(\.id)).isDisjoint(with: accountB.holdings.map(\.id)))
        XCTAssertTrue(seedHoldingIDs.isDisjoint(with: accountA.holdings.map(\.id)))
        XCTAssertEqual(Set(accountA.holdings.map(\.id)).count, accountA.holdings.count)
    }

    func testEditingCSVChangesAccountAndHoldingWithoutChangingSwift() throws {
        try withSampleDirectory { directory in
            let original = try SampleCatalog.load(directory: directory)
            let originalAccount = try XCTUnwrap(original.accounts.first)
            let originalHolding = try XCTUnwrap(originalAccount.holdings.first)
            let configuredQuantity = originalHolding.quantity + 123
            try rewriteTable("accounts", in: directory) { rows in
                let index = try XCTUnwrap(rows.firstIndex { $0["id"] == originalAccount.id.uuidString })
                rows[index]["name"] = "My configurable, \"portfolio\""
            }
            try rewriteTable("holdings", in: directory) { rows in
                let index = try XCTUnwrap(rows.firstIndex { $0["id"] == originalHolding.id.uuidString })
                rows[index]["quantity"] = String(configuredQuantity)
            }
            let configured = try SampleCatalog.load(directory: directory)
            let account = try XCTUnwrap(configured.accounts.first { $0.id == originalAccount.id })
            let holding = try XCTUnwrap(account.holdings.first { $0.id == originalHolding.id })
            XCTAssertEqual(account.name, "My configurable, \"portfolio\"")
            XCTAssertEqual(holding.quantity, configuredQuantity)
            XCTAssertEqual(holding.value, configuredQuantity * originalHolding.price, accuracy: 0.001)
        }
    }

    func testReorderingAccountsKeepsNamedTemplateHoldings() throws {
        try withSampleDirectory { directory in
            let original = try SampleCatalog.load(directory: directory)
            let template = original.makeAccount(template: "linked-account")
            try rewriteTable("accounts", in: directory) { $0.reverse() }
            let reordered = try SampleCatalog.load(directory: directory)
            XCTAssertEqual(reordered.accounts.map(\.id), original.accounts.reversed().map(\.id))
            let linkedAccount = reordered.makeAccount(template: "linked-account")
            XCTAssertEqual(linkedAccount.holdings.map(\.symbol), template.holdings.map(\.symbol))
            XCTAssertEqual(linkedAccount.holdings.map(\.quantity), template.holdings.map(\.quantity))
        }
    }

    func testDefaultAccountSelectionRecognizesMigratedIdentityBeforeFallingBack() throws {
        let configuredID = SampleData.setting("defaultAccountID")
        let configured = try XCTUnwrap(SampleData.accounts.first { $0.id.uuidString == configuredID })
        let firstCurrentAccount = try XCTUnwrap(SampleData.accounts.first { $0.id != configured.id })
        XCTAssertNotNil(configured.accountNumber)
        var migrated = configured
        migrated.id = UUID()
        migrated.name = "My renamed investment portfolio"

        XCTAssertEqual(SampleData.defaultAccount(in: [firstCurrentAccount, migrated])?.id, migrated.id,
                       "A migrated account keeps its saved UUID and edited name; its account number should still select the configured default.")
        XCTAssertEqual(SampleData.defaultAccount(in: [migrated, firstCurrentAccount, configured])?.id, configured.id,
                       "An exact configured ID must take priority over a matching migrated account.")
        XCTAssertNil(SampleData.defaultAccount(in: []))
        XCTAssertEqual(SampleData.defaultAccount(in: [firstCurrentAccount])?.id, firstCurrentAccount.id)
    }

    func testCatalogRejectsBrokenReferencesDuplicateIDsAndInvalidValues() throws {
        let cases: [(table: String, change: (inout [[String: String]]) -> Void)] = [
            ("accounts", { $0[1]["id"] = $0[0]["id"] }),
            ("accounts", { $0[0]["holdingsSet"] = "missing-holdings-set" }),
            ("holdings", { $0[0]["currency"] = "INVALID" }),
            ("holdings", { $0[0]["quantity"] = "nan" }),
            ("currencies", { $0[0]["cnyRate"] = "0" }),
            ("currencies", { $0[0]["cnyRate"] = "1e308" }),
            ("performance", { $0[0]["marketFilters"] = $0[0]["marketFilters"]! + "|" + $0[0]["allMarketsLabel"]! }),
            ("assistant_rules", { $0[0]["response"] = "Unknown {unsupportedValue}" }),
            ("holdings", { rows in
                for index in rows.indices where rows[index]["setID"] == "csv-import" {
                    rows[index]["quantity"] = "0"
                }
            })
        ]
        for testCase in cases {
            try withSampleDirectory { directory in
                try rewriteTable(testCase.table, in: directory, update: testCase.change)
                XCTAssertThrowsError(try SampleCatalog.load(directory: directory)) { error in
                    XCTAssertTrue(error.localizedDescription.contains(testCase.table + ".csv"), error.localizedDescription)
                }
            }
        }
    }

    func testConfiguredDefaultsDoNotReplaceSavedEditsUntilReset() throws {
        let suiteName = "wealthhub.sample-tests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = PortfolioStore(defaults: defaults)
        var edited = try XCTUnwrap(store.accounts.first)
        edited.name = "My saved portfolio"
        edited.holdings.removeAll()
        store.save(edited)
        for account in store.accounts where account.id != edited.id {
            store.deleteAccount(id: account.id)
        }
        store.currency = .USD
        store.hideAmounts = true

        let reopened = PortfolioStore(defaults: defaults)
        XCTAssertEqual(reopened.accounts, [edited])
        XCTAssertEqual(reopened.currency, .USD)
        XCTAssertTrue(reopened.hideAmounts)
        reopened.reset()
        XCTAssertEqual(reopened.accounts, SampleData.accounts)
        XCTAssertEqual(reopened.currency.rawValue, SampleData.setting("defaultCurrency"))
        XCTAssertFalse(reopened.hideAmounts)
        XCTAssertEqual(PortfolioStore(defaults: defaults).accounts, SampleData.accounts)
    }

    private func withSampleDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("wealthhub-sample-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.copyItem(at: SampleData.directory, to: directory)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }

    private func rewriteTable(_ name: String, in directory: URL, update: (inout [[String: String]]) throws -> Void) throws {
        let url = directory.appendingPathComponent(name + ".csv")
        let text = try String(contentsOf: url, encoding: .utf8)
        let header = try XCTUnwrap(text.split(whereSeparator: \.isNewline).first)
        let columns = header.split(separator: ",").map(String.init)
        var rows = try SampleCSV.parse(text, source: name + ".csv").map(\.values)
        try update(&rows)
        func quote(_ value: String) -> String {
            "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        let result = [String(header)] + rows.map { row in columns.map { quote(row[$0] ?? "") }.joined(separator: ",") }
        try (result.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private func legacyAccounts() -> [InvestmentAccount] {
        let definitions: [(index: Int, name: String, symbols: Set<String>)] = [
            (1, "Equity Investment Account", ["NVDA", "AAPL", "VOO", "USD"]),
            (5, "Hong Kong Investment Account", ["00700", "09988", "HKD"]),
            (3, "Wealth Portfolio", ["SGS", "GIF", "SGD"])
        ]
        return definitions.map { definition in
            var account = SampleData.accounts[definition.index]
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
