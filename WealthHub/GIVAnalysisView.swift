import SwiftUI
import Charts

struct GIVAnalysisView: View {
    @Environment(PortfolioStore.self) private var store
    let data: GIVPortfolioData
    @State private var exposure = "Currency"
    @State private var selectedSlice: String?
    @State private var expandedInsight = false
    @State private var scenario = GIVScenario.configuredDefault
    private var slices: [GIVSlice] { exposure == "Currency" ? data.currencies : exposure == "Region" ? data.regions : data.sectors }
    private var focused: GIVSlice? { slices.first { $0.name == selectedSlice } ?? slices.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Exposure").font(.system(size: 17, weight: .medium))
                HStack(spacing: 0) {
                    ForEach(["Currency", "Region", "Sectors"], id: \.self) { item in
                        Button { exposure = item; selectedSlice = nil; expandedInsight = false } label: {
                            Text(item).font(.system(size: 12)).frame(maxWidth: .infinity).frame(height: 40)
                                .background(exposure == item ? .white : .clear, in: Capsule())
                                .overlay(Capsule().stroke(exposure == item ? Theme.line : .clear))
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("giv.analysis.\(item)").accessibilityAddTraits(exposure == item ? .isSelected : [])
                    }
                }.padding(2).background(Theme.background, in: Capsule())
                if exposure == "Currency" { currencyExposure }
                else if exposure == "Region" { regionExposure }
                else { sectorExposure }
                insight
            }.padding(16)
            Rectangle().fill(Theme.background).frame(height: 5).padding(.top, 4)
            scenarioAnalysis.padding(16)
        }
    }

    private var currencyExposure: some View {
        VStack(spacing: 20) {
            GIVHalfRing(slices: slices, total: data.value, amount: store.amount(data.value))
                .frame(height: 180).padding(.horizontal, 8).padding(.top, 2)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 17) {
                ForEach(slices) { slice in
                    Button { selectedSlice = slice.name } label: {
                        HStack(spacing: 8) {
                            Rectangle().fill(slice.color).frame(width: 12, height: 12)
                            Text(slice.name).font(.system(size: 12))
                            Spacer(minLength: 3)
                            Text(data.percent(slice.value)).font(.system(size: 12, weight: selectedSlice == slice.name ? .semibold : .regular))
                        }.padding(.vertical, 4).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("giv.currency.\(slice.name)")
                }
            }
        }
    }

    private var regionExposure: some View {
        VStack(spacing: 4) {
            GIVRegionMap(slices: slices, selected: $selectedSlice).frame(height: 210)
            ForEach(slices) { slice in
                Button { selectedSlice = slice.name } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Rectangle().fill(slice.color).frame(width: 12, height: 12).padding(.top, 2)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(slice.name) (\(data.percent(slice.value)))").font(.system(size: 12))
                            Text(store.amount(slice.value)).font(.system(size: 15, weight: .semibold))
                        }
                        Spacer(minLength: 4)
                        let profit = data.entries.filter { $0.region == slice.name }.reduce(0) { $0 + $1.profit }
                        HStack(spacing: 3) {
                            Image(systemName: profit >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill").font(.system(size: 7)).accessibilityHidden(true)
                            Text(store.amount(profit)).font(.system(size: 11)).lineLimit(1).minimumScaleFactor(0.65)
                        }.foregroundStyle(profit >= 0 ? Theme.green : Theme.red).padding(.top, 21)
                    }.padding(.vertical, 11).background(selectedSlice == slice.name ? Theme.background : .clear).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("giv.region.\(slice.name)")
                Divider()
            }
        }
    }

    private var sectorExposure: some View {
        VStack(alignment: .leading, spacing: 12) {
            GIVSectorMap(slices: slices, selected: $selectedSlice).frame(height: 280)
            if let focused {
                HStack {
                    Rectangle().fill(focused.color.opacity(0.4)).frame(width: 12, height: 12)
                    Text(focused.name).font(.system(size: 12))
                    Spacer()
                    Text("\(store.amount(focused.value)) · \(data.percent(focused.value))").font(.system(size: 11, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
                }
            }
        }
    }

    private var insight: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation { expandedInsight.toggle() } } label: {
                HStack(spacing: 8) {
                    Image(systemName: exposure == "Currency" ? "dollarsign.arrow.circlepath" : exposure == "Region" ? "globe" : "chart.pie").foregroundStyle(Theme.red)
                    Text(exposure == "Currency" ? "Currency risks analysis" : exposure == "Region" ? "Regional Concentration analysis" : "Sector Allocation Analysis").font(.system(size: 13, weight: .medium))
                    Spacer(minLength: 2)
                    Image(systemName: expandedInsight ? "chevron.up" : "arrow.right").font(.system(size: 13, weight: .light))
                }.padding(13).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("giv.analysis.insight")
            Divider().padding(.horizontal, 12)
            Text(insightText).font(.system(size: 11)).lineSpacing(4).padding(13)
            if expandedInsight {
                Text(exposure == "Currency" ? "Exposure is grouped by the quotation currency of each holding. Currency hedges and underlying fund exposures are not modelled. The scenario below applies a change to the selected holdings’ converted value." : exposure == "Region" ? "Regions use the market classification stored with each holding. A fund may invest beyond its assigned region. Select a region above to inspect its value and unrealised gain/loss." : "Sector values use the classifications stored with each holding. Funds and structured products may span several sectors; these demo classifications use a single primary exposure.")
                    .font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(4).padding([.horizontal, .bottom], 13)
            }
        }.overlay(Rectangle().stroke(Theme.line))
    }

    private var insightText: String {
        guard let focused else { return "Select an account with holdings to see your exposure." }
        if exposure == "Currency" {
            let shock = SampleData.row("analytics", id: "default").double("currencyIllustrationShock")
            let magnitude = (abs(shock) * 100).formatted(.number.precision(.fractionLength(0...2)))
            return "\(focused.name) represents \(data.percent(focused.value)) of the selected portfolio. A \(magnitude)% \(shock < 0 ? "fall" : "rise") in this currency against \(store.currency.rawValue) would change the converted value of these holdings by \(store.amount(focused.name == store.currency.rawValue ? 0 : focused.value * shock))."
        }
        let threshold = SampleData.row("analytics", id: "default").double("concentrationThreshold")
        return "\(focused.name) accounts for \(data.percent(focused.value)) of your selected holdings. \(focused.value > data.value * threshold ? "This concentration makes this exposure a major contributor to changes in your portfolio value." : "Review this exposure alongside the other holdings to understand the balance of your portfolio.")"
    }

    private var scenarioLoss: Double { data.entries.reduce(0) { $0 + $1.value * scenario.shock(for: $1, reportingCurrency: store.currency) } }
    private var currentRisk: Double { riskScore(stressed: false) }
    private var stressedRisk: Double { riskScore(stressed: true) }

    private var scenarioAnalysis: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Scenario analysis").font(.system(size: 17, weight: .medium))
            Text("Explore how a market change could affect your portfolio value and its mix of risk exposures.").font(.system(size: 13)).foregroundStyle(Theme.muted).lineSpacing(4)
            Menu {
                ForEach(GIVScenario.allCases) { item in Button(item.title) { scenario = item } }
            } label: {
                HStack { Text(scenario.title).font(.system(size: 13)); Spacer(); Image(systemName: "chevron.down").font(.system(size: 15, weight: .light)) }
                    .padding(13).overlay(Rectangle().stroke(Theme.muted.opacity(0.5))).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("giv.scenario")
            HStack {
                Text("Illustrative change in value").font(.system(size: 12)).foregroundStyle(Theme.muted)
                Spacer()
                Text(store.amount(scenarioLoss)).font(.system(size: 14, weight: .semibold)).foregroundStyle(scenarioLoss < 0 ? Theme.red : Theme.muted)
            }.accessibilityElement(children: .combine).accessibilityIdentifier("giv.scenario.impact")
            HStack(spacing: 5) { Spacer(); Text("Portfolio risk level").font(.system(size: 12, weight: .medium)); Image(systemName: "questionmark.circle").font(.system(size: 12)); Spacer() }
            Chart {
                PointMark(x: .value("Risk score", currentRisk), y: .value("Market value", data.value)).foregroundStyle(GIVPortfolioData.colors[0]).symbolSize(220)
                PointMark(x: .value("Risk score", stressedRisk), y: .value("Market value", data.value + scenarioLoss)).foregroundStyle(Theme.red.opacity(0.6)).symbolSize(160)
            }
            .chartXScale(domain: 0...10).chartYScale(domain: 0...max(1, data.value * 1.3))
            .chartXAxis { AxisMarks(values: [0, 2, 4, 6, 8, 10]) { _ in AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4)); AxisValueLabel().font(.system(size: 10)) } }
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4))
                AxisValueLabel { if let amount = value.as(Double.self) { Text(store.hideAmounts ? "••••" : amount.formatted(.number.notation(.compactName))).font(.system(size: 9)) } }
            } }
            .chartYAxisLabel(store.currency.rawValue, position: .topLeading).chartXAxisLabel("Lower risk                                         Higher risk")
            .frame(height: 210)
            HStack(spacing: 24) {
                Label("Current portfolio", systemImage: "circle.fill").foregroundStyle(GIVPortfolioData.colors[0])
                Label("After scenario", systemImage: "circle.fill").foregroundStyle(Theme.red.opacity(0.7))
            }.font(.system(size: 11))
            Text("Illustrative stress test with fixed shocks and asset-class risk scores; no correlations, tax or fees are modelled.").font(.system(size: 10)).foregroundStyle(Theme.muted).lineSpacing(3)
        }
    }

    private func riskScore(stressed: Bool) -> Double {
        var numerator = 0.0, denominator = 0.0
        for entry in data.entries {
            let value = entry.value * (stressed ? 1 + scenario.shock(for: entry, reportingCurrency: store.currency) : 1)
            let score = SampleData.row("asset_profiles", id: entry.holding.category.rawValue).double("riskScore")
            numerator += value * score; denominator += value
        }
        return denominator > 0 ? numerator / denominator : 0
    }
}

private struct GIVScenario: Identifiable {
    let record: SampleRecord
    var id: String { record.id }
    var title: String { record.string("title") }
    static var allCases: [GIVScenario] { SampleData.rows("scenarios").map { GIVScenario(record: $0) } }
    static var configuredDefault: GIVScenario {
        GIVScenario(record: SampleData.row("scenarios", id: SampleData.row("analytics", id: "default").string("defaultScenarioID")))
    }

    func shock(for entry: GIVEntry, reportingCurrency: Currency) -> Double {
        let currencyMatches = record.list("currencies").contains(entry.holding.currency.rawValue)
        let assetMatches = record.list("assetClasses").contains(entry.holding.category.rawValue)
        let regionMatches = record.list("regions").contains(entry.region)
        guard currencyMatches || assetMatches || regionMatches else { return 0 }
        if currencyMatches && record.bool("skipMatchingReportingCurrency") && entry.holding.currency == reportingCurrency { return 0 }
        return record.double("shock")
    }
}

private struct GIVHalfRing: View {
    let slices: [GIVSlice]
    let total: Double
    let amount: String
    var body: some View {
        GeometryReader { geometry in
            let radius = min(geometry.size.width / 2 - 12, geometry.size.height - 20)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height - 12)
            ZStack(alignment: .bottom) {
                Path { path in path.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false) }.stroke(Theme.line, lineWidth: 20)
                ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                    let preceding = slices.prefix(index).reduce(0) { $0 + $1.value }
                    let from = 180 + (total > 0 ? preceding / total * 180 : 0)
                    let to = from + (total > 0 ? slice.value / total * 180 : 0)
                    Path { path in path.addArc(center: center, radius: radius, startAngle: .degrees(from + 0.5), endAngle: .degrees(max(from + 0.5, to - 0.5)), clockwise: false) }
                        .stroke(slice.color, lineWidth: 20)
                }
                VStack(spacing: 6) { Text("Total market value").font(.system(size: 11)).foregroundStyle(Theme.muted); Text(amount).font(.system(size: 19, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.65) }.frame(maxWidth: radius * 1.65).padding(.bottom, 32).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }.accessibilityLabel("Currency exposure, total market value \(amount)")
    }
}

private struct GIVSectorMap: View {
    let slices: [GIVSlice]
    @Binding var selected: String?
    private var columns: [[GIVSlice]] {
        guard let first = slices.first else { return [] }
        let rest = Array(slices.dropFirst())
        return [[first], rest.enumerated().filter { $0.offset % 2 == 0 }.map(\.element), rest.enumerated().filter { $0.offset % 2 != 0 }.map(\.element)].filter { !$0.isEmpty }
    }
    var body: some View {
        GeometryReader { geometry in
            let total = max(1, slices.reduce(0) { $0 + $1.value })
            HStack(spacing: 2) {
                ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                    let columnValue = column.reduce(0) { $0 + $1.value }
                    VStack(spacing: 2) {
                        ForEach(column) { slice in
                            let tileHeight = max(0, (geometry.size.height - CGFloat(column.count - 1) * 2) * slice.value / columnValue)
                            Button { selected = slice.name } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    if tileHeight > 36 { Text(slice.name).font(.system(size: 12, weight: .semibold)).lineLimit(3) }
                                    if slice.value / total > 0.10 { Text(String(format: "%.1f%%", slice.value / total * 100)).font(.system(size: 10)) }
                                    Spacer(minLength: 0)
                                }.padding(10).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                    .background(slice.color.opacity(0.3)).overlay(Rectangle().stroke(selected == slice.name ? Theme.ink : .clear, lineWidth: 1.5))
                                    .contentShape(Rectangle())
                            }.buttonStyle(.plain).frame(height: tileHeight).clipped().accessibilityLabel(slice.name)
                                .accessibilityIdentifier("giv.sector.\(slice.name)")
                        }
                    }.frame(width: max(0, (geometry.size.width - CGFloat(columns.count - 1) * 2) * columnValue / total))
                }
            }
        }.accessibilityLabel("Sector allocation")
    }
}

private struct GIVRegionMap: View {
    let slices: [GIVSlice]
    @Binding var selected: String?
    // A schematic world silhouette in normalised coordinates, rendered as a light dot map.
    private let continents: [[CGPoint]] = [
        [.init(x: 0.05, y: 0.16), .init(x: 0.16, y: 0.08), .init(x: 0.30, y: 0.15), .init(x: 0.36, y: 0.26), .init(x: 0.29, y: 0.39), .init(x: 0.25, y: 0.48), .init(x: 0.18, y: 0.40), .init(x: 0.13, y: 0.29)],
        [.init(x: 0.27, y: 0.48), .init(x: 0.38, y: 0.51), .init(x: 0.42, y: 0.62), .init(x: 0.34, y: 0.90), .init(x: 0.29, y: 0.77), .init(x: 0.29, y: 0.64)],
        [.init(x: 0.40, y: 0.06), .init(x: 0.47, y: 0.04), .init(x: 0.46, y: 0.19), .init(x: 0.41, y: 0.22)],
        [.init(x: 0.45, y: 0.29), .init(x: 0.52, y: 0.14), .init(x: 0.61, y: 0.13), .init(x: 0.70, y: 0.11), .init(x: 0.91, y: 0.23), .init(x: 0.97, y: 0.29), .init(x: 0.89, y: 0.35), .init(x: 0.86, y: 0.49), .init(x: 0.80, y: 0.53), .init(x: 0.79, y: 0.64), .init(x: 0.73, y: 0.56), .init(x: 0.69, y: 0.44), .init(x: 0.66, y: 0.54), .init(x: 0.59, y: 0.39), .init(x: 0.54, y: 0.35)],
        [.init(x: 0.46, y: 0.37), .init(x: 0.58, y: 0.38), .init(x: 0.64, y: 0.53), .init(x: 0.58, y: 0.70), .init(x: 0.55, y: 0.83), .init(x: 0.50, y: 0.71), .init(x: 0.48, y: 0.57), .init(x: 0.42, y: 0.47)],
        [.init(x: 0.80, y: 0.71), .init(x: 0.87, y: 0.67), .init(x: 0.93, y: 0.74), .init(x: 0.92, y: 0.84), .init(x: 0.81, y: 0.83)],
        [.init(x: 0.79, y: 0.62), .init(x: 0.87, y: 0.64), .init(x: 0.91, y: 0.68), .init(x: 0.81, y: 0.66)]
    ]
    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geometry in
                ZStack {
                    Canvas { context, size in
                    let paths = continents.map { points in Path { path in path.addLines(points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }); path.closeSubpath() } }
                    for x in stride(from: 0.0, through: size.width, by: 3.5) {
                        for y in stride(from: 0.0, through: size.height, by: 3.5) {
                            if paths.contains(where: { $0.contains(CGPoint(x: x, y: y)) }) { context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2.1, height: 2.1)), with: .color(Color(hex: 0xDADDDD))) }
                        }
                    }
                }
                    ForEach(slices) { slice in
                        if let point = coordinate(slice.name) {
                            let total = max(1, slices.reduce(0) { $0 + $1.value })
                            Button { selected = slice.name } label: {
                                Image(systemName: "hexagon.fill").resizable().scaledToFit().foregroundStyle(slice.color)
                                    .frame(width: 10 + sqrt(slice.value / total) * 42, height: 10 + sqrt(slice.value / total) * 42)
                                    .overlay { if selected == slice.name { Circle().stroke(slice.color.opacity(0.4), lineWidth: 2).padding(-5) } }
                                    .contentShape(Rectangle())
                            }.buttonStyle(.plain).position(x: point.x * geometry.size.width, y: point.y * geometry.size.height)
                                .accessibilityLabel("\(slice.name) exposure").accessibilityIdentifier("giv.map.\(slice.name)")
                        }
                    }
                }
            }
            if slices.contains(where: { coordinate($0.name) == nil }) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(slices.filter { coordinate($0.name) == nil }) { slice in
                            Button { selected = slice.name } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: slice.name.lowercased() == "global" ? "globe" : "questionmark.circle").foregroundStyle(slice.color)
                                    Text(slice.name).fontWeight(selected == slice.name ? .semibold : .regular)
                                    Text(String(format: "%.2f%%", slice.value / max(1, slices.reduce(0) { $0 + $1.value }) * 100))
                                }.font(.system(size: 11)).padding(.vertical, 6).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityIdentifier("giv.map.unmapped.\(slice.name)")
                        }
                    }
                }.frame(height: 28)
            }
        }
    }
    private func coordinate(_ region: String) -> CGPoint? {
        let value = region.lowercased()
        guard let region = SampleData.rows("regions").first(where: { row in row.list("aliases").contains { value.contains($0.lowercased()) } }) else { return nil }
        return CGPoint(x: region.double("mapX"), y: region.double("mapY"))
    }
}
