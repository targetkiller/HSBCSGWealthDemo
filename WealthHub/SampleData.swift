import Foundation

struct SampleConfigurationError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct SampleRecord {
    let values: [String: String]
    let lineNumber: Int
    let source: String
    var id: String { string("id") }
    func string(_ key: String) -> String { values[key] ?? "" }
    // Configuration is validated in full before any model or view reads typed values.
    func double(_ key: String) -> Double { Double(string(key))! }
    func int(_ key: String) -> Int { Int(string(key))! }
    func bool(_ key: String) -> Bool { string(key).lowercased() == "true" }
    func list(_ key: String) -> [String] {
        string(key).split(separator: "|").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
    func error(_ detail: String) -> SampleConfigurationError {
        SampleConfigurationError(message: "\(source), line \(lineNumber): \(detail)")
    }
}

enum SampleCSV {
    /// RFC-style quoting, including escaped quotes, embedded line breaks and UTF-8 BOM.
    static func parse(_ text: String, source: String) throws -> [SampleRecord] {
        var text = text
        if text.first == "\u{FEFF}" { text.removeFirst() }
        let characters = Array(text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n"))
        var rows: [(Int, [String])] = []
        var fields: [String] = [], field = ""
        var quoted = false, closedQuote = false
        var line = 1, startLine = 1, index = 0
        func failure(_ message: String) -> SampleConfigurationError {
            SampleConfigurationError(message: "\(source), line \(line): \(message)")
        }
        func finishRow() {
            fields.append(field)
            if fields.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) { rows.append((startLine, fields)) }
            fields = []; field = ""; closedQuote = false
        }
        while index < characters.count {
            let character = characters[index]
            if quoted {
                if character == "\"" {
                    if index + 1 < characters.count && characters[index + 1] == "\"" { field.append("\""); index += 1 }
                    else { quoted = false; closedQuote = true }
                } else {
                    field.append(character)
                    if character == "\n" { line += 1 }
                }
            } else if character == "," {
                fields.append(field); field = ""; closedQuote = false
            } else if character == "\n" {
                finishRow(); line += 1; startLine = line
            } else if character == "\"" {
                guard field.isEmpty && !closedQuote else { throw failure("Unexpected quote in an unquoted field.") }
                quoted = true
            } else {
                guard !closedQuote else { throw failure("Expected a comma or line break after a closing quote.") }
                field.append(character)
            }
            index += 1
        }
        guard !quoted else { throw failure("Unclosed quoted field (record begins on line \(startLine)).") }
        if !field.isEmpty || !fields.isEmpty || closedQuote { finishRow() }
        guard let headerRow = rows.first else { throw failure("Missing CSV header.") }
        let headers = headerRow.1.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !headers.contains(""), Set(headers).count == headers.count else { throw failure("Header names must be nonempty and unique.") }
        return try rows.dropFirst().map { row in
            guard row.1.count == headers.count else {
                throw SampleConfigurationError(message: "\(source), line \(row.0): Expected \(headers.count) columns, found \(row.1.count).")
            }
            return SampleRecord(values: Dictionary(uniqueKeysWithValues: zip(headers, row.1.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })), lineNumber: row.0, source: source)
        }
    }

    static func encode(_ rows: [[String]]) -> String {
        rows.map { row in
            row.map { value in
                value.contains(where: { ",\"\n\r".contains($0) }) ? "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : value
            }.joined(separator: ",")
        }.joined(separator: "\n") + "\n"
    }
}

struct SampleCatalog {
    private let tables: [String: [SampleRecord]]
    private static let schemas: [String: String] = [
        "accounts": "id,name,institution,currency,colorIndex,note,market,accountNumber,holdingsSet",
        "account_templates": "id,name,institution,currency,colorIndex,note,market,accountNumber,holdingsSet",
        "holdings": "id,setID,name,symbol,category,currency,quantity,price,averageCost,region,sector",
        "currencies": "id,symbol,cnyRate,wealthRegion",
        "settings": "id,value",
        "legacy_accounts": "id,previousName,signatureSymbols",
        "banks": "id,name,portfolioEnabled,accountEnabled",
        "markets": "id,name,shortName,currency",
        "wealth_scenarios": "id,name,description,shockRate,referenceDecline",
        "wealth_scenario_targets": "id,scenarioID,category,currency",
        "wealth_regions": "id,name,color",
        "performance": "id,asOfDate,initialStartDate,initialEndDate,initialMarket,initialPeriod,initialMetric,allMarketsLabel,marketFilters,sampleIntervals,seedModulus,maxYears,portfolioAmplitude,minDuration,primaryFrequency,primarySeedMultiplier,secondaryFrequency,secondarySeedMultiplier,secondaryWeight,portfolioBaseWeight,portfolioAnnualWeight",
        "benchmarks": "id,name,annualReturnPercent,sqrtReturnPercent,amplitude,colorHex,symbol,defaultSelected",
        "analytics": "id,currencyIllustrationShock,concentrationThreshold,defaultScenarioID",
        "asset_profiles": "id,riskScore,liquidityScore,riskLabel,defaultSector",
        "scenarios": "id,title,currencies,assetClasses,regions,shock,skipMatchingReportingCurrency",
        "products": "id,category,title,symbol",
        "assistant_suggestions": "id,prompt",
        "assistant_rules": "id,keywords,response",
        "regions": "id,name,aliases,mapX,mapY"
    ]

    static func load(directory: URL) throws -> SampleCatalog {
        var tables: [String: [SampleRecord]] = [:]
        for (name, schema) in schemas.sorted(by: { $0.key < $1.key }) {
            let url = directory.appendingPathComponent(name + ".csv")
            let text: String
            do { text = try String(contentsOf: url, encoding: .utf8) }
            catch { throw SampleConfigurationError(message: "\(name).csv: Cannot read this UTF-8 configuration table. \(error.localizedDescription)") }
            let records = try SampleCSV.parse(text, source: name + ".csv")
            guard let first = records.first else { throw SampleConfigurationError(message: "\(name).csv: At least one data row is required.") }
            let expected = Set(schema.components(separatedBy: ","))
            guard Set(first.values.keys) == expected else { throw first.error("Expected columns: \(schema).") }
            var ids = Set<String>()
            for record in records {
                guard !record.id.isEmpty, ids.insert(record.id).inserted else { throw record.error("Missing or duplicate id '\(record.id)'.") }
            }
            tables[name] = records
        }
        let catalog = SampleCatalog(tables: tables)
        try catalog.validate()
        return catalog
    }

    func rows(_ table: String) -> [SampleRecord] { tables[table]! }
    func row(_ table: String, id: String) -> SampleRecord { rows(table).first { $0.id == id }! }
    func setting(_ key: String) -> String { row("settings", id: key).string("value") }

    var accounts: [InvestmentAccount] { rows("accounts").map { account(from: $0, id: UUID(uuidString: $0.id)!, freshHoldings: false) } }
    func makeAccount(template: String) -> InvestmentAccount { account(from: row("account_templates", id: template), id: UUID(), freshHoldings: true) }
    func holdings(in setID: String) -> [Holding] { holdings(in: setID, freshIDs: true) }

    private func account(from row: SampleRecord, id: UUID, freshHoldings: Bool) -> InvestmentAccount {
        InvestmentAccount(id: id, name: row.string("name"), institution: row.string("institution"), currency: Currency(rawValue: row.string("currency"))!, colorIndex: row.int("colorIndex"), note: row.string("note"), market: row.string("market"), holdings: holdings(in: row.string("holdingsSet"), freshIDs: freshHoldings), accountNumber: row.string("accountNumber").nilIfEmpty)
    }
    private func holdings(in setID: String, freshIDs: Bool) -> [Holding] {
        rows("holdings").filter { $0.string("setID") == setID }.map { row in
            Holding(id: freshIDs ? UUID() : UUID(uuidString: row.id)!, name: row.string("name"), symbol: row.string("symbol"), category: AssetClass(rawValue: row.string("category"))!, currency: Currency(rawValue: row.string("currency"))!, quantity: row.double("quantity"), price: row.double("price"), averageCost: row.double("averageCost"), region: row.string("region").nilIfEmpty, sector: row.string("sector").nilIfEmpty)
        }
    }

    var statementCSV: String { statementCSV(in: "csv-import") }
    func statementCSV(in setID: String) -> String {
        SampleCSV.encode([["name", "symbol", "category", "currency", "quantity", "price", "averageCost"]] + rows("holdings").filter { $0.string("setID") == setID }.map { row in
            ["name", "symbol", "category", "currency", "quantity", "price", "averageCost"].map(row.string)
        })
    }

    private func validate() throws {
        func require(_ condition: Bool, _ row: SampleRecord, _ message: String) throws { if !condition { throw row.error(message) } }
        func nonempty(_ row: SampleRecord, _ keys: String...) throws {
            for key in keys { try require(!row.string(key).isEmpty, row, "\(key) must not be empty.") }
        }
        func number(_ row: SampleRecord, _ key: String, min: Double = -Double.greatestFiniteMagnitude, max: Double = Double.greatestFiniteMagnitude) throws {
            guard let value = Double(row.string(key)), value.isFinite, value >= min, value <= max else { throw row.error("\(key) must be a finite number between \(min) and \(max).") }
        }
        func integer(_ row: SampleRecord, _ key: String, min: Int = 0, max: Int = Int.max) throws {
            guard let value = Int(row.string(key)), value >= min, value <= max else { throw row.error("\(key) must be an integer between \(min) and \(max).") }
        }
        func boolean(_ row: SampleRecord, _ key: String) throws { try require(["true", "false"].contains(row.string(key).lowercased()), row, "\(key) must be true or false.") }
        func reference(_ row: SampleRecord, _ key: String, _ allowed: Set<String>, optional: Bool = false) throws {
            try require((optional && row.string(key).isEmpty) || allowed.contains(row.string(key)), row, "Unknown \(key) '\(row.string(key))'. Valid values: \(allowed.sorted().joined(separator: ", ")).")
        }
        func ids(_ table: String) -> Set<String> { Set(rows(table).map(\.id)) }
        func unique(_ table: String, _ key: String) throws {
            var seen = Set<String>()
            for row in rows(table) { try require(seen.insert(row.string(key)).inserted, row, "Duplicate \(key) '\(row.string(key))'.") }
        }
        let currencies = Set(Currency.allCases.map(\.rawValue)), categories = Set(AssetClass.allCases.map(\.rawValue))
        let marketNames = Set(rows("markets").map { $0.string("name") })
        let regionNames = Set(rows("regions").map { $0.string("name") })
        let sets = Set(rows("holdings").map { $0.string("setID") })
        try require(ids("currencies") == currencies, rows("currencies")[0], "Include exactly one row for each currency: \(currencies.sorted().joined(separator: ", ")).")
        for row in rows("currencies") {
            try number(row, "cnyRate", min: Double.leastNormalMagnitude)
            try nonempty(row, "symbol", "wealthRegion")
            try reference(row, "wealthRegion", Set(rows("wealth_regions").map { $0.string("name") }))
        }
        for table in ["accounts", "account_templates"] {
            var accountIDs = Set<UUID>()
            for row in rows(table) {
                if table == "accounts" {
                    guard let id = UUID(uuidString: row.id), accountIDs.insert(id).inserted else { throw row.error("id must be a unique UUID.") }
                }
                try nonempty(row, "name", "institution", "market")
                try reference(row, "currency", currencies)
                try reference(row, "market", marketNames)
                try reference(row, "holdingsSet", sets, optional: true)
                try integer(row, "colorIndex")
            }
        }
        var holdingIDs = Set<UUID>()
        for row in rows("holdings") {
            guard let id = UUID(uuidString: row.id), holdingIDs.insert(id).inserted else { throw row.error("id must be a unique UUID.") }
            try nonempty(row, "setID", "name", "symbol")
            try reference(row, "currency", currencies); try reference(row, "category", categories)
            for key in ["quantity", "price", "averageCost"] { try number(row, key, min: 0) }
            try require((row.double("quantity") * row.double("price")).isFinite && (row.double("quantity") * row.double("averageCost")).isFinite, row, "Holding value or cost overflows.")
            if ["csv-import", "csv-file-export"].contains(row.string("setID")) {
                try require(row.double("quantity") > 0 && row.double("quantity") * max(row.double("price"), row.double("averageCost")) < 1e14, row, "CSV statement sets require positive quantity and value/cost below 100 trillion, matching the statement importer.")
            }
        }
        for setID in ["csv-import", "csv-file-export"] {
            try require(rows("holdings").filter { $0.string("setID") == setID }.count <= 1000, rows("holdings")[0], "\(setID) supports up to 1,000 holdings.")
        }
        // Check the same multiply-then-divide conversion used by the models before any UI
        // turns allocation percentages into integers. Finite inputs can still overflow.
        for target in rows("currencies") {
            var totalValue = 0.0, totalCost = 0.0
            for holding in rows("holdings") {
                let source = row("currencies", id: holding.string("currency"))
                let quantity = holding.double("quantity")
                let value = quantity * holding.double("price") * source.double("cnyRate") / target.double("cnyRate")
                let cost = quantity * holding.double("averageCost") * source.double("cnyRate") / target.double("cnyRate")
                totalValue += value; totalCost += cost
                try require(value.isFinite && cost.isFinite && totalValue < 1e14 && totalCost < 1e14, source, "Rates and holdings must produce finite values and totals below 100 trillion in every reporting currency; check holding '\(holding.string("symbol"))' and rate \(target.id).")
            }
        }
        for required in ["bank-connection", "linked-account", "statement-review", "statement-import"] {
            try require(ids("account_templates").contains(required), rows("account_templates")[0], "Required template '\(required)' is missing.")
        }
        for required in ["statement-preview", "csv-import", "csv-file-export"] { try require(sets.contains(required), rows("holdings")[0], "Required holding set '\(required)' is missing.") }
        for row in rows("legacy_accounts") { try reference(row, "id", ids("accounts")); try nonempty(row, "previousName", "signatureSymbols") }
        for row in rows("banks") { try nonempty(row, "name"); try boolean(row, "portfolioEnabled"); try boolean(row, "accountEnabled") }
        for row in rows("markets") { try nonempty(row, "name", "shortName"); try reference(row, "currency", currencies) }
        try unique("markets", "name"); try unique("banks", "name"); try unique("regions", "name"); try unique("wealth_regions", "name")
        for row in rows("wealth_regions") { try nonempty(row, "name"); try integer(row, "color", max: Int(UInt32.max)) }
        for row in rows("wealth_scenarios") { try nonempty(row, "name", "description"); try number(row, "shockRate", min: 0, max: 1); try number(row, "referenceDecline", min: 0) }
        for row in rows("wealth_scenario_targets") {
            try reference(row, "scenarioID", ids("wealth_scenarios")); try reference(row, "category", categories, optional: true); try reference(row, "currency", currencies, optional: true)
            try require(!row.string("category").isEmpty || !row.string("currency").isEmpty, row, "Specify category or currency.")
        }
        for row in rows("wealth_scenarios") { try require(rows("wealth_scenario_targets").contains { $0.string("scenarioID") == row.id }, row, "At least one target is required.") }
        let requiredSettings = ["defaultCurrency", "defaultAccountID", "defaultBankID", "defaultMarketID", "defaultWealthScenarioID", "wealthReferenceAssumptions", "statementPreviewSource", "statementCSVFilename", "defaultManualAccountName"]
        for key in requiredSettings {
            guard let row = rows("settings").first(where: { $0.id == key }) else { throw SampleConfigurationError(message: "settings.csv: Missing setting '\(key)'.") }
            try nonempty(row, "value")
        }
        for (key, allowed) in [("defaultCurrency", currencies), ("defaultAccountID", ids("accounts")), ("defaultBankID", ids("banks")), ("defaultMarketID", ids("markets")), ("defaultWealthScenarioID", ids("wealth_scenarios"))] {
            try reference(row("settings", id: key), "value", allowed)
        }
        let bank = row("banks", id: setting("defaultBankID"))
        try require(bank.bool("portfolioEnabled") && bank.bool("accountEnabled"), bank, "The default bank must be enabled for both entry points.")
        for table in ["performance", "analytics"] { try require(rows(table).count == 1 && rows(table)[0].id == "default", rows(table)[0], "Exactly one row with id 'default' is required.") }
        let performance = row("performance", id: "default")
        for key in ["sampleIntervals", "seedModulus"] { try integer(performance, key, min: 1, max: 10000) }
        for key in ["maxYears", "portfolioAmplitude", "minDuration", "primaryFrequency", "primarySeedMultiplier", "secondaryFrequency", "secondarySeedMultiplier", "secondaryWeight", "portfolioBaseWeight", "portfolioAnnualWeight"] { try number(performance, key, min: 0) }
        try require(performance.double("maxYears") > 0 && performance.double("minDuration") > 0, performance, "maxYears and minDuration must be positive.")
        try number(performance, "maxYears", min: Double.leastNormalMagnitude, max: 100)
        let dateFormatter = DateFormatter(); dateFormatter.locale = Locale(identifier: "en_US_POSIX"); dateFormatter.timeZone = TimeZone(secondsFromGMT: 0); dateFormatter.dateFormat = "yyyy-MM-dd"; dateFormatter.isLenient = false
        var dates: [String: Date] = [:]
        for key in ["asOfDate", "initialStartDate", "initialEndDate"] {
            guard let date = dateFormatter.date(from: performance.string(key)), dateFormatter.string(from: date) == performance.string(key) else { throw performance.error("\(key) must be a valid yyyy-MM-dd date.") }
            dates[key] = date
        }
        try require(dates["initialStartDate"]! <= dates["initialEndDate"]! && dates["initialEndDate"]! <= dates["asOfDate"]!, performance, "Expected initialStartDate ≤ initialEndDate ≤ asOfDate.")
        try reference(performance, "initialPeriod", ["month", "year", "custom"]); try reference(performance, "initialMetric", ["TWRR", "MWRR"])
        let filters = Set(performance.list("marketFilters"))
        try require(filters.count == performance.list("marketFilters").count, performance, "marketFilters must not contain duplicate names.")
        try reference(performance, "initialMarket", filters); try reference(performance, "allMarketsLabel", filters)
        try require(filters.subtracting([performance.string("allMarketsLabel")]).isSubset(of: marketNames.union(regionNames)), performance, "marketFilters must use configured market or region names.")
        for row in rows("benchmarks") {
            try nonempty(row, "name", "symbol"); try require(row.string("name") != "My total return", row, "My total return is reserved for the portfolio series.")
            for key in ["annualReturnPercent", "sqrtReturnPercent", "amplitude"] { try number(row, key) }
            try require(row.string("colorHex").count == 6 && UInt32(row.string("colorHex"), radix: 16) != nil, row, "colorHex must contain six hexadecimal digits.")
            try boolean(row, "defaultSelected")
        }
        try unique("benchmarks", "name")
        let analytics = row("analytics", id: "default")
        try number(analytics, "currencyIllustrationShock", min: -1, max: 1); try number(analytics, "concentrationThreshold", min: 0, max: 1); try reference(analytics, "defaultScenarioID", ids("scenarios"))
        try require(ids("asset_profiles") == categories, rows("asset_profiles")[0], "Include exactly one profile for every asset class.")
        for row in rows("asset_profiles") { try number(row, "riskScore", min: 0, max: 10); try number(row, "liquidityScore", min: 0, max: 10); try nonempty(row, "riskLabel", "defaultSector") }
        for row in rows("scenarios") {
            try nonempty(row, "title"); try number(row, "shock", min: -1); try boolean(row, "skipMatchingReportingCurrency")
            try require(!row.list("currencies").isEmpty || !row.list("assetClasses").isEmpty || !row.list("regions").isEmpty, row, "At least one scenario matching rule is required.")
            for (key, allowed) in [("currencies", currencies), ("assetClasses", categories), ("regions", regionNames.union(marketNames))] { try require(Set(row.list(key)).isSubset(of: allowed), row, "Unknown value in \(key).") }
        }
        for row in rows("regions") { try nonempty(row, "name"); try number(row, "mapX", min: 0, max: 1); try number(row, "mapY", min: 0, max: 1) }
        for row in rows("products") { try nonempty(row, "title", "symbol"); try reference(row, "category", ["Products", "Services"]) }
        for row in rows("assistant_suggestions") { try nonempty(row, "prompt") }
        for (index, row) in rows("assistant_rules").enumerated() {
            try nonempty(row, "response")
            try require(row.list("keywords").isEmpty == (index == rows("assistant_rules").count - 1), row, "Only the last assistant rule must have empty keywords (fallback).")
            var response = row.string("response")
            for key in ["allocationName", "allocationPercent", "holdingCount", "accountCount", "totalAmount"] {
                response = response.replacingOccurrences(of: "{\(key)}", with: "")
            }
            try require(!response.contains("{") && !response.contains("}"), row, "Unknown response placeholder. Use allocationName, allocationPercent, holdingCount, accountCount or totalAmount inside braces.")
        }
    }
}

enum SampleData {
    static let directory = Bundle.main.resourceURL!.appendingPathComponent("Sample", isDirectory: true)
    static let result = Result { try SampleCatalog.load(directory: directory) }
    static var configurationError: String? {
        if case .failure(let error) = result { return error.localizedDescription }
        return nil
    }
    private static var catalog: SampleCatalog {
        switch result {
        case .success(let catalog): return catalog
        case .failure(let error): preconditionFailure("Invalid Sample configuration: \(error.localizedDescription)")
        }
    }
    static var accounts: [InvestmentAccount] { catalog.accounts }
    static func defaultAccount(in savedAccounts: [InvestmentAccount]) -> InvestmentAccount? {
        let configured = accounts.first { $0.id.uuidString.caseInsensitiveCompare(setting("defaultAccountID")) == .orderedSame }!
        // Earlier app versions used random IDs; their migration preserves those IDs and user edits.
        return savedAccounts.first { $0.id == configured.id }
            ?? savedAccounts.first {
                $0.institution.caseInsensitiveCompare(configured.institution) == .orderedSame && $0.market == configured.market &&
                (($0.accountNumber != nil && $0.accountNumber == configured.accountNumber) || $0.name == configured.name)
            }
            ?? savedAccounts.first
    }
    static func rows(_ table: String) -> [SampleRecord] { catalog.rows(table) }
    static func row(_ table: String, id: String) -> SampleRecord { catalog.row(table, id: id) }
    static func setting(_ key: String) -> String { catalog.setting(key) }
    static func number(_ key: String) -> Double { Double(setting(key))! }
    static func makeAccount(template: String) -> InvestmentAccount { catalog.makeAccount(template: template) }
    static func holdings(in setID: String) -> [Holding] { catalog.holdings(in: setID) }
    static var statementCSV: String { catalog.statementCSV }
}

private extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }
