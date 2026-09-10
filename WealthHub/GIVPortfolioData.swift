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

struct GIVHistoryPoint: Identifiable {
    var id: String { series + String(index) }
    let series: String
    let index: Int
    let date: Date
    let value: Double
}

/// A shared, deterministic demo history for selected accounts and the live reference account.
/// Current market values and costs remain authoritative; this models an illustrative time path.
struct GIVPerformanceModel {
    static let mySeriesName = "My total return"
    let data: GIVPortfolioData
    let availableAccounts: [InvestmentAccount]
    let market: String
    let range: ClosedRange<Date>

    static func periodRange(for period: String, asOf date: Date) -> ClosedRange<Date> {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let first: Date
        if period == "ytd" {
            first = calendar.date(from: calendar.dateComponents([.year], from: date)) ?? date
        } else {
            first = calendar.date(byAdding: period == "year" ? .year : .month, value: -1, to: date) ?? date
        }
        return first...date
    }

    private static let calibrationRange: ClosedRange<Date> = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        let asOf = formatter.date(from: SampleData.row("performance", id: "default").string("asOfDate"))!
        return periodRange(for: "ytd", asOf: asOf)
    }()

    private var settings: SampleRecord { SampleData.row("performance", id: "default") }
    var referenceName: String { SampleData.row("benchmarks", id: settings.string("referenceBenchmarkID")).string("name") }
    var entries: [GIVEntry] { filtered(data.entries) }
    var invested: Double { entries.reduce(0) { $0 + $1.cost } }
    var referenceMarket: String {
        if market == "Singapore" || market == "Hong Kong" { return market }
        let accountMarkets = Set(data.accounts.map(\.market))
        if accountMarkets == ["Hong Kong"] { return "Hong Kong" }
        if accountMarkets == ["Singapore"] { return "Singapore" }
        return settings.string("defaultReferenceMarket")
    }
    var referenceAccount: InvestmentAccount? {
        let key = referenceMarket == "Hong Kong" ? "hkReferencePortfolioID" : "sgReferencePortfolioID"
        let portfolioID = settings.string(key)
        guard let configured = SampleData.rows("accounts").first(where: { $0.string("portfolioID") == portfolioID }) else { return nil }
        if let exact = availableAccounts.first(where: { $0.id == UUID(uuidString: configured.id) }) { return exact }
        // Legacy migrations preserve their random account IDs and any edited display names.
        return availableAccounts.first { account in
            guard account.institution.caseInsensitiveCompare(configured.string("institution")) == .orderedSame,
                  account.market == configured.string("market") else { return false }
            if !configured.string("accountNumber").isEmpty, account.accountNumber == configured.string("accountNumber") { return true }
            return account.name == configured.string("name")
        }
    }

    private var duration: Double {
        min(settings.double("maxYears"), max(0, range.upperBound.timeIntervalSince(range.lowerBound) / 86_400) / 365)
    }
    private var calibrationDuration: Double { Self.calibrationRange.upperBound.timeIntervalSince(Self.calibrationRange.lowerBound) / (86_400 * 365) }
    private var intervals: Int { settings.int("sampleIntervals") }
    private func filtered(_ entries: [GIVEntry]) -> [GIVEntry] {
        entries.filter { market == settings.string("allMarketsLabel") || $0.region == market }
    }

    func history(for series: String) -> [GIVHistoryPoint] {
        let values: [Double]
        if series == Self.mySeriesName {
            values = portfolioValues(entries)
        } else if series == referenceName {
            guard let referenceAccount else { return [] }
            let referenceData = GIVPortfolioData(accounts: [referenceAccount], currency: data.currency)
            values = portfolioValues(filtered(referenceData.entries))
        } else if let benchmark = SampleData.rows("benchmarks").first(where: { $0.string("name") == series }) {
            values = benchmarkValues(benchmark)
        } else { return [] }
        return values.enumerated().map { index, value in
            let fraction = Double(index) / Double(intervals)
            return GIVHistoryPoint(series: series, index: index, date: range.lowerBound.addingTimeInterval(range.upperBound.timeIntervalSince(range.lowerBound) * fraction), value: value)
        }
    }

    private func portfolioValues(_ entries: [GIVEntry]) -> [Double] {
        guard !entries.isEmpty else { return [] }
        let groups = Dictionary(grouping: entries, by: { $0.account.id.uuidString })
        let accountEntries = groups.keys.sorted().map { groups[$0]! }
        // Return the account path directly: a single selected reference account must coincide
        // point-for-point, without an extra percentage multiplication/division round trip.
        if accountEntries.count == 1 { return accountValues(accountEntries[0]) }
        let costs = accountEntries.map { $0.reduce(0) { $0 + $1.cost } }
        let totalCost = costs.reduce(0, +)
        guard totalCost > 0 else { return Array(repeating: 0, count: intervals + 1) }
        let paths = accountEntries.map(accountValues)
        return (0...intervals).map { index in
            zip(paths, costs).reduce(0) { $0 + $1.0[index] * ($1.1 / totalCost) }
        }
    }

    private func accountValues(_ entries: [GIVEntry]) -> [Double] {
        let sorted = entries.sorted { $0.holding.id.uuidString < $1.holding.id.uuidString }
        let cost = sorted.reduce(0) { $0 + $1.cost }
        guard cost > 0, let account = sorted.first?.account else { return Array(repeating: 0, count: intervals + 1) }
        let profiles = SampleData.rows("performance_banks")
        let profile = profiles.first { $0.string("institution").caseInsensitiveCompare(account.institution) == .orderedSame }
            ?? profiles.first { $0.string("institution") == "*" }!
        let returnRate = sorted.reduce(0) { $0 + $1.profit } / cost * 100
        let limit = settings.double("maxHoldingTiltPercent")
        let tilt = min(limit, max(-limit, returnRate * settings.double("holdingTiltWeight")))
        let holdingPhase = sorted.reduce(0) { total, entry in
            let identity = entry.holding.symbol + "|" + entry.holding.currency.rawValue + "|" + entry.holding.category.rawValue
            return total + seed(identity) * (entry.cost / cost)
        }
        // The configured YTD return fixes the endpoint. Live holdings affect the journey,
        // so account edits remain visible without breaking the presentation's return targets.
        let phase = profile.double("phaseOffset") + holdingPhase * settings.double("primarySeedMultiplier")
            + seed(account.market) * 2 * .pi
        let shift = (seed(account.market) + holdingPhase - 1) * settings.double("eventPhaseWeight")
        return curveValues(profile, amplitude: profile.double("waveAmplitude"),
                           primaryFrequency: profile.double("primaryFrequency"), secondaryFrequency: profile.double("secondaryFrequency"),
                           phase: phase, eventShift: shift, varianceDuration: duration, holdingTilt: tilt)
    }

    private func seed(_ label: String) -> Double {
        let modulus = settings.int("seedModulus")
        let sum = label.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % modulus }
        return Double(sum) / Double(modulus)
    }

    private func benchmarkValues(_ benchmark: SampleRecord) -> [Double] {
        curveValues(benchmark, amplitude: benchmark.double("amplitude"),
                    primaryFrequency: settings.double("primaryFrequency"), secondaryFrequency: settings.double("secondaryFrequency"),
                    phase: seed(benchmark.string("name")) * settings.double("primarySeedMultiplier"), eventShift: 0,
                    varianceDuration: max(settings.double("minDuration"), duration))
    }

    private func curveValues(_ profile: SampleRecord, amplitude: Double, primaryFrequency: Double,
                             secondaryFrequency: Double, phase: Double, eventShift: Double,
                             varianceDuration: Double, holdingTilt: Double = 0) -> [Double] {
        guard duration > 0 else { return Array(repeating: 0, count: intervals + 1) }
        let ratio = duration / calibrationDuration
        // The full YTD range uses the configured value directly to retain an exact endpoint.
        let ytdReturn = profile.double("ytdReturnPercent")
        let target = ratio == 1 ? ytdReturn : expm1(log1p(ytdReturn / 100) * ratio) * 100
        let varianceScale = sqrt(varianceDuration / calibrationDuration)
        let drawdown = profile.double("drawdownPosition") + eventShift
        let recovery = profile.double("recoveryPosition") + eventShift
        let depth = profile.double("drawdownDepth")
        let width = profile.double("drawdownWidth")
        let weight = settings.double("secondaryWeight")
        return (0...intervals).map { index in
            if index == 0 { return 0 }
            if index == intervals { return target }
            let x = Double(index) / Double(intervals)
            let primary = sin(x * primaryFrequency + phase)
            let secondary = sin(x * secondaryFrequency + phase * settings.double("secondarySeedMultiplier"))
            let cycle = amplitude * sin(.pi * x) * (primary + secondary * weight) / (1 + abs(weight))
            let retreat = depth * pulse(x, center: drawdown, width: width)
            let rebound = settings.double("recoveryStrength") * depth * pulse(x, center: recovery, width: width * 1.5)
            let progress = x + settings.double("trendVariation") * sin(2 * .pi * x + phase) * x * (1 - x)
            let holdingAdjustment = holdingTilt * ratio * 4 * x * (1 - x)
            return target * progress + varianceScale * (cycle - retreat + rebound) + holdingAdjustment
        }
    }

    /// A local decline/recovery fades to zero at both endpoints, without moving the YTD target.
    private func pulse(_ x: Double, center: Double, width: Double) -> Double {
        func gaussian(_ position: Double) -> Double { exp(-0.5 * pow((position - center) / width, 2)) }
        return gaussian(x) - (1 - x) * gaussian(0) - x * gaussian(1)
    }
}
