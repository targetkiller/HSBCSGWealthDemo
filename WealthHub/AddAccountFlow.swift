import SwiftUI
import UniformTypeIdentifiers

struct AddAccountFlow: View {
    @Environment(PortfolioStore.self) private var store
    @State private var bank = "DBS"
    @State private var market = "Singapore"
    @State private var name = ""
    @State private var step = 0
    @State private var consent = false
    @State private var addedID: UUID?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if step == 2 {
                    VStack(spacing: 18) { Image(systemName: "checkmark.circle").font(.system(size: 64, weight: .light)).foregroundStyle(Theme.green); Text("Your account is ready").font(.system(size: 25, weight: .medium)); Text("Your demo portfolio has been added to Wealth Hub.").font(.subheadline).foregroundStyle(Theme.muted).multilineTextAlignment(.center) }.frame(maxWidth: .infinity).padding(.vertical, 45)
                    if let addedID { NavigationLink { AccountDetailView(accountID: addedID) } label: { Text("View account").frame(maxWidth: .infinity).padding(17).foregroundStyle(.white).background(Theme.red).contentShape(Rectangle()) }.buttonStyle(.plain) }
                } else if step == 1 {
                    Image(systemName: "link.circle").font(.system(size: 48, weight: .light)).foregroundStyle(Theme.red)
                    Text("Connect to \(bank)").font(.system(size: 27, weight: .medium))
                    Text("Bring your wealth together").font(.headline)
                    Text("Preview how a linked bank account appears in your portfolio. This demo creates sample holdings locally. No credentials are requested or sent to a bank.").font(.subheadline).foregroundStyle(Theme.muted).lineSpacing(5)
                    VStack(alignment: .leading, spacing: 20) { Label("Account balances", systemImage: "banknote"); Label("Investment holdings", systemImage: "chart.pie"); Label("Portfolio allocation", systemImage: "chart.bar") }.font(.system(size: 15)).padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Theme.background)
                    Toggle("I understand this is a demo connection", isOn: $consent).font(.system(size: 13)).tint(Theme.red)
                    PrimaryButton(title: "Connect demo account") { connect() }.disabled(!consent).opacity(consent ? 1 : 0.4)
                } else {
                    Text("Add your other accounts").font(.system(size: 27, weight: .medium))
                    Text("See your full financial picture, across banks and markets.").font(.subheadline).foregroundStyle(Theme.muted)
                    NavigationLink { StatementImportView() } label: { HStack { Image(systemName: "doc.badge.arrow.up").font(.title2).foregroundStyle(Theme.red); VStack(alignment: .leading, spacing: 6) { Text("Upload statement").font(.system(size: 16, weight: .medium)); Text("Import holdings from a CSV file").font(.system(size: 12)).foregroundStyle(Theme.muted) }; Spacer(); Image(systemName: "chevron.right") }.padding(18).background(Theme.background).contentShape(Rectangle()) }.buttonStyle(.plain)
                    Text("Connect to another bank").font(.system(size: 18, weight: .medium))
                    HStack { ForEach(["Singapore", "Hong Kong"], id: \.self) { item in Pill(title: item, selected: market == item) { market = item } } }
                    ForEach(["DBS", "HSBC", "OCBC", "UOB", "Standard Chartered"], id: \.self) { item in
                        Button { bank = item } label: { HStack { BankMark(bank: item); Text(item).font(.system(size: 15)); Spacer(); Image(systemName: bank == item ? "largecircle.fill.circle" : "circle").font(.system(size: 23)) }.padding(.vertical, 12).contentShape(Rectangle()) }.buttonStyle(.plain)
                        Divider()
                    }
                    TextField("Account nickname (optional)", text: $name).textFieldStyle(.roundedBorder)
                    PrimaryButton(title: "Continue") { step = 1 }
                    Button {
                        let account = InvestmentAccount(name: name.isEmpty ? "My investment account" : name, institution: bank, currency: market == "Singapore" ? .SGD : .HKD, colorIndex: store.accounts.count, market: market)
                        store.save(account); addedID = account.id; step = 2
                    } label: {
                        Text("Create an empty account manually").font(.system(size: 13))
                            .frame(maxWidth: .infinity).contentShape(Rectangle())
                    }
                }
                DemoFootnote()
            }.padding(20)
        }.navigationTitle("Add account").navigationBarTitleDisplayMode(.inline)
    }
    private func connect() {
        var account = DemoData.accounts[2]
        account.id = UUID(); account.institution = bank; account.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "\(bank) Investment Account" : name
        account.market = market; account.currency = market == "Singapore" ? .SGD : .HKD; account.colorIndex = store.accounts.count
        account.holdings = account.holdings.map { holding in var copy = holding; copy.id = UUID(); return copy }
        store.save(account); addedID = account.id; step = 2
    }
}

struct StatementImportView: View {
    @Environment(PortfolioStore.self) private var store
    @State private var picking = false
    @State private var holdings: [Holding] = []
    @State private var error: String?
    @State private var filename = ""
    @State private var accountName = "Imported portfolio"
    @State private var importedID: UUID?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(importedID == nil ? "Your investments, together" : "Statement imported").font(.system(size: 26, weight: .medium))
                Text("Import a CSV statement to add another portfolio. Files are processed on this device.").font(.subheadline).foregroundStyle(Theme.muted)
                if let importedID {
                    Image(systemName: "checkmark.circle").font(.system(size: 58)).foregroundStyle(Theme.green).frame(maxWidth: .infinity).padding(30)
                    NavigationLink { AccountDetailView(accountID: importedID) } label: { Label("View imported account", systemImage: "arrow.right").frame(maxWidth: .infinity).padding(16).foregroundStyle(.white).background(Theme.red).contentShape(Rectangle()) }.buttonStyle(.plain)
                } else {
                    Button { picking = true } label: { VStack(spacing: 14) { Image(systemName: "doc.badge.arrow.up").font(.system(size: 38, weight: .light)); Text("Select a CSV statement").font(.system(size: 16, weight: .medium)); Text("CSV · Up to 1 MB / 1,000 holdings").font(.caption).foregroundStyle(Theme.muted) }.frame(maxWidth: .infinity).padding(.vertical, 36).background(Theme.background).overlay(Rectangle().stroke(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [6]))).contentShape(Rectangle()) }.buttonStyle(.plain)
                    Button { do { holdings = try StatementParser.parse(StatementParser.template); filename = "Sample statement.csv"; error = nil } catch { self.error = error.localizedDescription } } label: {
                        Text("Try a sample statement").font(.subheadline).frame(maxWidth: .infinity).contentShape(Rectangle())
                    }
                    DisclosureGroup("CSV format and supported values") { Text("Columns: name, symbol, category, currency, quantity, price, averageCost\n\nCategories: \(AssetClass.allCases.map(\.rawValue).joined(separator: ", "))\nCurrencies: SGD, USD, HKD, CNY\n\nUse plain comma-separated values without quoted commas. PDF/OCR import is not included in this demo.").font(.caption).foregroundStyle(Theme.muted).padding(.top, 10) }
                    if let error { Label(error, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(Theme.red) }
                    if !holdings.isEmpty {
                        Label(filename, systemImage: "checkmark.circle").font(.subheadline).foregroundStyle(Theme.green)
                        TextField("Account name", text: $accountName).textFieldStyle(.roundedBorder)
                        Text("Preview · \(holdings.count) holdings").font(.headline)
                        ForEach(holdings) { holding in HStack { VStack(alignment: .leading) { Text(holding.name).font(.subheadline); Text(holding.symbol).font(.caption).foregroundStyle(Theme.muted) }; Spacer(); Text(holding.currency.format(holding.value)).font(.subheadline) }.padding(.vertical, 7) }
                        PrimaryButton(title: "Confirm import") {
                            let account = InvestmentAccount(name: accountName.trimmingCharacters(in: .whitespacesAndNewlines), institution: "Statement", currency: .SGD, colorIndex: store.accounts.count, holdings: holdings)
                            store.save(account); importedID = account.id
                        }.disabled(accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }.padding(20)
        }.navigationTitle("Upload statement").navigationBarTitleDisplayMode(.inline)
            .fileImporter(isPresented: $picking, allowedContentTypes: [.commaSeparatedText], allowsMultipleSelection: false) { result in
                do {
                    guard let url = try result.get().first else { return }
                    let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                    guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 1_000_000 else { throw StatementParser.ParseError.invalid("Choose a file smaller than 1 MB.") }
                    let parsed = try StatementParser.parse(String(contentsOf: url, encoding: .utf8)); holdings = parsed; filename = url.lastPathComponent; error = nil
                } catch { holdings = []; self.error = error.localizedDescription }
            }
    }
}
