import Foundation

enum Currency: String, Codable, CaseIterable, Identifiable {
    case SGD, CNY, USD, HKD
    var id: String { rawValue }
    var symbol: String { switch self { case .SGD: "S$"; case .CNY: "¥"; case .USD: "$"; case .HKD: "HK$" } }
    // Fixed demo rates, quoted as CNY per unit; never live market data.
    var cnyRate: Double { switch self { case .SGD: 5.4; case .CNY: 1; case .USD: 7.2; case .HKD: 0.92 } }
    func convert(_ value: Double, to target: Currency) -> Double { value * cnyRate / target.cnyRate }
    func format(_ value: Double, compact: Bool = false) -> String {
        let number: String
        if compact && abs(value) >= 1_000_000 { number = String(format: "%.2fM", value / 1_000_000) }
        else if compact && abs(value) >= 1_000 { number = String(format: "%.1fK", value / 1_000) }
        else { number = value.formatted(.number.locale(Locale(identifier: "en_SG")).precision(.fractionLength(2))) }
        return "\(number) \(rawValue)"
    }
}

enum AssetClass: String, Codable, CaseIterable, Identifiable {
    case stock = "Stocks", fund = "Unit trusts", bond = "Bonds", cash = "Cash and FX", other = "Structured products", insurance = "Insurance", option = "Options"
    var id: String { rawValue }
    var icon: String {
        switch self { case .stock: "chart.line.uptrend.xyaxis"; case .fund: "chart.pie.fill"; case .bond: "doc.text.fill"; case .cash: "banknote.fill"; case .other: "square.stack.3d.up.fill"; case .insurance: "shield.lefthalf.filled"; case .option: "arrow.up.arrow.down.square.fill" }
    }
}

struct Holding: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var symbol: String
    var category: AssetClass
    var currency: Currency
    var quantity: Double
    var price: Double
    var averageCost: Double
    var region: String? = nil
    var sector: String? = nil
    var value: Double { quantity * price }
    var cost: Double { quantity * averageCost }
    var profit: Double { value - cost }
    var returnRate: Double? { cost > 0 ? profit / cost * 100 : nil }
}

struct InvestmentAccount: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var institution: String
    var currency: Currency
    var colorIndex: Int
    var note = ""
    var market = "Singapore"
    var holdings: [Holding] = []
    var accountNumber: String? = nil
    func value(in currency: Currency) -> Double { holdings.reduce(0) { $0 + $1.currency.convert($1.value, to: currency) } }
    func cost(in currency: Currency) -> Double { holdings.reduce(0) { $0 + $1.currency.convert($1.cost, to: currency) } }
    func profit(in currency: Currency) -> Double { value(in: currency) - cost(in: currency) }
    var returnRate: Double? {
        let cost = cost(in: .CNY)
        return cost > 0 ? profit(in: .CNY) / cost * 100 : nil
    }
}

enum DemoData {
    // Stable template identifiers make the one-time seed migration idempotent.
    static let accounts: [InvestmentAccount] = [
        .init(id: UUID(uuidString: "10000000-0000-4000-8000-000000000001")!, name: "HSBC Current Account", institution: "HSBC", currency: .SGD, colorIndex: 0, note: "Everyday banking and multi-currency balances", holdings: [
            .init(name: "Singapore dollar balance", symbol: "SGD", category: .cash, currency: .SGD, quantity: 62800, price: 1, averageCost: 1, region: "Singapore", sector: "Cash"),
            .init(name: "US dollar balance", symbol: "USD", category: .cash, currency: .USD, quantity: 14800, price: 1, averageCost: 1, region: "United States", sector: "Cash"),
            .init(name: "Hong Kong dollar balance", symbol: "HKD", category: .cash, currency: .HKD, quantity: 42500, price: 1, averageCost: 1, region: "Hong Kong", sector: "Cash"),
            .init(name: "Renminbi balance", symbol: "CNY", category: .cash, currency: .CNY, quantity: 38600, price: 1, averageCost: 1, region: "Mainland China", sector: "Cash")
        ], accountNumber: "001-223344-001"),
        .init(id: UUID(uuidString: "10000000-0000-4000-8000-000000000002")!, name: "(068) Equity Investment Account", institution: "HSBC", currency: .USD, colorIndex: 1, note: "Global equities and exchange-traded funds", holdings: [
            .init(name: "NVIDIA", symbol: "NVDA", category: .stock, currency: .USD, quantity: 180, price: 128.5, averageCost: 104, region: "United States", sector: "Technology"),
            .init(name: "Apple", symbol: "AAPL", category: .stock, currency: .USD, quantity: 120, price: 226.8, averageCost: 205, region: "United States", sector: "Technology"),
            .init(name: "Vanguard S&P 500 ETF", symbol: "VOO", category: .fund, currency: .USD, quantity: 80, price: 518.2, averageCost: 476, region: "United States", sector: "Multi-sector"),
            .init(name: "DBS Group", symbol: "D05", category: .stock, currency: .SGD, quantity: 500, price: 43.2, averageCost: 38.6, region: "Singapore", sector: "Financials"),
            .init(name: "Singapore Airlines", symbol: "C6L", category: .stock, currency: .SGD, quantity: 2400, price: 6.48, averageCost: 6.75, region: "Singapore", sector: "Industrials"),
            .init(name: "US dollar balance", symbol: "USD", category: .cash, currency: .USD, quantity: 8250, price: 1, averageCost: 1, region: "United States", sector: "Cash")
        ], accountNumber: "068-981234-001"),
        .init(id: UUID(uuidString: "10000000-0000-4000-8000-000000000003")!, name: "(085) Unit Trust Investment Account", institution: "HSBC", currency: .SGD, colorIndex: 2, note: "Diversified funds across regions and investment styles", holdings: [
            .init(name: "Global Income Fund", symbol: "GIF-SG", category: .fund, currency: .SGD, quantity: 26000, price: 1.32, averageCost: 1.18, region: "Global", sector: "Fixed income"),
            .init(name: "Asia Growth Fund", symbol: "AGF", category: .fund, currency: .USD, quantity: 2800, price: 17.85, averageCost: 16.5, region: "Mainland China", sector: "Multi-sector"),
            .init(name: "European Equity Fund", symbol: "EEF", category: .fund, currency: .USD, quantity: 1600, price: 25.8, averageCost: 23.1, region: "Europe", sector: "Multi-sector"),
            .init(name: "Global Healthcare Fund", symbol: "GHCF", category: .fund, currency: .USD, quantity: 1300, price: 19.7, averageCost: 21.4, region: "United States", sector: "Healthcare"),
            .init(name: "Japan Opportunities Fund", symbol: "JOF", category: .fund, currency: .SGD, quantity: 3800, price: 8.62, averageCost: 7.9, region: "Japan", sector: "Multi-sector")
        ], accountNumber: "085-981234-001"),
        .init(id: UUID(uuidString: "10000000-0000-4000-8000-000000000004")!, name: "DBS Account", institution: "DBS", currency: .SGD, colorIndex: 3, note: "Income, protection and capital preservation", holdings: [
            .init(name: "Singapore Government Bond", symbol: "SGS", category: .bond, currency: .SGD, quantity: 85000, price: 1.058, averageCost: 1, region: "Singapore", sector: "Government"),
            .init(name: "Global Income Fund", symbol: "GIF", category: .fund, currency: .SGD, quantity: 42000, price: 1.25, averageCost: 1.18, region: "Global", sector: "Fixed income"),
            .init(name: "Singapore dollar balance", symbol: "SGD", category: .cash, currency: .SGD, quantity: 46000, price: 1, averageCost: 1, region: "Singapore", sector: "Cash"),
            .init(name: "Singapore REIT Fund", symbol: "SG-REIT", category: .fund, currency: .SGD, quantity: 12500, price: 1.61, averageCost: 1.72, region: "Singapore", sector: "Real estate"),
            .init(name: "Life protection policy", symbol: "SG-LIFE", category: .insurance, currency: .SGD, quantity: 1, price: 38500, averageCost: 35000, region: "Singapore", sector: "Insurance")
        ], accountNumber: "029-001234-5"),
        .init(id: UUID(uuidString: "10000000-0000-4000-8000-000000000005")!, name: "HSBC Current Account", institution: "HSBC", currency: .HKD, colorIndex: 0, note: "Hong Kong everyday banking and foreign-currency balances", market: "Hong Kong", holdings: [
            .init(name: "Hong Kong dollar balance", symbol: "HKD", category: .cash, currency: .HKD, quantity: 218500, price: 1, averageCost: 1, region: "Hong Kong", sector: "Cash"),
            .init(name: "US dollar balance", symbol: "USD", category: .cash, currency: .USD, quantity: 22600, price: 1, averageCost: 1, region: "United States", sector: "Cash"),
            .init(name: "Renminbi balance", symbol: "CNY", category: .cash, currency: .CNY, quantity: 78000, price: 1, averageCost: 1, region: "Mainland China", sector: "Cash")
        ], accountNumber: "004-987654-001"),
        .init(id: UUID(uuidString: "10000000-0000-4000-8000-000000000006")!, name: "HSBC One Investment Services", institution: "HSBC", currency: .HKD, colorIndex: 1, note: "Hong Kong equities, global trading and listed options", market: "Hong Kong", holdings: [
            .init(name: "Tencent", symbol: "00700", category: .stock, currency: .HKD, quantity: 600, price: 428.6, averageCost: 380, region: "Mainland China", sector: "Technology"),
            .init(name: "Alibaba", symbol: "09988", category: .stock, currency: .HKD, quantity: 1000, price: 98.5, averageCost: 105, region: "Mainland China", sector: "Consumer discretionary"),
            .init(name: "HSBC Holdings", symbol: "00005", category: .stock, currency: .HKD, quantity: 1200, price: 92.4, averageCost: 78.6, region: "Hong Kong", sector: "Financials"),
            .init(name: "Meituan", symbol: "03690", category: .stock, currency: .HKD, quantity: 400, price: 137.2, averageCost: 153.4, region: "Mainland China", sector: "Consumer discretionary"),
            .init(name: "NVIDIA December call option", symbol: "NVDA-DEC-C150", category: .option, currency: .USD, quantity: 100, price: 9.45, averageCost: 8.2, region: "United States", sector: "Technology"),
            .init(name: "Hong Kong dollar balance", symbol: "HKD", category: .cash, currency: .HKD, quantity: 48000, price: 1, averageCost: 1, region: "Hong Kong", sector: "Cash")
        ], accountNumber: "004-987654-068"),
        .init(id: UUID(uuidString: "10000000-0000-4000-8000-000000000007")!, name: "HSBC One FundMax Account", institution: "HSBC", currency: .HKD, colorIndex: 2, note: "Fund portfolio with regional and thematic exposure", market: "Hong Kong", holdings: [
            .init(name: "China Technology Fund", symbol: "CN-TECH", category: .fund, currency: .HKD, quantity: 12500, price: 11.28, averageCost: 10.6, region: "Mainland China", sector: "Technology"),
            .init(name: "Global Balanced Fund", symbol: "GBF", category: .fund, currency: .USD, quantity: 2200, price: 31.6, averageCost: 28.7, region: "Global", sector: "Multi-sector"),
            .init(name: "US Bond Fund", symbol: "US-BOND", category: .fund, currency: .USD, quantity: 4100, price: 10.45, averageCost: 10.2, region: "United States", sector: "Fixed income"),
            .init(name: "Asia Dividend Fund", symbol: "ASIA-DIV", category: .fund, currency: .HKD, quantity: 8600, price: 8.35, averageCost: 7.8, region: "Hong Kong", sector: "Financials"),
            .init(name: "Global Infrastructure Fund", symbol: "GIFRA", category: .fund, currency: .USD, quantity: 1750, price: 15.8, averageCost: 14.9, region: "Europe", sector: "Utilities")
        ], accountNumber: "004-987654-085"),
        .init(id: UUID(uuidString: "10000000-0000-4000-8000-000000000008")!, name: "Standard Chartered Account", institution: "Standard Chartered", currency: .HKD, colorIndex: 4, note: "International wealth, bonds and structured investments", market: "Hong Kong", holdings: [
            .init(name: "NetEase", symbol: "09999", category: .stock, currency: .HKD, quantity: 300, price: 173.4, averageCost: 162, region: "Mainland China", sector: "Technology"),
            .init(name: "US Treasury Note", symbol: "UST-2028", category: .bond, currency: .USD, quantity: 70000, price: 1.018, averageCost: 0.995, region: "United States", sector: "Government"),
            .init(name: "Global equity-linked note", symbol: "GL-ELN", category: .other, currency: .USD, quantity: 50000, price: 1.036, averageCost: 1, region: "Global", sector: "Multi-sector"),
            .init(name: "Hong Kong savings policy", symbol: "HK-SAVINGS", category: .insurance, currency: .HKD, quantity: 1, price: 168000, averageCost: 150000, region: "Hong Kong", sector: "Insurance"),
            .init(name: "Global Energy Fund", symbol: "GEF", category: .fund, currency: .USD, quantity: 1400, price: 18.6, averageCost: 20.5, region: "Global", sector: "Energy"),
            .init(name: "US dollar balance", symbol: "USD", category: .cash, currency: .USD, quantity: 18500, price: 1, averageCost: 1, region: "United States", sector: "Cash")
        ], accountNumber: "447-123456-8")
    ]
}
