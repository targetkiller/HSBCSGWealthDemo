import SwiftUI

@main
struct WealthHubApp: App {
    @State private var store: PortfolioStore? = {
        guard SampleData.configurationError == nil else { return nil }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            let defaults = UserDefaults(suiteName: "wealthhub.ui-tests")!
            defaults.removePersistentDomain(forName: "wealthhub.ui-tests")
            return PortfolioStore(defaults: defaults)
        }
        #endif
        return PortfolioStore()
    }()
    var body: some Scene {
        WindowGroup {
            if let store {
                RootView().environment(store).tint(Theme.red).preferredColorScheme(.light)
                    .alert("Local storage", isPresented: Binding(get: { store.storageError != nil }, set: { if !$0 { store.storageError = nil } })) {
                        Button("OK") { store.storageError = nil }
                    } message: { Text(store.storageError ?? "") }
            } else {
                ContentUnavailableView {
                    Label("Check Sample configuration", systemImage: "exclamationmark.triangle")
                } description: {
                    Text((SampleData.configurationError ?? "Unable to load sample data.") + "\n\nCorrect the CSV in Sample, rebuild, and reopen the app. Your saved portfolio has been preserved.")
                }
                .preferredColorScheme(.light)
            }
        }
    }
}

struct RootView: View {
    @State private var section: BankingSection = .wealth
    @State private var menuPresented = false

    var body: some View {
        NavigationStack {
            Group {
                if section == .wealth {
                    WealthView()
                } else {
                    BankingPlaceholderView(section: section) { section = .wealth }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white)
            .safeAreaInset(edge: .top, spacing: 0) {
                BankingHeader(selection: $section) { menuPresented = true }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .foregroundStyle(Theme.ink)
        .sheet(isPresented: $menuPresented) { BankingMenuView() }
    }
}
