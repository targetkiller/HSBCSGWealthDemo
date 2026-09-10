import SwiftUI
import Charts

struct CompareView: View {
    @Environment(PortfolioStore.self) private var store
    @State private var selected = Set<UUID>()
    @State private var metric = "Market value"
    private var accounts: [InvestmentAccount] { store.accounts.filter { selected.contains($0.id) } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("A side-by-side perspective").font(.system(size: 25, weight: .medium))
                Text("Select 2–3 accounts to compare in \(store.currency.rawValue).").font(.system(size: 14)).foregroundStyle(Theme.muted)
                ForEach(store.accounts) { account in
                    Button {
                        if selected.contains(account.id) { selected.remove(account.id) } else if selected.count < 3 { selected.insert(account.id) }
                    } label: { HStack(spacing: 12) { Image(systemName: selected.contains(account.id) ? "checkmark.square.fill" : "square").font(.system(size: 22)).foregroundStyle(selected.contains(account.id) ? Theme.red : Theme.muted); BankMark(bank: account.institution); VStack(alignment: .leading, spacing: 4) { Text(account.name).font(.system(size: 13, weight: .medium)); Text(account.institution + " · " + account.market).font(.system(size: 11)).foregroundStyle(Theme.muted) }; Spacer() }.padding(13).background(selected.contains(account.id) ? Theme.background : .white).contentShape(Rectangle()) }.buttonStyle(.plain).disabled(selected.count == 3 && !selected.contains(account.id))
                }
                if accounts.count < 2 { EmptyPortfolio(title: "Choose at least two accounts", message: "Compare value, return and allocation across your portfolios.") }
                else {
                    HStack { Text("Portfolio comparison").font(.system(size: 18, weight: .medium)); Spacer(); Menu(store.currency.rawValue) { ForEach(Currency.allCases) { currency in Button(currency.rawValue) { store.currency = currency } } }.font(.system(size: 12)) }
                    Picker("Metric", selection: $metric) { Text("Market value").tag("Market value"); Text("Return %").tag("Return %") }.pickerStyle(.segmented)
                    if store.hideAmounts && metric == "Market value" {
                        Label("Balances are hidden", systemImage: "eye.slash").font(.subheadline).foregroundStyle(Theme.muted).frame(maxWidth: .infinity).frame(height: 220)
                    } else {
                    Chart(Array(accounts.enumerated()), id: \.element.id) { index, account in
                        BarMark(x: .value("Account", "\(index + 1). \(account.institution)"), y: .value("Value", metric == "Market value" ? account.value(in: store.currency) : account.returnRate ?? 0)).foregroundStyle(Theme.accountColor(account.colorIndex))
                            .annotation(position: .top) { Text(metric == "Market value" ? store.amount(account.value(in: store.currency), compact: true) : account.returnRate.map { String(format: "%.2f%%", $0) } ?? "N/A").font(.system(size: 10)) }
                    }.frame(height: 220).padding(.top, 16)
                    }
                    comparisonTable
                    Text("Asset allocation").font(.system(size: 18, weight: .medium))
                    ForEach(accounts) { account in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(account.name).font(.system(size: 13, weight: .medium))
                            let allocation = store.allocation(for: [account])
                            let total = account.value(in: store.currency)
                            GeometryReader { geo in HStack(spacing: 1) { ForEach(allocation, id: \.category) { item in Rectangle().fill(Theme.color(item.category)).frame(width: max(0, (geo.size.width - CGFloat(max(0, allocation.count - 1))) * item.value / max(total, 1))) } } }.frame(height: 18)
                            if total == 0 { Text("No holdings").font(.caption).foregroundStyle(Theme.muted) }
                            ForEach(allocation, id: \.category) { item in HStack { Circle().fill(Theme.color(item.category)).frame(width: 7, height: 7); Text(item.category.rawValue); Spacer(); Text(String(format: "%.1f%%", total > 0 ? item.value / total * 100 : 0)) }.font(.system(size: 11)) }
                        }.padding(16).background(Theme.background)
                    }
                    Text("Returns compare unrealised gain/loss against invested cost. They do not adjust for investment dates or cash flows.").font(.system(size: 11)).foregroundStyle(Theme.muted)
                }
                DemoFootnote()
            }.padding(20)
        }.navigationTitle("Compare accounts").navigationBarTitleDisplayMode(.inline)
            .onAppear { if selected.isEmpty { selected = Set(store.accounts.prefix(2).map(\.id)) } }
            .onChange(of: store.accounts.map(\.id)) { _, ids in selected.formIntersection(ids) }
    }
    private var comparisonTable: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 18) {
                GridRow { Text("Account").font(.caption).foregroundStyle(Theme.muted).frame(width: 100, alignment: .leading); ForEach(accounts) { account in Text(account.name).font(.system(size: 12, weight: .medium)).frame(width: 125, alignment: .leading) } }
                Divider().gridCellUnsizedAxes(.horizontal)
                tableRow("Market value") { store.amount($0.value(in: store.currency)) }
                tableRow("Invested cost") { store.amount($0.cost(in: store.currency)) }
                tableRow("Gain / loss") { store.amount($0.profit(in: store.currency)) }
                tableRow("Return") { $0.returnRate.map { String(format: "%+.2f%%", $0) } ?? "N/A" }
                tableRow("Holdings") { String($0.holdings.count) }
                tableRow("Market") { $0.market }
            }.padding(16).background(Theme.background)
        }
    }
    private func tableRow(_ title: String, value: @escaping (InvestmentAccount) -> String) -> some View {
        GridRow { Text(title).font(.system(size: 12)).foregroundStyle(Theme.muted).frame(width: 100, alignment: .leading); ForEach(accounts) { account in Text(value(account)).font(.system(size: 12, weight: .medium)).frame(width: 125, alignment: .leading) } }
    }
}

struct SettingsView: View {
    @Environment(PortfolioStore.self) private var store
    @State private var resetConfirm = false
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }
    var body: some View {
        @Bindable var store = store
        Form {
            Section("Display") { Picker("Reporting currency", selection: $store.currency) { ForEach(Currency.allCases) { Text($0.rawValue).tag($0) } }; Toggle("Hide balances", isOn: $store.hideAmounts) }
            Section("About this demo") { LabeledContent("Version", value: appVersion).accessibilityIdentifier("settings.version"); LabeledContent("Accounts", value: String(store.accounts.count)); LabeledContent("Holdings", value: String(store.holdingCount)); Text("Built from the Wealth Hub Figma concepts. All bank connections and analysis are illustrative. Changes are saved locally for this session. Fully close and reopen the app to start again with the initial HSBC accounts.").font(.footnote).foregroundStyle(Theme.muted) }
            Section {
                NavigationLink("Privacy policy") { DemoPrivacyPolicyView() }
                    .accessibilityIdentifier("settings.privacy")
            }
            Section("Fixed demo exchange rates") { ForEach(Currency.allCases) { currency in LabeledContent("1 \(currency.rawValue)", value: String(format: "%.4f SGD", currency.convert(1, to: .SGD))) } }
            Section { Button("Restore demo data", role: .destructive) { resetConfirm = true } } footer: { Text("Replaces local accounts and holdings with the original sample portfolios.") }
        }.navigationTitle("Settings").navigationBarTitleDisplayMode(.inline).confirmationDialog("Restore all demo data?", isPresented: $resetConfirm, titleVisibility: .visible) { Button("Restore demo data", role: .destructive) { store.reset() } }
    }
}

private struct DemoPrivacyPolicyView: View {
    var body: some View {
        List {
            Section {
                Text("This prototype uses local demo data and does not connect to a bank or provide banking services.")
                Text("Effective date: 9 September 2026").font(.caption).foregroundStyle(Theme.muted)
            }
            Section("Data on your device") {
                Text("Portfolio names, accounts, holdings, and preferences are stored on your device. There is no app account or bank sign-in. The app does not send portfolios or usage data to the project maintainers and has no advertising, analytics, or tracking SDKs.")
            }
            Section("Statements, photos, and analysis") {
                Text("Selected CSV files, PDFs, and images are processed on your device. Text recognition uses Apple's on-device frameworks. Extracted holdings are saved when you confirm them. Camera or photo access is requested for the import action you choose. Statements and photos are not uploaded to a server.")
                Text("Portfolio calculations and generated demo analysis run locally, without a remote AI service.")
            }
            Section("Retention and deletion") {
                Text("Saved portfolios and preferences remain during the current app session, including while the app is in the background. Fully closing and reopening the app replaces them with the initial demo accounts. You can also remove accounts or restore demo data in Settings. Camera and photo permissions can be changed in iOS Settings.")
            }
            Section("External services") {
                Text("Apple distributes TestFlight builds and may collect beta feedback or diagnostics under its own terms. The project's GitHub support page follows GitHub's privacy policy. These services are separate from the demo's local portfolio storage.")
            }
            Section("Contact") {
                Link("Project support", destination: URL(string: "https://github.com/targetkiller/HSBCSGWealthDemo/issues")!)
            }
        }
        .navigationTitle("Privacy policy")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("privacy.policy")
    }
}
