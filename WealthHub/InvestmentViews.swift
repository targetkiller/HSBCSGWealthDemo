import SwiftUI
import Charts

struct RiskPanel: View {
    var accounts: [InvestmentAccount]
    private var holdings: [Holding] { accounts.flatMap(\.holdings) }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Risk & liquidity").font(.system(size: 15, weight: .medium))
            Chart(holdings) { holding in
                let profile = SampleData.row("asset_profiles", id: holding.category.rawValue)
                PointMark(x: .value("Liquidity", profile.double("liquidityScore")), y: .value("Risk", profile.double("riskScore")))
                    .symbolSize(holding.currency.convert(holding.value, to: .SGD) / 200 + 50).foregroundStyle(Theme.color(holding.category).opacity(0.7))
            }.chartXScale(domain: 0...10).chartYScale(domain: 0...10).frame(height: 230).chartXAxisLabel("Liquidity →").chartYAxisLabel("Risk →")
            ForEach(holdings) { item in HStack { Circle().fill(Theme.color(item.category)).frame(width: 8, height: 8); Text(item.name).font(.system(size: 12)); Spacer(); Text(SampleData.row("asset_profiles", id: item.category.rawValue).string("riskLabel")).font(.system(size: 11)).foregroundStyle(Theme.muted) } }
            Text("Illustrative category-based risk scores; not a suitability assessment.").font(.system(size: 10)).foregroundStyle(Theme.muted)
        }
    }
}

struct InvestmentView: View {
    @Environment(PortfolioStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIDs: Set<UUID>
    @State private var tab = "Markets"
    @State private var selectingAccounts = false
    @State private var showingMenu = false
    @State private var showingValueInfo = false

    init(selectedIDs: Set<UUID>) { _selectedIDs = State(initialValue: selectedIDs) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                summary.padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 14)
                HStack(spacing: 0) {
                    ForEach(["Markets", "Performance", "Analysis"], id: \.self) { item in
                        Button { tab = item } label: {
                            HStack(spacing: 5) {
                                if item == "Performance" { Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 12)) }
                                Text(item).font(.system(size: 14, weight: tab == item ? .medium : .regular))
                            }
                            .frame(maxWidth: .infinity).frame(height: 45)
                            .overlay(alignment: .bottom) { Rectangle().fill(tab == item ? Theme.red : .clear).frame(height: 2) }
                            .contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("giv.tab.\(item)")
                            .accessibilityAddTraits(tab == item ? .isSelected : [])
                    }
                }
                Divider()
                if accounts.isEmpty { EmptyPortfolio(title: "No accounts selected", message: "Select an account to explore your investments.") }
                else if tab == "Markets" { GIVMarketsView(data: data) }
                else if tab == "Performance" { GIVPerformanceView(data: data) }
                else { GIVAnalysisView(data: data) }
            }.padding(.bottom, 24)
        }
        .background(.white).foregroundStyle(Theme.ink)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 12) {
                Button { dismiss() } label: { Image(systemName: "arrow.left").font(.system(size: 21, weight: .light)).frame(width: 28, height: 44).contentShape(Rectangle()) }
                    .accessibilityLabel("Back to Wealth").accessibilityIdentifier("giv.back")
                Text("Global Investment View").font(.system(size: 17, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Button { showingMenu = true } label: { Image(systemName: "line.3.horizontal").font(.system(size: 22, weight: .light)).frame(width: 32, height: 44).contentShape(Rectangle()) }
                    .accessibilityLabel("Menu").accessibilityIdentifier("giv.menu")
            }.buttonStyle(.plain).padding(.horizontal, 12).background(.white)
        }
        .sheet(isPresented: $selectingAccounts) { AccountSelector(selectedIDs: $selectedIDs) }
        .sheet(isPresented: $showingMenu) { BankingMenuView() }
        .alert("Your portfolio value", isPresented: $showingValueInfo) {
            Button("OK", role: .cancel) {}
        } message: { Text("Market value is the sum of the selected holdings. Invested amount uses quantity × average unit cost. Values are converted using fixed demo exchange rates.") }
    }

    private var accounts: [InvestmentAccount] { store.accounts.filter { selectedIDs.isEmpty || selectedIDs.contains($0.id) } }
    private var data: GIVPortfolioData { GIVPortfolioData(accounts: accounts, currency: store.currency) }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 11) {
            Button { selectingAccounts = true } label: {
                HStack(spacing: 6) {
                    BankLogoStack(banks: accounts.map(\.institution), size: 15)
                    Text(selectedIDs.isEmpty || accounts.count == store.accounts.count ? "All global accounts selected" : accounts.count == 1 ? accounts[0].name : "\(accounts.count) accounts selected")
                        .font(.system(size: 11)).lineLimit(1)
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .light))
                }.padding(.horizontal, 10).padding(.vertical, 9).overlay(Capsule().stroke(Theme.line)).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("giv.accounts")
            Button { showingValueInfo = true } label: { HStack(spacing: 4) { Text("Your global total market value"); Image(systemName: "questionmark.circle") }.font(.system(size: 12)).foregroundStyle(Theme.muted).contentShape(Rectangle()) }.buttonStyle(.plain)
            Menu {
                ForEach(Currency.allCases) { currency in Button(currency.rawValue) { store.currency = currency } }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(store.hideAmounts ? "••••••" : data.value.formatted(.number.precision(.fractionLength(2))))
                        .font(.system(size: 29, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.65)
                    Text(store.currency.rawValue).font(.system(size: 12, weight: .medium))
                    Image(systemName: "chevron.down").font(.system(size: 13, weight: .light))
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("giv.totalValue")
            HStack(spacing: 4) {
                Text("Unrealised gain/loss").foregroundStyle(Theme.muted)
                Image(systemName: "questionmark.circle").foregroundStyle(Theme.muted)
                Spacer(minLength: 5)
                Image(systemName: data.profit >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill").font(.system(size: 7)).foregroundStyle(data.profit >= 0 ? Theme.green : Theme.red).accessibilityHidden(true)
                Text(store.amount(data.profit) + " (" + (data.returnRate.map { String(format: "%+.2f%%", $0) } ?? "—") + ")").fontWeight(.semibold).lineLimit(1).minimumScaleFactor(0.65)
            }.font(.system(size: 11))
            HStack(spacing: 4) {
                Text("Total invested amount").foregroundStyle(Theme.muted)
                Image(systemName: "questionmark.circle").foregroundStyle(Theme.muted)
                Spacer()
                Text(store.amount(data.cost)).fontWeight(.semibold)
            }.font(.system(size: 12))
        }
    }
}

struct GIVMarketsView: View {
    @Environment(PortfolioStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let data: GIVPortfolioData
    @State private var expanded: Set<String> = []
    private var groups: [GIVHoldingGroup] {
        GIVHoldingGroup.order.compactMap { category in
            let entries = data.entries.filter { $0.holding.category == category }
            return entries.isEmpty ? nil : GIVHoldingGroup(category: category, entries: entries)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your holdings").font(.system(size: 19, weight: .medium)).padding(.vertical, 8)
            allocationBar.padding(.top, 8)
            if groups.isEmpty {
                Text("No holdings in the selected accounts.").font(.system(size: 14)).foregroundStyle(Theme.muted).padding(.vertical, 24)
            }
            // The screen already scrolls; keep the legend rows in that same scroll flow.
            LazyVStack(spacing: 0) {
                ForEach(groups) { group in
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                            if expanded.contains(group.id) { expanded.remove(group.id) } else { expanded.insert(group.id) }
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Rectangle().fill(group.color).frame(width: 14, height: 14)
                                .frame(width: 18, height: 20).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(group.title) (\(data.percent(group.value)))")
                                    .font(.system(size: 14)).frame(maxWidth: .infinity, alignment: .leading)
                                if group.category == .insurance {
                                    Text("Total cash value").font(.system(size: 14)).padding(.top, 8)
                                }
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    balance(group.value)
                                    Spacer(minLength: 0)
                                    gain(group)
                                }
                                HStack(spacing: 4) {
                                    ForEach(group.markets, id: \.self) { market in
                                        Text(market).font(.system(size: 12)).padding(.horizontal, 8).padding(.vertical, 4)
                                            .background(Theme.line)
                                    }
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(group.markets.joined(separator: ", "))
                                .accessibilityIdentifier("giv.holdings.markets.\(group.id)")
                            }
                        }.padding(.vertical, 12).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("giv.holdings.\(group.id)")
                        .accessibilityHint(expanded.contains(group.id) ? "Collapse holdings" : "Show individual holdings")
                    if expanded.contains(group.id) {
                        ForEach(group.entries) { entry in
                            NavigationLink { AccountDetailView(accountID: entry.account.id).toolbar(.visible, for: .navigationBar) } label: {
                                HStack(spacing: 8) {
                                    BankMark(bank: entry.account.institution).scaleEffect(0.65).frame(width: 20)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.holding.name).font(.system(size: 12))
                                        Text(entry.account.name).font(.system(size: 10)).foregroundStyle(Theme.muted)
                                    }
                                    Spacer(minLength: 4)
                                    Text(store.amount(entry.value)).font(.system(size: 11)).lineLimit(1).minimumScaleFactor(0.7)
                                }.padding(.vertical, 11).padding(.leading, 14).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    }
                    if group.id != groups.last?.id { Divider() }
                }
            }
        }.padding(.horizontal, 16).padding(.vertical, 12)
    }

    private var allocationBar: some View {
        Chart {
            ForEach(groups) { group in
                BarMark(x: .value("Market value", group.value), y: .value("Allocation", "Holdings"), height: .fixed(12))
                    .foregroundStyle(group.color)
            }
            ForEach(Array(groups.dropLast().enumerated()), id: \.element.id) { index, _ in
                RuleMark(x: .value("Category boundary", groups.prefix(index + 1).reduce(0) { $0 + $1.value }))
                    .foregroundStyle(.white).lineStyle(StrokeStyle(lineWidth: 1.5))
            }
        }
        .chartXScale(domain: 0...(data.value > 0 ? data.value : 1)).chartXAxis(.hidden).chartYAxis(.hidden).chartLegend(.hidden)
        .frame(height: 12).background(Theme.background)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Holdings allocation")
        .accessibilityValue(groups.map { "\($0.title): \(data.percent($0.value))" }.joined(separator: ", "))
        .accessibilityIdentifier("giv.holdings.allocationBar")
    }

    private func balance(_ value: Double) -> some View {
        let parts = value.formatted(.number.locale(Locale(identifier: "en_SG")).precision(.fractionLength(2))).split(separator: ".")
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(store.hideAmounts ? "••••••" : String(parts.first ?? "0")).font(.system(size: 16, weight: .semibold))
            if !store.hideAmounts { Text("." + String(parts.last ?? "00")).font(.system(size: 12, weight: .medium)) }
            Text(" " + store.currency.rawValue).font(.system(size: 12)).foregroundStyle(Theme.muted)
        }.lineLimit(1).minimumScaleFactor(0.75)
            .accessibilityElement(children: .ignore).accessibilityLabel(store.amount(value))
    }

    private func gain(_ group: GIVHoldingGroup) -> some View {
        let rate = group.returnRate.map { String(format: "%.2f%%", $0) } ?? "—"
        let amount = group.profit.formatted(.number.locale(Locale(identifier: "en_SG")).precision(.fractionLength(2)))
        let text = store.hideAmounts ? "••••••" : "\(rate) (\(group.profit >= 0 ? "+" : "")\(amount))"
        return HStack(spacing: 3) {
            if !store.hideAmounts { Image(systemName: group.profit >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill").font(.system(size: 7)).accessibilityHidden(true) }
            Text(text).font(.system(size: 14)).lineLimit(1).minimumScaleFactor(0.7)
        }.foregroundStyle(group.profit >= 0 ? Theme.green : Theme.red)
            .accessibilityElement(children: .ignore).accessibilityLabel("Unrealised gain/loss: " + text)
            .accessibilityIdentifier("giv.holdings.gain.\(group.id)")
    }
}

private struct GIVHoldingGroup: Identifiable {
    static let order: [AssetClass] = [.fund, .stock, .bond, .other, .insurance, .option, .cash]
    let category: AssetClass
    let entries: [GIVEntry]
    var id: String { category.rawValue }
    var value: Double { entries.reduce(0) { $0 + $1.value } }
    var cost: Double { entries.reduce(0) { $0 + $1.cost } }
    var profit: Double { value - cost }
    var returnRate: Double? { cost > 0 ? profit / cost * 100 : nil }
    var title: String {
        switch category {
        case .fund: "Unit Trusts & Mutual funds"
        case .stock: "Stocks & Equities / ETFs"
        case .insurance: "Investment-linked insurance"
        default: category.rawValue
        }
    }
    var color: Color {
        let index = category == .option ? 6 : category == .cash ? 5 : Self.order.firstIndex(of: category) ?? 0
        return GIVPortfolioData.colors[index]
    }
    var markets: [String] {
        let names = Set(entries.map { $0.account.market })
        let configured = SampleData.rows("markets")
        let known = configured.filter { names.contains($0.string("name")) }.map { $0.string("shortName") }
        let unknown = names.subtracting(configured.map { $0.string("name") }).sorted()
        return known + unknown
    }
}
