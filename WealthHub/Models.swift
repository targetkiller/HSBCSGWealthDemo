import Foundation

enum Currency: String, Codable, CaseIterable, Identifiable {
    case SGD, CNY, USD, HKD
    var id: String { rawValue }
    var symbol: String { SampleData.row("currencies", id: rawValue).string("symbol") }
    // Fixed demo rates, quoted as CNY per unit; never live market data.
    var cnyRate: Double { SampleData.row("currencies", id: rawValue).double("cnyRate") }
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
