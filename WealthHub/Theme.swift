import SwiftUI
import Charts

enum Theme {
    static let red = Color(hex: 0xDB0011)
    static let ink = Color(hex: 0x25272A)
    static let muted = Color(hex: 0x6A6D70)
    static let background = Color(hex: 0xF5F5F5)
    static let line = Color(hex: 0xE8E8E8)
    static let green = Color(hex: 0x328579)
    static let palette: [Color] = [Color(hex: 0x376475), Color(hex: 0x69A52D), Color(hex: 0xB74362), Color(hex: 0xDE8953), Color(hex: 0x75A5B7)]
    static func color(_ category: AssetClass) -> Color {
        switch category {
        case .fund: Color(hex: 0x286074)
        case .stock: Color(hex: 0x4DA900)
        case .bond: Color(hex: 0xBB3655)
        case .other: Color(hex: 0xEE704A)
        case .cash: Color(hex: 0x55A2BE)
        case .insurance: Color(hex: 0x8067AF)
        case .option: Color(hex: 0xC7983B)
        }
    }
    static func accountColor(_ index: Int) -> Color { palette[abs(index) % palette.count] }
}

extension Color {
    init(hex: UInt32) { self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255) }
}

struct PrimaryButton: View {
    var title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(Theme.red)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(title)
    }
}

struct Pill: View {
    let title: String
    var selected = false
    var action: () -> Void
    var body: some View {
        Button(action: action) { Text(title).font(.system(size: 12, weight: .medium)).padding(.horizontal, 14).padding(.vertical, 10)
                .foregroundStyle(selected ? .white : Theme.ink).background(selected ? Theme.ink : .white, in: Capsule())
                .overlay(Capsule().stroke(selected ? .clear : Theme.line))
                .contentShape(Capsule()) }
        .buttonStyle(.plain)
    }
}

struct BankMark: View {
    var bank = "HSBC"
    var size: CGFloat = 28

    private var normalizedBank: String { bank.lowercased() }

    var body: some View {
        ZStack {
            if normalizedBank.contains("hsbc") {
                GeometryReader { g in
                    Path { p in
                        let w = g.size.width, h = g.size.height
                        p.move(to: .init(x: 0, y: h / 2)); p.addLines([.init(x: w / 4, y: 0), .init(x: w / 4, y: h), .init(x: 0, y: h / 2)])
                        p.move(to: .init(x: w / 4, y: 0)); p.addLines([.init(x: w * 0.75, y: 0), .init(x: w / 2, y: h / 2), .init(x: w / 4, y: 0)])
                        p.move(to: .init(x: w * 0.75, y: 0)); p.addLines([.init(x: w, y: h / 2), .init(x: w * 0.75, y: h), .init(x: w * 0.75, y: 0)])
                        p.move(to: .init(x: w / 4, y: h)); p.addLines([.init(x: w / 2, y: h / 2), .init(x: w * 0.75, y: h), .init(x: w / 4, y: h)])
                    }.fill(Theme.red)
                }
            } else if normalizedBank.contains("dbs") {
                GeometryReader { geometry in
                    let edge = geometry.size.height
                    ZStack {
                        ForEach(0..<4) { petal in
                            RoundedRectangle(cornerRadius: edge * 0.13)
                                .fill(Theme.red)
                                .frame(width: edge * 0.57, height: edge * 0.57)
                                .rotationEffect(.degrees(45))
                                .offset(y: -edge * 0.18)
                                .rotationEffect(.degrees(Double(petal) * 90))
                        }
                        Rectangle().fill(.white)
                            .frame(width: edge * 0.20, height: edge * 0.20)
                            .rotationEffect(.degrees(45))
                    }.frame(width: geometry.size.width, height: edge)
                }
            } else if normalizedBank.contains("standard chartered") || normalizedBank == "sc" {
                GeometryReader { geometry in
                    let w = geometry.size.width, h = geometry.size.height
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.70, y: h * 0.08))
                        path.addCurve(to: CGPoint(x: w * 0.28, y: h * 0.36), control1: CGPoint(x: w * 0.48, y: h * 0.18), control2: CGPoint(x: w * 0.13, y: h * 0.20))
                        path.addLine(to: CGPoint(x: w * 0.56, y: h * 0.55))
                    }
                    .stroke(Color(hex: 0x0075B0), style: StrokeStyle(lineWidth: h * 0.22, lineCap: .round, lineJoin: .round))
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.40, y: h * 0.47))
                        path.addLine(to: CGPoint(x: w * 0.68, y: h * 0.64))
                        path.addCurve(to: CGPoint(x: w * 0.28, y: h * 0.93), control1: CGPoint(x: w * 0.86, y: h * 0.80), control2: CGPoint(x: w * 0.50, y: h * 0.85))
                    }
                    .stroke(Color(hex: 0x00A651), style: StrokeStyle(lineWidth: h * 0.22, lineCap: .round, lineJoin: .round))
                }
            } else {
                Text(String(bank.prefix(3)).uppercased())
                    .font(.system(size: size * 0.36, weight: .heavy)).foregroundStyle(Theme.red)
            }
        }
        .frame(width: size, height: size * 0.64)
        .accessibilityLabel(bank)
    }
}

struct BankLogoStack: View {
    var banks: [String]
    var size: CGFloat = 28

    private var distinctBanks: [String] {
        var seen = Set<String>()
        return banks.filter { seen.insert($0.lowercased()).inserted }
    }

    var body: some View {
        HStack(spacing: -size * 0.26) {
            ForEach(Array(distinctBanks.prefix(3).enumerated()), id: \.offset) { index, bank in
                BankMark(bank: bank, size: size * 0.72)
                    .frame(width: size, height: size)
                    .background(.white, in: Circle())
                    .overlay(Circle().stroke(Theme.line, lineWidth: 0.75))
                    .zIndex(Double(3 - index))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(distinctBanks.joined(separator: ", "))
    }
}

struct SectionTitle<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing
    var body: some View { HStack { Text(title).font(.system(size: 18, weight: .medium)); Spacer(); trailing }.padding(.bottom, 8) }
}

struct ReturnLabel: View {
    var value: Double?
    var body: some View { Text(value.map { String(format: "%@%.2f%%", $0 >= 0 ? "+" : "", $0) } ?? "—").font(.system(size: 13, weight: .medium)).foregroundStyle((value ?? 0) >= 0 ? Theme.green : Theme.red).monospacedDigit() }
}

struct DemoFootnote: View {
    var body: some View { Label("Demo data · Fixed FX rates · No live bank connection", systemImage: "info.circle").font(.system(size: 11)).foregroundStyle(Theme.muted).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 16) }
}

struct EmptyPortfolio: View {
    var title = "Your portfolio starts here"
    var message = "Add an account to see your wealth in one place."
    var body: some View { VStack(spacing: 16) { Image(systemName: "chart.pie").font(.system(size: 42)).foregroundStyle(Theme.red); Text(title).font(.headline); Text(message).font(.subheadline).foregroundStyle(Theme.muted).multilineTextAlignment(.center) }.frame(maxWidth: .infinity).padding(.vertical, 48) }
}

struct AllocationRing: View {
    var slices: [(name: String, value: Double, color: Color)]
    var subtitle = "Total assets"
    var center: String
    var body: some View {
        ZStack {
            if slices.isEmpty { Circle().stroke(Theme.line, lineWidth: 36).padding(20) }
            else {
                Chart(Array(slices.enumerated()), id: \.offset) { _, item in
                    SectorMark(angle: .value("Value", item.value), innerRadius: .ratio(0.50), outerRadius: .ratio(0.81), angularInset: 1).foregroundStyle(item.color)
                }
                .chartLegend(.hidden)
                .accessibilityLabel("Asset allocation")
                Chart(Array(slices.enumerated()), id: \.offset) { _, item in
                    SectorMark(angle: .value("Value", item.value), innerRadius: .ratio(0.83), outerRadius: .ratio(1), angularInset: 1).foregroundStyle(item.color.opacity(0.42))
                }.chartLegend(.hidden).accessibilityHidden(true)
            }
            VStack(spacing: 6) { Text(subtitle).font(.system(size: 11)).foregroundStyle(Theme.muted); Text(center).font(.system(size: 17, weight: .semibold)).minimumScaleFactor(0.6).lineLimit(1).frame(maxWidth: 105) }
        }.frame(height: 250).padding(.vertical, 12)
    }
}
