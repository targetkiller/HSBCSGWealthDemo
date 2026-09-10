import SwiftUI
import Charts

struct WealthView: View {
    @Environment(PortfolioStore.self) private var store
    @State private var selectedIDs = Set<UUID>()
    @State private var selectionReady = false
    @State private var selectionPresented = false
    @State private var addPortfolioPresented = false
    @State private var assistantPresented = false
    @State private var globalView = false
    @State private var overview = "Overview"
    @State private var analysis = "Summary"
    @State private var generated = false
    @State private var analysisExpanded = false
    @State private var generating = false
    @State private var analysisTask: Task<Void, Never>?
    @State private var expandedCategory: AssetClass?
    @State private var geography = false
    @State private var scenarioID = SampleData.setting("defaultWealthScenarioID")
    @State private var infoExpanded = false
    @State private var updateMessage: String?
    @State private var productPreview: String?

    private var accounts: [InvestmentAccount] { store.accounts.filter { selectedIDs.isEmpty || selectedIDs.contains($0.id) } }
    private var holdings: [Holding] { accounts.flatMap(\.holdings) }
    private var total: Double { accounts.reduce(0) { $0 + $1.value(in: store.currency) } }
    private var cost: Double { accounts.reduce(0) { $0 + $1.cost(in: store.currency) } }
    private var allocation: [(category: AssetClass, value: Double)] { store.allocation(for: accounts) }
    private var topHolding: Holding? { holdings.max { $0.currency.convert($0.profit, to: store.currency) < $1.currency.convert($1.profit, to: store.currency) } }
    private var lowestHolding: Holding? { holdings.min { $0.currency.convert($0.profit, to: store.currency) < $1.currency.convert($1.profit, to: store.currency) } }
    private var scenario: SampleRecord { SampleData.row("wealth_scenarios", id: scenarioID) }
    private var selectionTitle: String {
        if selectedIDs.isEmpty { return "All global accounts selected" }
        if accounts.count == 1, let account = accounts.first { return "\(account.institution) · \(account.name)" }
        return "\(accounts.count) accounts selected"
    }

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(spacing: 0) {
                    summary.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 18)
                    portfolioAnalysis(scroll: scroll).padding(16).background(Theme.background)
                    quickActions.padding(.horizontal, 16).padding(.vertical, 24)
                    overviewTabs
                    if accounts.isEmpty {
                        EmptyPortfolio()
                        Button("Add other holdings to analyse") { addPortfolioPresented = true }.padding(.bottom, 28)
                    } else if overview == "Insights" {
                        insights.padding(16)
                    } else {
                        holdingsSection.id("holdings").padding(.horizontal, 16).padding(.vertical, 24)
                        if globalView || analysis != "Summary" { stressTest.padding(16) }
                        WealthProductsSection(onSelect: { productPreview = $0 }).id("products")
                        futurePlanner.padding(16)
                    }
                    DisclosureGroup("Important information", isExpanded: $infoExpanded) {
                        Text("This demonstration uses sample portfolios and fixed exchange rates. The analysis is generated on this device from your selected holdings. Investment returns and stress scenarios are illustrative. Bank connections do not access real accounts.")
                            .font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(4).padding(.top, 10)
                    }.font(.system(size: 13)).padding(16)
                }
            }
            .background(WealthBackdrop())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                WealthHelpBar { assistantPresented = true }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $selectionPresented, onDismiss: { updateMessage = nil }) { AccountSelector(selectedIDs: $selectedIDs) }
            .sheet(isPresented: $addPortfolioPresented) {
                AddPortfolioSheet { includedIDs in
                    if !selectedIDs.isEmpty { selectedIDs.formUnion(includedIDs) }
                    updateMessage = "Your added holdings are now included in this analysis."
                    refreshAnalysis()
                    withAnimation { scroll.scrollTo("portfolioAnalysis", anchor: .top) }
                }
            }
            .sheet(isPresented: $assistantPresented) { WealthAssistantSheet(accounts: accounts) }
            .sheet(isPresented: Binding(get: { productPreview != nil }, set: { if !$0 { productPreview = nil } })) {
                WealthProductPreview(title: productPreview ?? "Wealth")
            }
            .onAppear {
                if !selectionReady {
                    if let first = SampleData.defaultAccount(in: store.accounts) { selectedIDs = [first.id] }
                    selectionReady = true
                }
            }
            .onChange(of: store.accounts.map(\.id)) { _, ids in selectedIDs.formIntersection(ids) }
            .onDisappear { analysisTask?.cancel(); generating = false }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 14) {
            if globalView {
                HStack(spacing: 7) {
                    ForEach(SampleData.rows("markets"), id: \.id) { market in
                        Pill(title: market.string("shortName"), selected: !accounts.isEmpty && accounts.allSatisfy { $0.market == market.string("name") }) {
                            selectedIDs = Set(store.accounts.filter { $0.market == market.string("name") }.map(\.id))
                        }
                    }
                    Pill(title: "◎ Global view", selected: selectedIDs.isEmpty) { selectedIDs = [] }
                }
            }
            Button { selectionPresented = true } label: {
                HStack(spacing: 9) {
                    BankLogoStack(banks: accounts.map(\.institution), size: 20)
                    Text(selectionTitle).font(.system(size: 13)).lineLimit(1)
                    Image(systemName: "chevron.down").font(.system(size: 15, weight: .light))
                }.padding(.horizontal, 12).padding(.vertical, 10).background(.white.opacity(0.8), in: Capsule()).overlay(Capsule().stroke(Color(hex: 0xD7D8D6))).contentShape(Capsule())
            }.buttonStyle(.plain).accessibilityIdentifier("accountSelector")
            Label("Total market value", systemImage: "questionmark.circle").labelStyle(WealthTrailingIconLabelStyle()).font(.system(size: 14))
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(store.hideAmounts ? "••••••" : total.formatted(.number.precision(.fractionLength(2))))
                    .font(.system(size: 31, weight: .semibold)).tracking(-0.8).minimumScaleFactor(0.6).lineLimit(1).contentTransition(.numericText())
                Menu { ForEach(Currency.allCases) { item in Button(item.rawValue) { store.currency = item } } } label: {
                    Text(store.currency.rawValue).font(.system(size: 18)).foregroundStyle(Theme.ink)
                }.accessibilityLabel("Reporting currency")
            }
            HStack(spacing: 6) {
                Label("Unrealised gain/loss", systemImage: "questionmark.circle").labelStyle(WealthTrailingIconLabelStyle()).font(.system(size: 12))
                Spacer(minLength: 4)
                Image(systemName: total >= cost ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill").font(.system(size: 8)).foregroundStyle(total >= cost ? Theme.green : Theme.red)
                Text(store.amount(total - cost)).font(.system(size: 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.6)
                Text(cost > 0 ? String(format: "(%+.2f%%)", (total - cost) / cost * 100) : "(—)").font(.system(size: 11, weight: .semibold))
            }
            HStack {
                Label("Realised gain/loss", systemImage: "questionmark.circle").labelStyle(WealthTrailingIconLabelStyle()).font(.system(size: 12))
                Spacer()
                NavigationLink { InvestmentView(selectedIDs: Set(accounts.map(\.id))) } label: { HStack(spacing: 8) { Text("View details").font(.system(size: 13, weight: .semibold)); Image(systemName: "arrow.right").font(.system(size: 18, weight: .light)) }.contentShape(Rectangle()) }.buttonStyle(.plain).disabled(accounts.isEmpty).accessibilityIdentifier("wealth.viewDetails")
            }
        }
    }

    private func portfolioAnalysis(scroll: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles").font(.system(size: 25, weight: .light)).foregroundStyle(Theme.red).padding(.top, 3)
                VStack(alignment: .leading, spacing: 4) { Text("Portfolio analysis").font(.system(size: 17, weight: .semibold)); if generated || generating { Text(generating ? "Analysing…" : "Just now").font(.system(size: 12)).foregroundStyle(Theme.muted) } }
                Spacer()
                if generated {
                    Menu { Button("Regenerate analysis") { refreshAnalysis() }; Button("Add other holdings") { addPortfolioPresented = true } } label: { Image(systemName: "ellipsis").rotationEffect(.degrees(90)).frame(width: 24, height: 30).contentShape(Rectangle()) }.foregroundStyle(Theme.ink)
                    Button { withAnimation { analysisExpanded.toggle() } } label: { Image(systemName: analysisExpanded ? "chevron.up" : "chevron.down").font(.system(size: 20, weight: .light)).frame(width: 28, height: 30).contentShape(Rectangle()) }.buttonStyle(.plain).accessibilityLabel("Toggle portfolio analysis")
                }
            }
            if generating {
                VStack(alignment: .leading, spacing: 9) { ForEach(0..<7) { index in Rectangle().fill(Theme.line).frame(height: 9).frame(maxWidth: index % 3 == 0 ? 200 : .infinity, alignment: .leading) } }.redacted(reason: .placeholder).accessibilityLabel("Analysing selected holdings")
            } else if generated && analysisExpanded {
                if let updateMessage { Label(updateMessage, systemImage: "checkmark.circle").font(.system(size: 12)).foregroundStyle(Theme.green).accessibilityIdentifier("portfolio.analysis.updated") }
                analysisContent(scroll: scroll)
            } else {
                briefAnalysis.font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(4).lineLimit(4)
            }
            }.padding(16)
            if !generated || !analysisExpanded {
                Rectangle().fill(Theme.line).frame(height: 1).padding(.horizontal, 16)
                Button { refreshAnalysis() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles").foregroundStyle(Theme.red)
                        Text(generated ? "View AI analysis" : "Generate AI analysis")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .center)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).disabled(generating)
                .accessibilityIdentifier("portfolio.analysis.generate")
            }
            if generated || generating {
                VStack(spacing: 8) {
                    Button { addPortfolioPresented = true } label: { Label("Add other holdings to analyse", systemImage: "plus.circle").font(.system(size: 14, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth: .infinity).padding(.vertical, 13).overlay(Rectangle().stroke(Theme.ink, lineWidth: 1)).contentShape(Rectangle()) }.buttonStyle(.plain).accessibilityIdentifier("portfolio.addHoldings")
                    if generated && store.accounts.count > 1 {
                        NavigationLink { InvestmentView(selectedIDs: []) } label: { Label("View my global holdings", systemImage: "globe").font(.system(size: 14)).frame(maxWidth: .infinity).padding(.vertical, 13).overlay(Rectangle().stroke(Theme.ink, lineWidth: 1)).contentShape(Rectangle()) }.buttonStyle(.plain).accessibilityIdentifier("portfolio.globalHoldings")
                    }
                    Text("* You can add your global HSBC accounts, other banks data.").font(.system(size: 11)).foregroundStyle(Theme.muted).frame(maxWidth: .infinity, alignment: .leading).lineSpacing(3)
                }.padding(16)
            }
        }.background(.white).overlay(Rectangle().stroke(Color(hex: 0xD7D8D6), lineWidth: 1)).id("portfolioAnalysis")
    }

    private var briefAnalysis: Text {
        guard let topHolding else { return Text("Add your holdings to understand your portfolio across accounts, asset classes and markets.") }
        return Text("Portfolio movers | ").bold() + Text(topHolding.name).underline() + Text(" has an unrealised gain/loss of ") + Text(store.amount(topHolding.currency.convert(topHolding.profit, to: store.currency))).foregroundColor(topHolding.profit >= 0 ? Theme.green : Theme.red) + Text(". Explore your allocation and exposure with a personalised portfolio overview.")
    }

    private func analysisContent(scroll: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What happened").font(.system(size: 15, weight: .semibold))
            briefAnalysis.font(.system(size: 14)).lineSpacing(5)
            if let low = lowestHolding, low.id != topHolding?.id {
                (Text("Relative performance | ").bold() + Text(low.name).underline() + Text(" has an unrealised return of ") + Text(low.returnRate.map { String(format: "%+.2f%%", $0) } ?? "N/A").foregroundColor(low.profit >= 0 ? Theme.green : Theme.red) + Text(". Results reflect current value versus invested cost.")).font(.system(size: 14)).lineSpacing(5)
            }
            let largest = allocation.first
            Text("Exposure | \(largest?.category.rawValue ?? "Cash") accounts for \(total > 0 ? Int((largest?.value ?? 0) / total * 100) : 0)% of your selected portfolio. Currency movements and market changes may affect your returns.").font(.system(size: 14)).lineSpacing(5)
            Button { analysis = "Allocation analysis"; withAnimation { scroll.scrollTo("holdings", anchor: .top) } } label: { Text("View portfolio analysis").underline().font(.system(size: 14)) }.buttonStyle(.plain)
            Text("What’s next").font(.system(size: 15, weight: .semibold))
            Text("Review exposure and concentration, check the potential impact of market moves, and bring your other holdings into the same view for a more complete analysis.").font(.system(size: 14)).lineSpacing(5)
            Text("Other items for awareness:").font(.system(size: 14))
            Text("Portfolio coverage | This analysis includes \(holdings.count) holdings across \(accounts.count) \(accounts.count == 1 ? "account" : "accounts"), valued at \(store.amount(total)). Add your global accounts or a statement to include assets held elsewhere.").font(.system(size: 14)).lineSpacing(5)
        }.foregroundStyle(Theme.muted)
    }

    private func refreshAnalysis() {
        analysisTask?.cancel()
        generating = true
        analysisExpanded = true
        analysisTask = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(750)) } catch { return }
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) { generated = true; generating = false }
        }
    }

    private var quickActions: some View {
        HStack(alignment: .top, spacing: 8) {
            quickAction("Trade stocks", icon: "chart.xyaxis.line") { productPreview = "Trade stocks" }
            quickAction("Unit Trusts", icon: "square.stack.3d.up") { productPreview = "Unit Trusts" }
            quickAction("Foreign\nexchange", icon: "dollarsign.arrow.circlepath") { productPreview = "Foreign exchange" }
            quickAction("Manage your\ndocuments", icon: "doc.badge.arrow.up") { addPortfolioPresented = true }
        }
    }
    private func quickAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { VStack(spacing: 8) { Image(systemName: icon).font(.system(size: 24, weight: .light)).foregroundStyle(Theme.red).frame(width: 57, height: 57).background(Color(hex: 0xF3F3F3), in: Circle()); Text(title).font(.system(size: 12, weight: .medium)).lineSpacing(3).multilineTextAlignment(.center) }.frame(maxWidth: .infinity).contentShape(Rectangle()) }.buttonStyle(.plain)
    }
    private var overviewTabs: some View {
        HStack(spacing: 0) { ForEach(["Overview", "Insights"], id: \.self) { item in Button { overview = item } label: { Text(item).font(.system(size: 17, weight: overview == item ? .medium : .regular)).frame(maxWidth: .infinity).padding(.vertical, 15).overlay(alignment: .bottom) { Rectangle().fill(overview == item ? Theme.red : Theme.line).frame(height: overview == item ? 2 : 1) }.contentShape(Rectangle()) }.buttonStyle(.plain) } }
    }
    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("Your holdings").font(.system(size: 20, weight: .semibold)); Spacer(); if !globalView { Menu { ForEach(["Summary", "Allocation analysis", "Risk analysis"], id: \.self) { item in Button(item) { analysis = item } } } label: { Image(systemName: "slider.horizontal.3").font(.system(size: 16)).foregroundStyle(Theme.muted) }.accessibilityLabel("Holdings analysis view") } }
            if globalView { HStack(spacing: 7) { ForEach(["Summary", "Allocation analysis", "Risk analysis"], id: \.self) { item in Pill(title: item, selected: analysis == item) { analysis = item } } } }
            if analysis == "Risk analysis" { RiskPanel(accounts: accounts) }
            else {
                if analysis == "Allocation analysis" {
                    AllocationRing(slices: chartSlices, center: store.amount(total, compact: true))
                    HStack(spacing: 0) {
                        Button { geography = false } label: { Image(systemName: "square.stack.3d.up").frame(width: 44, height: 32).background(geography ? .clear : .white, in: Capsule()).contentShape(Capsule()) }.accessibilityLabel("Group by asset class")
                        Button { geography = true } label: { Image(systemName: "globe").frame(width: 44, height: 32).background(geography ? .white : .clear, in: Capsule()).contentShape(Capsule()) }.accessibilityLabel("Group by region")
                    }.buttonStyle(.plain).font(.system(size: 14)).padding(3).background(Theme.background, in: Capsule())
                } else { allocationBar }
                if geography && analysis == "Allocation analysis" {
                    ForEach(regionSlices, id: \.name) { region in HStack { Rectangle().fill(region.color).frame(width: 10, height: 10); Text(region.name).font(.system(size: 13)); Spacer(); Text(store.amount(region.value)).font(.system(size: 14, weight: .medium)) }.padding(.vertical, 14); Divider() }
                } else { ForEach(allocation, id: \.category) { item in holdingCategoryRow(item.category, value: item.value) } }
            }
        }
    }
    private var allocationBar: some View {
        GeometryReader { geometry in HStack(spacing: 2) { ForEach(allocation, id: \.category) { item in Rectangle().fill(Theme.color(item.category)).frame(width: max(0, geometry.size.width - CGFloat(max(0, allocation.count - 1)) * 2) * item.value / max(total, 1)) } } }.frame(height: 16)
    }
    private func holdingCategoryRow(_ category: AssetClass, value: Double) -> some View {
        let group = holdings.filter { $0.category == category }
        let profit = group.reduce(0) { $0 + $1.currency.convert($1.profit, to: store.currency) }
        return VStack(spacing: 0) {
            Button { withAnimation { expandedCategory = expandedCategory == category ? nil : category } } label: {
                HStack(alignment: .center, spacing: 10) {
                    Rectangle().fill(Theme.color(category)).frame(width: 13, height: 13).frame(maxHeight: .infinity, alignment: .top).padding(.top, 3)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(category.rawValue) (\(total > 0 ? value / total * 100 : 0, specifier: "%.2f")%)").font(.system(size: 14))
                        Text(store.amount(value)).font(.system(size: 17, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    Spacer(minLength: 4)
                    HStack(spacing: 4) { if profit != 0 { Image(systemName: profit >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill").font(.system(size: 8)) }; Text(store.amount(profit)).font(.system(size: 13, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7) }.foregroundStyle(profit >= 0 ? Theme.green : Theme.red)
                    Image(systemName: expandedCategory == category ? "chevron.down" : "chevron.right").font(.system(size: 17, weight: .light))
                }.padding(.vertical, 16).contentShape(Rectangle())
            }.buttonStyle(.plain)
            if expandedCategory == category {
                ForEach(group) { item in HStack { VStack(alignment: .leading, spacing: 4) { Text(item.name).font(.system(size: 12)); Text("\(item.quantity.formatted()) shares · \(item.symbol)").font(.system(size: 10)).foregroundStyle(Theme.muted) }; Spacer(); Text(store.amount(item.currency.convert(item.value, to: store.currency))).font(.system(size: 12)) }.padding(.leading, 23).padding(.bottom, 16) }
            }
            Divider()
        }
    }
    private var regionSlices: [(name: String, value: Double, color: Color)] {
        SampleData.rows("wealth_regions").map { region in
            let name = region.string("name")
            let included = holdings.filter { SampleData.row("currencies", id: $0.currency.rawValue).string("wealthRegion") == name }
            return (name, included.reduce(0) { $0 + $1.currency.convert($1.value, to: store.currency) }, Color(hex: UInt32(region.int("color"))))
        }.filter { $0.1 > 0 }
    }
    private var chartSlices: [(name: String, value: Double, color: Color)] { geography ? regionSlices : allocation.map { ($0.category.rawValue, $0.value, Theme.color($0.category)) } }

    private var stressTest: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stress Test Your Portfolio").font(.system(size: 18, weight: .medium))
            HStack(spacing: 0) { ForEach(SampleData.rows("wealth_scenarios"), id: \.id) { item in Button { scenarioID = item.id } label: { Text(item.string("name")).font(.system(size: 12)).frame(maxWidth: .infinity).padding(.vertical, 10).overlay(alignment: .bottom) { Rectangle().fill(scenarioID == item.id ? Theme.red : Theme.line).frame(height: 1) }.contentShape(Rectangle()) }.buttonStyle(.plain) } }
            Text(scenario.string("description")).font(.system(size: 13))
            Text("Hypothetical decline in portfolio value").font(.system(size: 11)).foregroundStyle(Theme.muted)
            Chart {
                BarMark(x: .value("Portfolio", "Your current portfolio"), y: .value("Decline", total > 0 ? stressLoss / total * 100 : 0)).foregroundStyle(Theme.palette[1]).annotation(position: .top) { Text(String(format: "−%.2f%%", total > 0 ? stressLoss / total * 100 : 0)).font(.system(size: 10)) }
                BarMark(x: .value("Portfolio", "Reference portfolio"), y: .value("Decline", scenario.double("referenceDecline"))).foregroundStyle(Theme.palette[3])
            }.frame(height: 180).chartYScale(domain: 0...12)
            DisclosureGroup("How is risk calculated?") { Text(SampleData.setting("wealthReferenceAssumptions")).font(.system(size: 11)).foregroundStyle(Theme.muted) }.font(.system(size: 12))
        }
    }
    private var stressLoss: Double {
        let targets = SampleData.rows("wealth_scenario_targets").filter { $0.string("scenarioID") == scenarioID }
        return holdings.reduce(0) { result, holding in
            let exposed = targets.contains { target in
                let category = target.string("category")
                let currency = target.string("currency")
                return (category.isEmpty || category == holding.category.rawValue) && (currency.isEmpty || currency == holding.currency.rawValue)
            }
            return result + (exposed ? holding.currency.convert(holding.value, to: store.currency) * scenario.double("shockRate") : 0)
        }
    }
    private var insights: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Your portfolio at a glance").font(.system(size: 20, weight: .medium))
            Text("\(holdings.count) holdings · \(accounts.count) accounts · \(allocation.count) asset classes").font(.system(size: 14)).foregroundStyle(Theme.muted)
            briefAnalysis.font(.system(size: 14)).lineSpacing(5)
            Button("Add other holdings to analyse") { addPortfolioPresented = true }.font(.system(size: 14)).foregroundStyle(Theme.red)
            NavigationLink("Compare your accounts") { CompareView() }.font(.system(size: 14))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var futurePlanner: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Future Planner").font(.system(size: 20, weight: .medium))
            Button { productPreview = "Future Planner" } label: { HStack(spacing: 14) { Image(systemName: "list.bullet.clipboard").font(.system(size: 26, weight: .light)).foregroundStyle(Theme.red); VStack(alignment: .leading, spacing: 5) { Text("You set the goals").font(.system(size: 14, weight: .semibold)); Text("Make a plan for the life you want, with a clear view of your wealth.").font(.system(size: 12)).foregroundStyle(Theme.muted).multilineTextAlignment(.leading) }; Spacer(); Image(systemName: "arrow.right") }.contentShape(Rectangle()) }.buttonStyle(.plain)
        }.padding(.vertical, 8)
    }
}

struct WealthTrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View { HStack(spacing: 4) { configuration.title; configuration.icon } }
}
