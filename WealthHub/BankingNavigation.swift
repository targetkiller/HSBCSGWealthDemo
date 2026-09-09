import SwiftUI

enum BankingSection: String, CaseIterable, Identifiable {
    case home, pay, cards, wealth

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct BankingHeader: View {
    @Binding var selection: BankingSection
    var openMenu: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button { selection = .home } label: {
                Image(systemName: "house")
                    .font(.system(size: 25, weight: .light))
                    .frame(width: 44, height: 48)
                    .overlay(alignment: .bottom) {
                        if selection == .home { selectionIndicator.padding(.horizontal, 8) }
                    }
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Home")
            .accessibilityAddTraits(selection == .home ? .isSelected : [])
            .accessibilityIdentifier("banking.tab.home")

            Rectangle()
                .fill(Theme.muted)
                .frame(width: 1, height: 28)
                .padding(.leading, 1)
                .padding(.trailing, 17)
                .accessibilityHidden(true)

            HStack(spacing: 23) {
                ForEach([BankingSection.pay, .cards, .wealth]) { section in
                    Button { selection = section } label: {
                        Text(section.title)
                            .font(.system(size: 20, weight: .semibold))
                            .fixedSize()
                            .frame(height: 48)
                            .overlay(alignment: .bottom) {
                                if selection == section { selectionIndicator.padding(.horizontal, 2) }
                            }
                            .contentShape(Rectangle())
                    }
                    .accessibilityAddTraits(selection == section ? .isSelected : [])
                    .accessibilityIdentifier("banking.tab.\(section.rawValue)")
                }
            }

            Spacer(minLength: 10)

            Button(action: openMenu) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 25, weight: .light))
                    .frame(width: 44, height: 48)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Menu")
            .accessibilityIdentifier("banking.menu.button")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
        .background(.white)
    }

    private var selectionIndicator: some View {
        Rectangle().fill(Theme.red).frame(height: 4)
    }
}

struct BankingMenuView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Wealth") {
                    NavigationLink { AccountsView() } label: {
                        Label("Your accounts", systemImage: "building.columns")
                    }
                    .accessibilityIdentifier("banking.menu.accounts")

                    NavigationLink { CompareView() } label: {
                        Label("Compare accounts", systemImage: "chart.bar.xaxis")
                    }
                    .accessibilityIdentifier("banking.menu.compare")

                    NavigationLink { AddAccountFlow() } label: {
                        Label("Add an account", systemImage: "plus.circle")
                    }
                    .accessibilityIdentifier("banking.menu.addAccount")
                }

                Section {
                    NavigationLink { SettingsView() } label: {
                        Label("Settings", systemImage: "slider.horizontal.3")
                    }
                    .accessibilityIdentifier("banking.menu.settings")
                }
            }
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("banking.menu.close")
                }
            }
        }
    }
}

struct BankingPlaceholderView: View {
    let section: BankingSection
    var openWealth: () -> Void

    private var symbol: String {
        switch section {
        case .home: "house"
        case .pay: "arrow.left.arrow.right"
        case .cards: "creditcard"
        case .wealth: "chart.pie"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(section == .home ? "Welcome to HSBC" : section.title)
                    .font(.system(size: 28, weight: .light))
                    .padding(.top, 26)

                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: symbol)
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(Theme.red)
                    Text("Your banking, in one place")
                        .font(.system(size: 21, weight: .medium))
                    Text("Explore your accounts, holdings and portfolio performance in Wealth.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.muted)
                        .lineSpacing(5)
                    Button(action: openWealth) {
                        HStack {
                            Text("Explore Wealth")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 6)
                        .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("banking.preview.openWealth")
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.background)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
    }
}
