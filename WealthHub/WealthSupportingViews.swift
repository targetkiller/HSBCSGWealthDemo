import SwiftUI

struct WealthBackdrop: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white
                Path { path in
                    path.move(to: .init(x: geometry.size.width, y: 0))
                    path.addLine(to: .init(x: 0, y: geometry.size.width))
                    path.addLine(to: .init(x: geometry.size.width, y: geometry.size.width * 2))
                    path.closeSubpath()
                }.fill(LinearGradient(colors: [Color(hex: 0xF8F8F8), .white], startPoint: .topTrailing, endPoint: .bottomLeading))
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct WealthProductsSection: View {
    var onSelect: (String) -> Void
    @State private var category = "Products"
    private var items: [SampleRecord] { SampleData.rows("products").filter { $0.string("category") == category } }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("Products and services").font(.system(size: 20, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                Button { onSelect("Products and services") } label: { HStack(spacing: 6) { Text("View all").font(.system(size: 12, weight: .medium)); Image(systemName: "arrow.right") }.contentShape(Rectangle()) }.buttonStyle(.plain)
            }
            HStack(spacing: 8) { Pill(title: "Products", selected: category == "Products") { category = "Products" }; Pill(title: "Services", selected: category == "Services") { category = "Services" } }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), alignment: .center, spacing: 24) {
                ForEach(items, id: \.id) { item in
                    let title = item.string("title").replacingOccurrences(of: "\\n", with: "\n")
                    Button { onSelect(title.replacingOccurrences(of: "\n", with: " ")) } label: {
                        VStack(spacing: 9) {
                            Image(systemName: item.string("symbol")).font(.system(size: 25, weight: .light)).foregroundStyle(Theme.red).frame(width: 58, height: 58).background(.white, in: Circle())
                            Text(title).font(.system(size: 12, weight: .medium)).lineSpacing(3).multilineTextAlignment(.center).frame(height: 34, alignment: .top)
                        }.frame(maxWidth: .infinity).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }
        }.padding(.horizontal, 16).padding(.vertical, 25).background(Color(hex: 0xEFEFED))
    }
}

struct WealthHelpBar: View {
    var open: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Button(action: open) { Image(systemName: "bubble.left.and.text.bubble.right").font(.system(size: 24, weight: .light)).frame(width: 24).contentShape(Rectangle()) }.accessibilityLabel("Open wealth assistant")
            Button(action: open) {
                HStack(spacing: 7) {
                    Text("How can we help you today?").font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                    Image(systemName: "mic").font(.system(size: 20, weight: .light))
                }.padding(.horizontal, 12).frame(height: 44).overlay(Rectangle().stroke(Theme.muted, lineWidth: 1)).contentShape(Rectangle())
            }.accessibilityIdentifier("wealth.assistant.open")
            Button(action: open) { Image(systemName: "arrow.right").font(.system(size: 25, weight: .light)).frame(width: 28).contentShape(Rectangle()) }.accessibilityLabel("Ask the wealth assistant")
        }.buttonStyle(.plain).foregroundStyle(Theme.ink).padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 10).background(.white.shadow(.drop(color: .black.opacity(0.08), radius: 12, y: -3)))
    }
}

struct WealthProductPreview: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                Image(systemName: "building.columns").font(.system(size: 38, weight: .light)).foregroundStyle(Theme.red)
                Text(title).font(.system(size: 28, weight: .light))
                Text("Explore your wealth with confidence.").font(.system(size: 18, weight: .medium))
                Text("This preview focuses on your holdings and portfolio analysis. Return to Wealth to explore your investments and add other portfolios.").font(.system(size: 15)).foregroundStyle(Theme.muted).lineSpacing(5)
                PrimaryButton(title: "Return to Wealth") { dismiss() }
                Spacer()
            }.padding(24).padding(.top, 22).navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly).foregroundStyle(Theme.ink) } }
        }.presentationDetents([.medium, .large])
    }
}

struct WealthAssistantSheet: View {
    @Environment(PortfolioStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let accounts: [InvestmentAccount]
    @State private var question = ""
    @State private var messages: [(question: String, answer: String)] = []
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("How can we help you today?").font(.system(size: 25, weight: .light))
                        Text("Explore your selected portfolio. Demo answers are based on the holdings on this device.").font(.system(size: 13)).foregroundStyle(Theme.muted).lineSpacing(4)
                        ForEach(SampleData.rows("assistant_suggestions"), id: \.id) { item in Button { answer(item.string("prompt")) } label: { HStack { Text(item.string("prompt")).font(.system(size: 14)); Spacer(); Image(systemName: "arrow.right") }.padding(14).background(Theme.background).contentShape(Rectangle()) }.buttonStyle(.plain) }
                        ForEach(Array(messages.enumerated()), id: \.offset) { _, item in VStack(alignment: .leading, spacing: 12) { Text(item.question).font(.system(size: 14, weight: .medium)); Text(item.answer).font(.system(size: 14)).foregroundStyle(Theme.muted).lineSpacing(5) }.padding(16).background(Theme.background) }
                    }.padding(20)
                }
                HStack(spacing: 12) { TextField("Ask about your wealth", text: $question).textFieldStyle(.roundedBorder).onSubmit { submit() }; Button(action: submit) { Image(systemName: "arrow.up.circle.fill").font(.system(size: 30)) }.disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityLabel("Send question") }.padding(16)
            }.navigationTitle("Wealth assistant").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly).foregroundStyle(Theme.ink) } }
        }
    }
    private func submit() { let text = question.trimmingCharacters(in: .whitespacesAndNewlines); guard !text.isEmpty else { return }; answer(text); question = "" }
    private func answer(_ prompt: String) {
        let allocation = store.allocation(for: accounts)
        let total = accounts.reduce(0) { $0 + $1.value(in: store.currency) }
        guard let rule = SampleData.rows("assistant_rules").first(where: { row in
            let keywords = row.list("keywords")
            return keywords.isEmpty || keywords.contains { prompt.localizedCaseInsensitiveContains($0) }
        }) else { return }
        let values = [
            "allocationName": allocation.first?.category.rawValue ?? "not yet available",
            "allocationPercent": String(total > 0 ? Int((allocation.first?.value ?? 0) / total * 100) : 0),
            "holdingCount": String(accounts.flatMap(\.holdings).count),
            "accountCount": String(accounts.count),
            "totalAmount": store.amount(total)
        ]
        let response = values.reduce(rule.string("response")) { text, item in text.replacingOccurrences(of: "{\(item.key)}", with: item.value) }
        messages.append((prompt, response))
    }
}
