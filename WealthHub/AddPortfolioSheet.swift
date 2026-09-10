import SwiftUI
import UIKit
import UniformTypeIdentifiers
import AVFoundation

struct AddPortfolioSheet: View {
    @Environment(PortfolioStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var onComplete: (Set<UUID>) -> Void

    @State private var activeStep: PortfolioStep?
    @State private var path: [PortfolioStep] = []
    @State private var rootHeight: CGFloat = 280
    @State private var selectedHSBC = Set<UUID>()
    @State private var extractedHoldings: [Holding] = []
    @State private var statementSource = ""
    @State private var statementAccount = SampleData.makeAccount(template: "statement-review")
    @State private var accountEvidence: String?
    @State private var extractionWarnings: [String] = []
    @State private var completed = false

    private var hsbcAccounts: [InvestmentAccount] {
        store.accounts.filter { $0.institution.localizedCaseInsensitiveContains("HSBC") }
    }

    var body: some View {
        portfolioOptions
            .foregroundStyle(Theme.ink)
            .presentationDetents([.height(rootHeight)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(8)
            .sheet(item: $activeStep, onDismiss: { path.removeAll() }) { step in
                // Present the destination at its final height. Resizing the chooser while
                // pushing used to leave no space above the destination's bottom actions.
                NavigationStack(path: $path) {
                    destination(for: step)
                        .toolbar { flowToolbar }
                        .navigationDestination(for: PortfolioStep.self) { nextStep in
                            destination(for: nextStep)
                                .toolbar { flowToolbar }
                        }
                }
                .foregroundStyle(Theme.ink)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(8)
            }
    }

    @ToolbarContentBuilder
    private var flowToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if path.isEmpty {
                Button("Back", systemImage: "chevron.left") { activeStep = nil }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(Theme.ink)
                    .accessibilityIdentifier("portfolio.flow.back")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Close", systemImage: "xmark") { dismiss() }
                .labelStyle(.iconOnly)
                .foregroundStyle(Theme.ink)
                .accessibilityIdentifier("portfolio.add.close")
        }
    }

    private var portfolioOptions: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Add a portfolio")
                .font(.system(size: 24, weight: .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .topTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 19, weight: .light))
                            .frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .offset(x: 10, y: -10)
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("portfolio.add.close")
                }
                .padding(.bottom, 16)
            Text("Connect an account or upload your portfolio data to get artificial intelligence analysis.")
                .font(.system(size: 16))
                .foregroundStyle(Theme.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)

            portfolioOption("Add my global HSBC account", icon: "creditcard", id: "hsbc") {
                selectedHSBC = Set(hsbcAccounts.map(\.id))
                activeStep = .hsbc
            }
            Divider().overlay(Theme.line.opacity(0.5))
            portfolioOption("Connect to other bank account", icon: "building.2.crop.circle", id: "bank") {
                activeStep = .bank
            }
            Divider().overlay(Theme.line.opacity(0.5))
            portfolioOption("Upload or scan a statement", icon: "square.and.arrow.up", id: "statement") {
                activeStep = .statement
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 6)
        .background {
            GeometryReader { geometry in
                Color.clear.preference(key: PortfolioSheetHeightKey.self, value: geometry.size.height)
            }
        }
        .onPreferenceChange(PortfolioSheetHeightKey.self) { height in
            if activeStep == nil && height > 0 && abs(rootHeight - height) > 1 {
                rootHeight = ceil(height)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.white)
    }

    @ViewBuilder
    private func destination(for step: PortfolioStep) -> some View {
        switch step {
        case .hsbc:
            GlobalHSBCSelection(accounts: hsbcAccounts, selection: $selectedHSBC) {
                finish(ids: selectedHSBC.intersection(Set(hsbcAccounts.map(\.id))))
            }
        case .bank:
            OtherBankPortfolioConnection { account in finish(account: account) }
        case .statement:
            PortfolioStatementUpload(onCancel: { dismiss() }) { result, source in
                extractedHoldings = result.holdings
                statementSource = source
                extractionWarnings = result.warnings
                accountEvidence = result.account?.evidence
                var account = SampleData.makeAccount(template: "statement-review")
                account.note = account.note.replacingOccurrences(of: "{source}", with: source)
                if let detected = result.account {
                    account.name = detected.name
                    account.institution = detected.institution
                    account.currency = detected.currency
                    account.market = detected.market ?? SampleData.row("markets", id: SampleData.setting("defaultMarketID")).string("name")
                    account.accountNumber = detected.accountNumber
                }
                statementAccount = account
                path.append(.extracted)
            }
        case .extracted:
            ExtractedPortfolioReview(holdings: $extractedHoldings, account: $statementAccount, source: statementSource,
                                     accountEvidence: accountEvidence, warnings: extractionWarnings, onCancel: { dismiss() }) {
                var account = statementAccount
                account.name = account.name.trimmingCharacters(in: .whitespacesAndNewlines)
                account.institution = account.institution.trimmingCharacters(in: .whitespacesAndNewlines)
                account.colorIndex = store.accounts.count
                account.holdings = extractedHoldings
                finish(account: account)
            }
        }
    }

    private func portfolioOption(_ title: String, icon: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 18, weight: .light)).frame(width: 22)
                Text(title).font(.system(size: 15)).multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                Image(systemName: "arrow.right").font(.system(size: 18, weight: .light))
            }
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("portfolio.add.\(id)")
    }

    private func finish(ids: Set<UUID> = [], account: InvestmentAccount? = nil) {
        guard !completed else { return }
        let included = account.map { Set([$0.id]) } ?? ids
        guard !included.isEmpty else { return }
        completed = true
        if let account { store.save(account) }
        onComplete(included)
        dismiss()
    }
}

private struct PortfolioSheetHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private enum PortfolioStep: String, Hashable, Identifiable {
    case hsbc, bank, statement, extracted
    var id: String { rawValue }
}

private struct GlobalHSBCSelection: View {
    let accounts: [InvestmentAccount]
    @Binding var selection: Set<UUID>
    var confirm: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Add your global HSBC accounts")
                    .font(.system(size: 25, weight: .light))
                Text("Select the accounts you’d like to include in your wealth analysis.")
                    .font(.system(size: 15)).foregroundStyle(Theme.muted).lineSpacing(4)
                if accounts.isEmpty {
                    EmptyPortfolio(title: "No HSBC accounts available", message: "You can add another bank account or upload a statement from the previous screen.")
                } else {
                    ForEach(accounts) { account in
                        Button {
                            if selection.contains(account.id) { selection.remove(account.id) }
                            else { selection.insert(account.id) }
                        } label: {
                            HStack(spacing: 14) {
                                BankMark(bank: "HSBC")
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(account.market).font(.system(size: 15, weight: .medium))
                                    Text(account.name).font(.system(size: 13)).foregroundStyle(Theme.muted)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: selection.contains(account.id) ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 23, weight: .light))
                                    .foregroundStyle(selection.contains(account.id) ? Theme.red : Theme.muted)
                            }
                            .padding(.vertical, 18)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selection.contains(account.id) ? .isSelected : [])
                        .accessibilityIdentifier("portfolio.hsbc.account.\(account.market)")
                        Divider()
                    }
                }
            }.padding(20)
        }
        .navigationTitle("Global HSBC accounts")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Confirm", action: confirm)
                .disabled(selection.isEmpty).opacity(selection.isEmpty ? 0.45 : 1)
                .accessibilityIdentifier("portfolio.hsbc.confirm")
                .padding(20).background(.white)
        }
    }
}

private struct OtherBankPortfolioConnection: View {
    var onComplete: (InvestmentAccount) -> Void
    @State private var bankID = SampleData.setting("defaultBankID")
    @State private var consent = false
    @State private var account: InvestmentAccount?

    private var bank: String { SampleData.row("banks", id: bankID).string("name") }
    private var banks: [SampleRecord] { SampleData.rows("banks").filter { $0.bool("portfolioEnabled") } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Label("Demo connection", systemImage: "info.circle")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)

                if let account {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 50, weight: .ultraLight)).foregroundStyle(Theme.green)
                        .frame(maxWidth: .infinity).padding(.top, 24)
                    Text("Your portfolio is ready")
                        .font(.system(size: 27, weight: .light)).frame(maxWidth: .infinity)
                    Text("A sample \(bank) investment account is ready to include in your wealth analysis.")
                        .font(.system(size: 15)).foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center).lineSpacing(4)
                    HStack(spacing: 14) {
                        BankMark(bank: bank)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(account.name).font(.system(size: 16, weight: .medium))
                            Text("\(account.market) · \(account.holdings.count) holdings").font(.system(size: 13)).foregroundStyle(Theme.muted)
                        }
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Theme.background)
                } else {
                    Text("Connect another bank")
                        .font(.system(size: 27, weight: .light))
                    Text("Bring your portfolios together with a sample SGFinDex-style connection.")
                        .font(.system(size: 15)).foregroundStyle(Theme.muted).lineSpacing(4)
                    Text("Choose a bank").font(.system(size: 17, weight: .medium))
                    ForEach(banks, id: \.id) { option in
                        Button {
                            bankID = option.id
                            consent = false
                        } label: {
                            HStack(spacing: 16) {
                                BankMark(bank: option.string("name"))
                                Text(option.string("name")).font(.system(size: 17))
                                Spacer()
                                Image(systemName: bankID == option.id ? "largecircle.fill.circle" : "circle")
                                    .font(.system(size: 23, weight: .light))
                                    .foregroundStyle(bankID == option.id ? Theme.red : Theme.muted)
                            }.padding(18).background(Theme.background).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("portfolio.bank.\(option.string("name"))")
                    }
                    Toggle(isOn: $consent) {
                        Text("I agree to include the selected bank’s demo account in my portfolio.")
                            .font(.system(size: 14)).lineSpacing(3)
                    }.tint(Theme.red).accessibilityIdentifier("portfolio.bank.consent")
                    Text("This demo uses local sample data. It does not sign in to your bank or retrieve your banking information.")
                        .font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(3)
                }
            }.padding(20)
        }
        .navigationTitle("Other bank account")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: account == nil ? "Connect demo account" : "Proceed") {
                if let account { onComplete(account) }
                else { account = sampleAccount() }
            }
            .disabled(account == nil && !consent)
            .opacity(account == nil && !consent ? 0.45 : 1)
            .accessibilityIdentifier(account == nil ? "portfolio.bank.connect" : "portfolio.bank.proceed")
            .padding(20).background(.white)
        }
    }

    private func sampleAccount() -> InvestmentAccount {
        var account = SampleData.makeAccount(template: "bank-connection")
        account.institution = bank
        account.name = account.name.replacingOccurrences(of: "{bank}", with: bank)
        return account
    }
}

private struct PortfolioStatementUpload: View {
    var onCancel: () -> Void
    var onExtracted: (StatementExtractionService.ExtractionResult, String) -> Void
    @State private var uploadSourcePresented = false
    @State private var importerPresented = false
    @State private var choosingCameraFallback = false
    @State private var imageSource: PortfolioImageSource?
    @State private var pickedImage: UIImage?
    @State private var loading = false
    @State private var error: String?
    @State private var extractionTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                explanation("How to provide your portfolio?", text: "Upload a statement, screenshot or photo of your investment holdings. You can also take a photo of your statement. CSV, PDF and image files are supported.")
                explanation("What we will do?", text: "We will look for your account provider and holdings, including currencies, quantities, prices and average costs. Review the extracted details before adding the account to your portfolio. Files are processed on this device.")

                if loading {
                    HStack(spacing: 12) {
                        ProgressView().tint(Theme.red)
                        Text("Recognising your account and holdings…").font(.system(size: 14))
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(18).background(Theme.background)
                        .accessibilityIdentifier("portfolio.statement.loading")
                }
                if let error {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.system(size: 14)).foregroundStyle(Theme.red).lineSpacing(3)
                        .accessibilityIdentifier("portfolio.statement.error")
                }
            }.padding(.horizontal, 24).padding(.vertical, 24)
        }
        .navigationTitle("Upload or scan a statement")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                PrimaryButton(title: "Upload") {
                    choosingCameraFallback = false
                    uploadSourcePresented = true
                }
                    .accessibilityIdentifier("portfolio.statement.upload")
                PrimaryButton(title: "Take a photo", action: openCamera)
                    .accessibilityIdentifier("portfolio.statement.camera")
                Button("Try a sample statement") {
                    error = nil
                    showSample()
                }
                .font(.system(size: 13)).foregroundStyle(Theme.muted)
                .padding(.vertical, 3)
                .accessibilityIdentifier("portfolio.statement.sample")
                PortfolioOutlinedButton(title: "Cancel", action: onCancel)
                    .accessibilityIdentifier("portfolio.statement.cancel")
            }
            .disabled(loading)
            .overlay(alignment: .bottom) {
                if loading {
                    PortfolioOutlinedButton(title: "Cancel extraction") {
                        extractionTask?.cancel()
                        loading = false
                        error = nil
                    }
                    .accessibilityIdentifier("portfolio.statement.cancelExtraction")
                }
            }
            .padding(20).background(.white)
        }
        .confirmationDialog(choosingCameraFallback ? "Camera unavailable" : "Upload a statement",
                            isPresented: $uploadSourcePresented, titleVisibility: .visible) {
            if choosingCameraFallback {
                Button("Choose a saved photo") { imageSource = .library }
                Button("Try a sample statement", action: showSample)
            } else {
                Button("Choose a photo") { imageSource = .library }
                Button("Choose a file") { importerPresented = true }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if choosingCameraFallback { Text(cameraUnavailableMessage) }
        }
        .fileImporter(isPresented: $importerPresented, allowedContentTypes: [.commaSeparatedText, .plainText, .pdf, .image], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                extract(url: url)
            case .failure(let failure): error = failure.localizedDescription
            }
        }
        .sheet(item: $imageSource, onDismiss: {
            if let image = pickedImage {
                pickedImage = nil
                extract(image: image)
            }
        }) { source in
            PortfolioImagePicker(source: source) { image in
                pickedImage = image
                imageSource = nil
            }.ignoresSafeArea()
        }
        .onDisappear { extractionTask?.cancel() }
    }

    private var cameraUnavailableMessage: String {
        #if targetEnvironment(simulator)
        "The simulator has no camera. Choose a saved photo or try the sample statement."
        #else
        "A camera is not available on this device. Choose a saved photo or try the sample statement."
        #endif
    }

    private func explanation(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 14, weight: .medium))
            Text(text).font(.system(size: 14)).foregroundStyle(Theme.muted).lineSpacing(4)
        }
    }

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            choosingCameraFallback = true
            uploadSourcePresented = true
            return
        }
        Task { @MainActor in
            let allowed = await AVCaptureDevice.requestAccess(for: .video)
            if allowed { imageSource = .camera }
            else { error = "Camera access is off. Enable it in Settings or upload a statement instead." }
        }
    }

    private func extract(url: URL) {
        beginExtraction(source: url.lastPathComponent) { try await StatementExtractionService.extract(url: url) }
    }

    private func extract(image: UIImage) {
        beginExtraction(source: "statement photo") { try await StatementExtractionService.extract(image: image) }
    }

    private func showSample() {
        onExtracted(.init(holdings: StatementExtractionService.sampleHoldings, account: nil, warnings: []), SampleData.setting("statementPreviewSource"))
    }

    private func beginExtraction(source: String, operation: @escaping () async throws -> StatementExtractionService.ExtractionResult) {
        extractionTask?.cancel()
        error = nil
        loading = true
        extractionTask = Task { @MainActor in
            do {
                let result = try await operation()
                guard !Task.isCancelled else { return }
                loading = false
                if result.holdings.isEmpty {
                    error = "No holdings were found. Try a clearer statement or upload a CSV with your holdings."
                } else { onExtracted(result, source) }
            } catch {
                guard !Task.isCancelled else { return }
                loading = false
                self.error = error.localizedDescription
            }
        }
    }
}

private struct ExtractedPortfolioReview: View {
    @Binding var holdings: [Holding]
    @Binding var account: InvestmentAccount
    let source: String
    let accountEvidence: String?
    let warnings: [String]
    var onCancel: () -> Void
    var onProceed: () -> Void
    @State private var editing: Holding?
    @State private var editingAccount = false

    private var allValid: Bool { portfolioStatementAccountIsValid(account) && !holdings.isEmpty && holdings.allSatisfy(portfolioHoldingIsValid) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("I’ve found \(holdings.count) holdings in this statement:")
                    .font(.system(size: 14)).lineSpacing(3).padding(.top, 16)
                Text(source == SampleData.setting("statementPreviewSource") ? "Sample statement · Review the details before proceeding." : "Review the account and holdings before adding them to your portfolio.")
                    .font(.system(size: 13)).foregroundStyle(Theme.muted).lineSpacing(3)
                accountCard
                ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                    Label(warning, systemImage: "info.circle")
                        .font(.system(size: 13)).foregroundStyle(Theme.muted).lineSpacing(3)
                }
                if !allValid {
                    Label("Complete the account details and any missing holding values before proceeding.", systemImage: "exclamationmark.circle")
                        .font(.system(size: 13)).foregroundStyle(Theme.red).lineSpacing(3)
                }
                VStack(spacing: 0) {
                    ForEach(holdings) { holding in
                        Button { editing = holding } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(holding.name).font(.system(size: 15, weight: .medium))
                                            .lineLimit(1).minimumScaleFactor(0.85)
                                        Text("\(holding.symbol) · \(holding.currency.rawValue)")
                                            .font(.system(size: 12)).foregroundStyle(Theme.muted)
                                    }
                                    Spacer(minLength: 4)
                                    Text("\(holding.quantity.formatted(.number.precision(.fractionLength(0...4)))) shares")
                                        .font(.system(size: 12)).foregroundStyle(Theme.muted).fixedSize()
                                    Image(systemName: "pencil").font(.system(size: 16, weight: .light))
                                }
                                HStack(alignment: .top, spacing: 10) {
                                    holdingAmount("Price", value: holding.price)
                                    holdingAmount("Average cost", value: holding.averageCost)
                                    holdingAmount("Market value", value: holding.value, fractionalDigits: 2)
                                }
                                if !portfolioHoldingIsValid(holding) {
                                    Text("Review required").font(.system(size: 11)).foregroundStyle(Theme.red)
                                }
                            }
                            .padding(.vertical, 14).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit \(holding.name), \(holding.symbol), \(holding.quantity.formatted()) shares, \(holding.currency.rawValue), price \(holding.price.formatted()), average cost \(holding.averageCost.formatted())")
                        .accessibilityIdentifier("portfolio.extracted.holding.\(holding.symbol)")
                        Divider()
                    }
                }
            }.padding(.horizontal, 24).padding(.bottom, 20)
        }
        .navigationTitle("Extracted outcome")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 14) {
                PortfolioOutlinedButton(title: "Cancel", action: onCancel)
                    .accessibilityIdentifier("portfolio.extracted.cancel")
                PrimaryButton(title: "Proceed", action: onProceed)
                    .disabled(!allValid).opacity(allValid ? 1 : 0.45)
                    .accessibilityIdentifier("portfolio.extracted.proceed")
            }.padding(20).background(.white)
        }
        .sheet(item: $editing) { holding in
            PortfolioHoldingDraftEditor(holding: holding) { updated in
                if let index = holdings.firstIndex(where: { $0.id == updated.id }) { holdings[index] = updated }
            }
        }
        .sheet(isPresented: $editingAccount) {
            PortfolioStatementAccountEditor(account: account) { account = $0 }
        }
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(accountEvidence == nil ? "Import into a new account" : "Detected account")
                .font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.muted)
            Button { editingAccount = true } label: {
                HStack(alignment: .top, spacing: 12) {
                    BankMark(bank: account.institution, size: 30)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(account.name).font(.system(size: 16, weight: .medium))
                        Text("\(account.institution) · \(account.market) · \(account.currency.rawValue)")
                            .font(.system(size: 12)).foregroundStyle(Theme.muted)
                        if let number = account.accountNumber, !number.isEmpty {
                            Text(number).font(.system(size: 12)).foregroundStyle(Theme.muted)
                        }
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "pencil").font(.system(size: 16, weight: .light))
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit account, \(account.name), \(account.institution), \(account.market), \(account.currency.rawValue)")
            .accessibilityIdentifier("portfolio.extracted.account.edit")
            Text(accountEvidence ?? "You can edit the account name, institution, market and reporting currency.")
                .font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(3)
        }.padding(16).background(Theme.background)
    }

    private func holdingAmount(_ title: String, value: Double, fractionalDigits: Int = 4) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11)).foregroundStyle(Theme.muted)
            Text(value.formatted(.number.locale(Locale(identifier: "en_SG")).precision(.fractionLength(2...fractionalDigits))))
                .font(.system(size: 13, weight: .medium)).lineLimit(1).minimumScaleFactor(0.75)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

private func portfolioStatementAccountIsValid(_ account: InvestmentAccount) -> Bool {
    !account.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
    !account.institution.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
    !account.market.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

private struct PortfolioStatementAccountEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var account: InvestmentAccount
    var onSave: (InvestmentAccount) -> Void

    private var markets: [String] {
        let names = SampleData.rows("markets").map { $0.string("name") }
        return names.contains(account.market) ? names : names + [account.market]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account details") {
                    TextField("Account name", text: $account.name)
                        .accessibilityIdentifier("portfolio.extracted.account.name")
                    TextField("Bank / institution", text: $account.institution)
                        .accessibilityIdentifier("portfolio.extracted.account.institution")
                    TextField("Account number (optional)", text: Binding(
                        get: { account.accountNumber ?? "" },
                        set: { account.accountNumber = $0.isEmpty ? nil : $0 }
                    )).autocorrectionDisabled()
                        .accessibilityIdentifier("portfolio.extracted.account.number")
                    Picker("Account market", selection: $account.market) {
                        ForEach(markets, id: \.self) { Text($0).tag($0) }
                    }.accessibilityIdentifier("portfolio.extracted.account.market")
                    Picker("Reporting currency", selection: $account.currency) {
                        ForEach(Currency.allCases) { Text($0.rawValue).tag($0) }
                    }.accessibilityIdentifier("portfolio.extracted.account.currency")
                }
                Section {
                    Text("Confirm where to organise this account. Each holding keeps the currency shown in the statement, regardless of the account's reporting currency.")
                        .font(.footnote).foregroundStyle(Theme.muted)
                }
            }
            .navigationTitle("Edit account").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        account.name = account.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        account.institution = account.institution.trimmingCharacters(in: .whitespacesAndNewlines)
                        let number = account.accountNumber?.trimmingCharacters(in: .whitespacesAndNewlines)
                        account.accountNumber = number?.isEmpty == false ? number : nil
                        onSave(account)
                        dismiss()
                    }.disabled(!portfolioStatementAccountIsValid(account))
                        .accessibilityIdentifier("portfolio.extracted.account.save")
                }
            }
        }
    }
}

private func portfolioHoldingIsValid(_ holding: Holding) -> Bool {
    !holding.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
    !holding.symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
    holding.quantity.isFinite && holding.quantity > 0 && holding.quantity < 1e14 &&
    holding.price.isFinite && holding.price > 0 && holding.price < 1e14 &&
    holding.averageCost.isFinite && holding.averageCost > 0 && holding.averageCost < 1e14 &&
    holding.value.isFinite && holding.cost.isFinite
}

private struct PortfolioHoldingDraftEditor: View {
    @Environment(\.dismiss) private var dismiss
    let original: Holding
    var onSave: (Holding) -> Void
    @State private var name: String
    @State private var symbol: String
    @State private var quantity: String
    @State private var price: String
    @State private var averageCost: String
    @State private var currency: Currency
    @State private var category: AssetClass

    init(holding: Holding, onSave: @escaping (Holding) -> Void) {
        original = holding
        self.onSave = onSave
        _name = State(initialValue: holding.name)
        _symbol = State(initialValue: holding.symbol)
        _quantity = State(initialValue: String(holding.quantity))
        _price = State(initialValue: String(holding.price))
        _averageCost = State(initialValue: String(holding.averageCost))
        _currency = State(initialValue: holding.currency)
        _category = State(initialValue: holding.category)
    }

    private var draft: Holding? {
        guard let quantity = Double(quantity), let price = Double(price), let averageCost = Double(averageCost) else { return nil }
        var holding = original
        holding.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        holding.symbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        holding.quantity = quantity
        holding.price = price
        holding.averageCost = averageCost
        holding.currency = currency
        holding.category = category
        return portfolioHoldingIsValid(holding) ? holding : nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Holding") {
                    TextField("Name", text: $name).accessibilityIdentifier("portfolio.holding.name")
                    TextField("Symbol", text: $symbol).textInputAutocapitalization(.characters)
                        .autocorrectionDisabled().accessibilityIdentifier("portfolio.holding.symbol")
                    Picker("Asset class", selection: $category) {
                        ForEach(AssetClass.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Currency", selection: $currency) {
                        ForEach(Currency.allCases) { Text($0.rawValue).tag($0) }
                    }.accessibilityIdentifier("portfolio.holding.currency")
                }
                Section {
                    numericField("Quantity", value: $quantity, id: "quantity")
                    numericField("Price per unit", value: $price, id: "price")
                    numericField("Average cost per unit", value: $averageCost, id: "cost")
                } header: { Text("Position") } footer: {
                    Text("Enter a positive quantity, price and average cost. Complete any values missing from your statement before proceeding. Each value must be below 100 trillion.")
                }
            }
            .navigationTitle("Edit holding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let draft else { return }
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft == nil)
                    .accessibilityIdentifier("portfolio.holding.save")
                }
            }
        }
    }

    private func numericField(_ title: String, value: Binding<String>, id: String) -> some View {
        HStack {
            Text(title)
            TextField(title, text: value)
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                .accessibilityIdentifier("portfolio.holding.\(id)")
        }
    }
}

private struct PortfolioOutlinedButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 16, weight: .medium))
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .foregroundStyle(Theme.ink)
                .background(.white)
                .overlay(Rectangle().stroke(Theme.ink, lineWidth: 1))
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

private enum PortfolioImageSource: String, Identifiable {
    case camera, library
    var id: String { rawValue }
    var pickerSource: UIImagePickerController.SourceType { self == .camera ? .camera : .photoLibrary }
}

private struct PortfolioImagePicker: UIViewControllerRepresentable {
    let source: PortfolioImageSource
    var onPick: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = source.pickerSource
        picker.mediaTypes = [UTType.image.identifier]
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPick: (UIImage?) -> Void
        init(onPick: @escaping (UIImage?) -> Void) { self.onPick = onPick }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onPick(nil) }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onPick(info[.originalImage] as? UIImage)
        }
    }
}
