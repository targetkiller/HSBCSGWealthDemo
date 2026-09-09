import Foundation
import Observation

@Observable
final class PortfolioStore {
    private(set) var accounts: [InvestmentAccount]
    var currency: Currency { didSet { persist() } }
    var hideAmounts: Bool { didSet { persist() } }
    var storageError: String?
    private let defaults: UserDefaults
    private let key = "wealthhub.portfolio.v1"
    private static let seedVersion = 2

    private struct Snapshot: Codable {
        var accounts: [InvestmentAccount]
        var currency: Currency
        var hideAmounts: Bool
        var seedVersion: Int? = nil
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key), let saved = try? JSONDecoder().decode(Snapshot.self, from: data) {
            accounts = saved.accounts
            currency = saved.currency
            hideAmounts = saved.hideAmounts
            if (saved.seedVersion ?? 1) < Self.seedVersion {
                accounts = Self.migrateDefaultAccounts(saved.accounts)
                persist()
            }
        } else {
            accounts = DemoData.accounts
            currency = .SGD
            hideAmounts = false
            if defaults.data(forKey: key) != nil { storageError = "本地数据无法读取，已载入演示数据。原始存储尚未覆盖。" }
            else { persist() }
        }
    }

    var totalValue: Double { accounts.reduce(0) { $0 + $1.value(in: currency) } }
    var totalCost: Double { accounts.reduce(0) { $0 + $1.cost(in: currency) } }
    var totalProfit: Double { totalValue - totalCost }
    var totalReturn: Double? { totalCost > 0 ? totalProfit / totalCost * 100 : nil }
    var holdingCount: Int { accounts.reduce(0) { $0 + $1.holdings.count } }

    func amount(_ value: Double, compact: Bool = false) -> String {
        hideAmounts ? "••••••" : currency.format(value, compact: compact)
    }

    func allocation(for subset: [InvestmentAccount]? = nil) -> [(category: AssetClass, value: Double)] {
        let holdings = (subset ?? accounts).flatMap(\.holdings)
        return AssetClass.allCases.map { category in
            (category, holdings.filter { $0.category == category }.reduce(0) { $0 + $1.currency.convert($1.value, to: currency) })
        }.filter { $0.value > 0 }.sorted { $0.value > $1.value }
    }

    func save(_ account: InvestmentAccount) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) { accounts[index] = account }
        else { accounts.append(account) }
        persist()
    }

    func deleteAccount(id: UUID) { accounts.removeAll { $0.id == id }; persist() }
    func saveHolding(_ holding: Holding, accountID: UUID) {
        guard let index = accounts.firstIndex(where: { $0.id == accountID }) else { return }
        if let item = accounts[index].holdings.firstIndex(where: { $0.id == holding.id }) { accounts[index].holdings[item] = holding }
        else { accounts[index].holdings.append(holding) }
        persist()
    }
    func deleteHolding(id: UUID, accountID: UUID) {
        guard let index = accounts.firstIndex(where: { $0.id == accountID }) else { return }
        accounts[index].holdings.removeAll { $0.id == id }
        persist()
    }
    func reset() { accounts = DemoData.accounts; currency = .SGD; hideAmounts = false; persist() }

    private static func migrateDefaultAccounts(_ saved: [InvestmentAccount]) -> [InvestmentAccount] {
        // An intentionally cleared portfolio must stay empty, including on its first upgrade.
        guard !saved.isEmpty else { return [] }
        let legacyNames = [
            "(068) Equity Investment Account": "Equity Investment Account",
            "HSBC One Investment Services": "Hong Kong Investment Account",
            "DBS Account": "Wealth Portfolio"
        ]
        let legacySymbols: [String: Set<String>] = [
            "(068) Equity Investment Account": ["NVDA", "AAPL", "VOO"],
            "HSBC One Investment Services": ["00700", "09988", "HKD"],
            "DBS Account": ["SGS", "GIF", "SGD"]
        ]
        var consumed = Set<Int>()
        var result: [InvestmentAccount] = []

        for template in DemoData.accounts {
            let available = saved.indices.filter { !consumed.contains($0) }
            let sameBankAndMarket: (InvestmentAccount) -> Bool = {
                $0.institution.caseInsensitiveCompare(template.institution) == .orderedSame && $0.market == template.market
            }
            let matched = available.first { saved[$0].id == template.id }
                ?? available.first {
                    sameBankAndMarket(saved[$0]) && saved[$0].accountNumber != nil && saved[$0].accountNumber == template.accountNumber
                }
                ?? available.first {
                    sameBankAndMarket(saved[$0]) && (saved[$0].name == template.name || saved[$0].name == legacyNames[template.name])
                }
                ?? available.first {
                    guard sameBankAndMarket(saved[$0]), let signature = legacySymbols[template.name] else { return false }
                    let symbols = Set(saved[$0].holdings.map { $0.symbol.uppercased() })
                    return signature.intersection(symbols).count >= 2
                }

            if let matched {
                consumed.insert(matched)
                var account = saved[matched]
                // Preserve IDs, edited names, balances and user-added or deleted holdings.
                if account.name == legacyNames[template.name] { account.name = template.name }
                if account.accountNumber == nil { account.accountNumber = template.accountNumber }
                account.holdings = account.holdings.map { holding in
                    var enriched = holding
                    if let reference = template.holdings.first(where: { $0.symbol.caseInsensitiveCompare(holding.symbol) == .orderedSame && $0.currency == holding.currency }) {
                        if enriched.region == nil { enriched.region = reference.region }
                        if enriched.sector == nil { enriched.sector = reference.sector }
                    }
                    return enriched
                }
                result.append(account)
            } else {
                result.append(template)
            }
        }

        result.append(contentsOf: saved.indices.filter { !consumed.contains($0) }.map { saved[$0] })
        return result
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(Snapshot(accounts: accounts, currency: currency, hideAmounts: hideAmounts, seedVersion: Self.seedVersion))
            defaults.set(data, forKey: key)
        } catch { storageError = "保存失败：\(error.localizedDescription)" }
    }
}
