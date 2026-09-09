import SwiftUI

struct AccountSelector: View {
    @Environment(PortfolioStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIDs: Set<UUID>
    @State private var draft = Set<UUID>()
    @State private var market = "Singapore"
    private var allIDs: Set<UUID> { Set(store.accounts.map(\.id)) }
    private var localAccounts: [InvestmentAccount] { store.accounts.filter { $0.market == market } }
    private var localIDs: Set<UUID> { Set(localAccounts.map(\.id)) }
    private var allGlobalSelected: Bool { !allIDs.isEmpty && draft == allIDs }
    private var allLocalSelected: Bool { !localIDs.isEmpty && localIDs.isSubset(of: draft) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select accounts").font(.system(size: 22, weight: .regular))
                    .accessibilityIdentifier("accountSelector.title")
                Spacer()
                Button { dismiss() } label: {
                    Label("Close", systemImage: "xmark")
                        .labelStyle(.iconOnly).font(.system(size: 22, weight: .light))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .accessibilityIdentifier("accountSelector.close")
            }
            .padding(.leading, 24).padding(.trailing, 12).padding(.top, 14).padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    selectionRow("All Global Accounts", selected: allGlobalSelected) {
                        draft = allGlobalSelected ? [] : allIDs
                    }
                    .accessibilityIdentifier("accountSelector.global")
                    .padding(.bottom, 12)

                    HStack(spacing: 12) {
                        ForEach(["Singapore", "Hong Kong"], id: \.self) { item in
                            Button { market = item } label: {
                                Text(item)
                                    .font(.system(size: 14, weight: .medium))
                                    .padding(.horizontal, 16)
                                    .frame(minWidth: 60, minHeight: 34)
                                    .foregroundStyle(market == item ? .white : Theme.ink)
                                    .background(market == item ? Theme.ink : .white, in: Capsule())
                                    .overlay(Capsule().stroke(market == item ? .clear : Theme.line))
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain).accessibilityLabel(item)
                            .accessibilityAddTraits(market == item ? .isSelected : [])
                            .accessibilityIdentifier("accountSelector.market.\(item == "Singapore" ? "sg" : "hk")")
                        }
                    }.padding(.bottom, 12)

                    selectionRow("All Accounts in \(market == "Singapore" ? "SG" : "HK")", selected: allLocalSelected) {
                        if allLocalSelected { draft.subtract(localIDs) }
                        else { draft.formUnion(localIDs) }
                    }
                    .accessibilityIdentifier("accountSelector.marketAll.\(market == "Singapore" ? "sg" : "hk")")

                    ForEach(localAccounts) { account in
                        Button {
                            if draft.contains(account.id) { draft.remove(account.id) }
                            else { draft.insert(account.id) }
                        } label: {
                            HStack(spacing: 12) {
                                BankMark(bank: account.institution, size: 34)
                                    .frame(width: 44, height: 32).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(account.name).font(.system(size: 14)).lineLimit(2)
                                    Text(account.accountNumber ?? "\(account.currency.rawValue) account")
                                        .font(.system(size: 12)).foregroundStyle(Theme.muted)
                                }
                                Spacer(minLength: 8)
                                selectionMark(draft.contains(account.id))
                            }
                            .padding(.vertical, 17).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(draft.contains(account.id) ? "Selected" : "Not selected")
                        .accessibilityIdentifier("accountSelector.account.\(account.id.uuidString)")
                        Divider()
                    }
                    if localAccounts.isEmpty {
                        Text("No accounts in this market.").font(.system(size: 14))
                            .foregroundStyle(Theme.muted).padding(.vertical, 28)
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 20)
            }

            PrimaryButton(title: "Confirm") {
                selectedIDs = allGlobalSelected ? [] : draft
                dismiss()
            }
            .disabled(draft.isEmpty).opacity(draft.isEmpty ? 0.45 : 1)
            .padding(20).background(.white)
        }
        .foregroundStyle(Theme.ink).background(.white)
        .presentationDetents([.large]).presentationDragIndicator(.hidden).presentationCornerRadius(8)
        .onAppear {
            draft = selectedIDs.isEmpty ? allIDs : selectedIDs.intersection(allIDs)
            let selectedAccounts = store.accounts.filter { draft.contains($0.id) }
            if !selectedAccounts.isEmpty && selectedAccounts.allSatisfy({ $0.market == "Hong Kong" }) { market = "Hong Kong" }
        }
    }

    private func selectionRow(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.system(size: 14))
                Spacer()
                selectionMark(selected)
            }.frame(minHeight: 52).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }

    private func selectionMark(_ selected: Bool) -> some View {
        Image(systemName: selected ? "largecircle.fill.circle" : "circle")
            .font(.system(size: 22, weight: .light))
            .foregroundStyle(selected ? Theme.ink : Theme.muted)
            .accessibilityHidden(true)
    }
}

struct AccountsView: View {
    @Environment(PortfolioStore.self) private var store
    @State private var search = ""
    @State private var market = "All"
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("All your wealth. One place.").font(.system(size: 25, weight: .medium))
                    Text("Manage your accounts across banks and markets.").font(.system(size: 14)).foregroundStyle(Theme.muted)
                }.padding(.top, 10)
                HStack { ForEach(["All", "Singapore", "Hong Kong"], id: \.self) { item in Pill(title: item, selected: market == item) { market = item } } }
                ForEach(filtered) { account in
                    NavigationLink { AccountDetailView(accountID: account.id) } label: {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack { BankMark(bank: account.institution); Text(account.institution).font(.system(size: 13, weight: .medium)); Spacer(); Text(account.market).font(.system(size: 11)).foregroundStyle(Theme.muted); Image(systemName: "chevron.right").font(.system(size: 12)) }
                            Text(account.name).font(.system(size: 16, weight: .medium))
                            if let number = account.accountNumber { Text(number).font(.system(size: 12)).foregroundStyle(Theme.muted) }
                            HStack(alignment: .bottom) { VStack(alignment: .leading, spacing: 5) { Text("Market value · \(store.currency.rawValue)").font(.system(size: 11)).foregroundStyle(Theme.muted); Text(store.amount(account.value(in: store.currency))).font(.system(size: 23, weight: .semibold)).minimumScaleFactor(0.7) }; Spacer(); ReturnLabel(value: account.returnRate) }
                            HStack { Text("\(account.holdings.count) holdings"); Spacer(); Text("Demo account") }.font(.system(size: 11)).foregroundStyle(Theme.muted)
                        }.padding(18).background(.white).overlay(Rectangle().stroke(Theme.line)).overlay(alignment: .top) { Rectangle().fill(Theme.accountColor(account.colorIndex)).frame(height: 3) }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                if filtered.isEmpty { EmptyPortfolio(title: store.accounts.isEmpty ? "No accounts yet" : "No matching accounts", message: "Add an account or change your filters.") }
                NavigationLink { AddAccountFlow() } label: { Label("Add an account", systemImage: "plus").frame(maxWidth: .infinity).padding(17).foregroundStyle(.white).background(Theme.red).contentShape(Rectangle()) }.buttonStyle(.plain).accessibilityIdentifier("addAccount")
                DemoFootnote()
            }.padding(20)
        }.background(Theme.background.opacity(0.55)).navigationTitle("Your accounts").navigationBarTitleDisplayMode(.inline).searchable(text: $search, prompt: "Search accounts or banks")
    }
    private var filtered: [InvestmentAccount] { store.accounts.filter { (market == "All" || $0.market == market) && (search.isEmpty || ($0.name + $0.institution).localizedCaseInsensitiveContains(search)) } }
}

struct AccountDetailView: View {
    @Environment(PortfolioStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var accountID: UUID
    @State private var editing = false
    @State private var adding = false
    @State private var holding: Holding?
    @State private var deleteConfirm = false
    private var account: InvestmentAccount? { store.accounts.first { $0.id == accountID } }
    var body: some View {
        Group {
            if let account {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack { BankMark(bank: account.institution); Text(account.institution).font(.subheadline); Spacer(); Text(account.market).font(.caption).foregroundStyle(Theme.muted) }
                        Text(account.name).font(.system(size: 25, weight: .medium))
                        if let number = account.accountNumber { Text(number).font(.system(size: 13)).foregroundStyle(Theme.muted) }
                        VStack(alignment: .leading, spacing: 10) { Text("Total market value · \(store.currency.rawValue)").font(.caption).foregroundStyle(Theme.muted); Text(store.amount(account.value(in: store.currency))).font(.system(size: 32, weight: .semibold)); HStack { Text("Unrealised gain/loss").font(.caption); Spacer(); Text(store.amount(account.profit(in: store.currency))).font(.subheadline); ReturnLabel(value: account.returnRate) } }.padding(18).background(Theme.background)
                        AllocationRing(slices: store.allocation(for: [account]).map { ($0.category.rawValue, $0.value, Theme.color($0.category)) }, subtitle: "Holdings", center: "\(account.holdings.count)")
                        SectionTitle(title: "Your holdings") { Button("Add", systemImage: "plus") { adding = true }.font(.system(size: 13)) }
                        if account.holdings.isEmpty { EmptyPortfolio(title: "No holdings yet", message: "Add your first holding to build this portfolio.") }
                        ForEach(account.holdings) { item in
                            Button { holding = item } label: {
                                HStack(spacing: 12) { Image(systemName: item.category.icon).font(.system(size: 17)).foregroundStyle(Theme.color(item.category)).frame(width: 38, height: 38).background(Theme.background); VStack(alignment: .leading, spacing: 5) { Text(item.name).font(.system(size: 14)); Text(item.symbol + " · " + item.category.rawValue).font(.system(size: 11)).foregroundStyle(Theme.muted) }; Spacer(); VStack(alignment: .trailing, spacing: 5) { Text(store.amount(item.currency.convert(item.value, to: store.currency))).font(.system(size: 13, weight: .medium)); ReturnLabel(value: item.returnRate) } }.padding(.vertical, 9).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            Divider()
                        }
                        if !account.note.isEmpty { Text(account.note).font(.subheadline).foregroundStyle(Theme.muted) }
                        Button("Remove account", role: .destructive) { deleteConfirm = true }.font(.subheadline).padding(.top, 12)
                        DemoFootnote()
                    }.padding(20)
                }.sheet(isPresented: $editing) { AccountEditor(account: account) }.sheet(isPresented: $adding) { HoldingEditor(accountID: account.id, currency: account.currency) }.sheet(item: $holding) { item in HoldingEditor(accountID: account.id, currency: item.currency, existing: item) }
            } else { EmptyPortfolio(title: "Account unavailable", message: "This account has been removed.") }
        }.navigationTitle("Account details").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { editing = true } } }
            .confirmationDialog("Remove this account and its holdings?", isPresented: $deleteConfirm, titleVisibility: .visible) { Button("Remove account", role: .destructive) { store.deleteAccount(id: accountID); dismiss() } } message: { Text("This only removes the local demo portfolio.") }
    }
}

struct AccountEditor: View {
    @Environment(PortfolioStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var account: InvestmentAccount
    var body: some View {
        NavigationStack {
            Form {
                Section("Account details") { TextField("Account name", text: $account.name); TextField("Bank / institution", text: $account.institution); Picker("Market", selection: $account.market) { Text("Singapore").tag("Singapore"); Text("Hong Kong").tag("Hong Kong") }; Picker("Account currency", selection: $account.currency) { ForEach(Currency.allCases) { Text($0.rawValue).tag($0) } } }
                Section("Notes") { TextField("Optional note", text: $account.note, axis: .vertical).lineLimit(3...5) }
            }.navigationTitle("Edit account").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { account.name = account.name.trimmingCharacters(in: .whitespacesAndNewlines); store.save(account); dismiss() }.disabled(account.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || account.institution.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }
        }
    }
}

struct HoldingEditor: View {
    @Environment(PortfolioStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let accountID: UUID
    @State var currency: Currency
    var existing: Holding?
    @State private var name = ""
    @State private var symbol = ""
    @State private var category = AssetClass.stock
    @State private var quantity = ""
    @State private var price = ""
    @State private var cost = ""
    @State private var deleting = false
    private var valid: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let q = Double(quantity), let p = Double(price), let c = Double(cost) else { return false }
        return q.isFinite && p.isFinite && c.isFinite && q > 0 && p >= 0 && c >= 0 && (q * p).isFinite && (q * c).isFinite && q * max(p, c) < 1e14
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Holding") { TextField("Name", text: $name); TextField("Symbol", text: $symbol).textInputAutocapitalization(.characters); Picker("Asset class", selection: $category) { ForEach(AssetClass.allCases) { Text($0.rawValue).tag($0) } }; Picker("Currency", selection: $currency) { ForEach(Currency.allCases) { Text($0.rawValue).tag($0) } } }
                Section { TextField("Quantity", text: $quantity).keyboardType(.decimalPad); TextField("Current unit price", text: $price).keyboardType(.decimalPad); TextField("Average unit cost", text: $cost).keyboardType(.decimalPad) } header: { Text("Valuation") } footer: { Text("Enter positive quantity and non-negative prices. For cash, use the balance as quantity and 1 for both prices. Zero cost is allowed; percentage return will be unavailable.") }
                if let existing { Section { Button("Remove holding", role: .destructive) { deleting = true }.confirmationDialog("Remove \(existing.name)?", isPresented: $deleting, titleVisibility: .visible) { Button("Remove holding", role: .destructive) { store.deleteHolding(id: existing.id, accountID: accountID); dismiss() } } } }
            }.navigationTitle(existing == nil ? "Add holding" : "Edit holding").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(!valid) } }
        }.onAppear { if let existing { name = existing.name; symbol = existing.symbol; category = existing.category; quantity = String(existing.quantity); price = String(existing.price); cost = String(existing.averageCost) } }
    }
    private func save() {
        guard valid, let q = Double(quantity), let p = Double(price), let c = Double(cost) else { return }
        var item = Holding(name: name.trimmingCharacters(in: .whitespacesAndNewlines), symbol: symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), category: category, currency: currency, quantity: q, price: p, averageCost: c)
        if let existing { item.id = existing.id; item.region = existing.region; item.sector = existing.sector }
        store.saveHolding(item, accountID: accountID); dismiss()
    }
}
