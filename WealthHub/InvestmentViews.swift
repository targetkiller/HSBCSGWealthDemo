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
    let data: GIVPortfolioData
    @State private var byRegion = false
    @State private var expanded: Set<String> = []
    private var groups: [GIVSlice] { byRegion ? data.regions : data.assets }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Your holdings").font(.system(size: 17, weight: .medium))
            GIVDoubleRing(groups: groups, entries: data.entries, byRegion: byRegion).frame(height: 270)
            HStack(spacing: 0) {
                modeButton("square.stack.3d.up", region: false)
                modeButton("globe", region: true)
            }.padding(2).background(Theme.background, in: Capsule()).fixedSize()
            VStack(spacing: 0) {
                ForEach(groups) { group in
                    let items = data.entries.filter { byRegion ? $0.region == group.name : $0.holding.category.rawValue == group.name }
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { if expanded.contains(group.name) { expanded.remove(group.name) } else { expanded.insert(group.name) } }
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Rectangle().fill(group.color).frame(width: 12, height: 12).padding(.top, 2)
                            Text("\(group.name) (\(data.percent(group.value)))").font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading)
                            Text(store.amount(group.value)).font(.system(size: 14, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                            Image(systemName: expanded.contains(group.name) ? "chevron.up" : "chevron.down").font(.system(size: 12, weight: .light)).padding(.top, 3)
                        }.padding(.vertical, 17).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("giv.holdings.\(group.name)")
                    if expanded.contains(group.name) {
                        ForEach(items) { entry in
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
                    Divider()
                }
            }
        }.padding(16)
    }

    private func modeButton(_ symbol: String, region: Bool) -> some View {
        Button { withAnimation { byRegion = region; expanded = [] } } label: {
            Image(systemName: symbol).font(.system(size: 17, weight: .light)).frame(width: 55, height: 36)
                .background(byRegion == region ? .white : .clear, in: Capsule())
                .overlay(Capsule().stroke(byRegion == region ? Theme.line : .clear))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(region ? "View by region" : "View by asset class")
            .accessibilityIdentifier(region ? "giv.markets.region" : "giv.markets.asset")
            .accessibilityAddTraits(byRegion == region ? .isSelected : [])
    }
}

private struct GIVDoubleRing: View {
    let groups: [GIVSlice]
    let entries: [GIVEntry]
    let byRegion: Bool

    private var outerSlices: [GIVSlice] {
        groups.flatMap { group in
            entries.filter { byRegion ? $0.region == group.name : $0.holding.category.rawValue == group.name }
                .enumerated().map { index, entry in GIVSlice(name: entry.id, value: entry.value, color: group.color.opacity(0.35 + Double(index % 4) * 0.14)) }
        }
    }

    var body: some View {
        ZStack {
            if groups.isEmpty { Circle().stroke(Theme.line, lineWidth: 50).padding(35) }
            else {
                Chart(groups) { group in SectorMark(angle: .value("Market value", group.value), innerRadius: .ratio(0.36), outerRadius: .ratio(0.79), angularInset: 1).foregroundStyle(group.color) }.chartLegend(.hidden)
                Chart(outerSlices) { slice in SectorMark(angle: .value("Holding value", slice.value), innerRadius: .ratio(0.80), outerRadius: .ratio(1), angularInset: 1).foregroundStyle(slice.color) }.chartLegend(.hidden).accessibilityHidden(true)
            }
        }.padding(8).accessibilityLabel(byRegion ? "Holdings by region" : "Holdings by asset class")
    }
}
