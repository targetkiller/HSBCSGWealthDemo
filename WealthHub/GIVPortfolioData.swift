import SwiftUI

struct GIVSlice: Identifiable {
    var id: String { name }
    let name: String
    let value: Double
    let color: Color
}

struct GIVEntry: Identifiable {
    var id: String { account.id.uuidString + holding.id.uuidString }
    let account: InvestmentAccount
    let holding: Holding
    let currency: Currency
    var value: Double { holding.currency.convert(holding.value, to: currency) }
    var cost: Double { holding.currency.convert(holding.cost, to: currency) }
    var profit: Double { value - cost }
    var region: String { holding.region ?? account.market }
    var sector: String { holding.sector ?? SampleData.row("asset_profiles", id: holding.category.rawValue).string("defaultSector") }
}

struct GIVPortfolioData {
    let accounts: [InvestmentAccount]
    let currency: Currency
    var entries: [GIVEntry] { accounts.flatMap { account in account.holdings.map { GIVEntry(account: account, holding: $0, currency: currency) } } }
    var value: Double { entries.reduce(0) { $0 + $1.value } }
    var cost: Double { entries.reduce(0) { $0 + $1.cost } }
    var profit: Double { value - cost }
    var returnRate: Double? { cost > 0 ? profit / cost * 100 : nil }
    var assets: [GIVSlice] { AssetClass.allCases.map { kind in GIVSlice(name: kind.rawValue, value: entries.filter { $0.holding.category == kind }.reduce(0) { $0 + $1.value }, color: Theme.color(kind)) }.filter { $0.value > 0 }.sorted { $0.value > $1.value } }
    var regions: [GIVSlice] { grouped { $0.region } }
    var sectors: [GIVSlice] { grouped { $0.sector } }
    var currencies: [GIVSlice] { grouped { $0.holding.currency.rawValue } }
    func percent(_ amount: Double) -> String { String(format: "%.2f%%", value > 0 ? amount / value * 100 : 0) }

    private func grouped(_ key: (GIVEntry) -> String) -> [GIVSlice] {
        Dictionary(grouping: entries, by: key).map { name, values in (name, values.reduce(0) { $0 + $1.value }) }
            .filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }.enumerated().map { index, item in GIVSlice(name: item.0, value: item.1, color: Self.colors[index % Self.colors.count]) }
    }

    static let colors: [Color] = [Color(hex: 0x286477), Color(hex: 0x4BAA08), Color(hex: 0xBF375A), Color(hex: 0xEF7046), Color(hex: 0x53A1B6), Color(hex: 0xF5B72D), Color(hex: 0xEB6182), Color(hex: 0x168B82)]
}
