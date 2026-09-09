import SwiftUI
import Charts

struct GIVPerformanceView: View {
    @Environment(PortfolioStore.self) private var store
    let data: GIVPortfolioData
    @State private var market = "All markets"
    @State private var period = "month"
    @State private var metric = "TWRR"
    @State private var benchmarks: Set<String> = ["S&P 500"]
    @State private var selectedDate: Date?
    @State private var customDates = false
    @State private var metricInfo = false
    @State private var start = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 9))!
    @State private var end = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 9))!
    @State private var draftStart = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 9))!
    @State private var draftEnd = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 9))!

    private static let anchor = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 9))!
    private let benchmarkNames = ["S&P 500", "HSBC reference portfolio", "HSI"]
    private var range: ClosedRange<Date> {
        if period == "custom" { return min(start, end)...max(start, end) }
        let first = Calendar.current.date(byAdding: period == "year" ? .year : .month, value: -1, to: Self.anchor) ?? Self.anchor
        return first...Self.anchor
    }
    private var entries: [GIVEntry] { data.entries.filter { market == "All markets" || $0.region == market } }
    private var invested: Double { entries.reduce(0) { $0 + $1.cost } }
    private var mySeries: [GIVHistoryPoint] { history(for: "My total return") }
    private var allPoints: [GIVHistoryPoint] { mySeries + benchmarkNames.filter { benchmarks.contains($0) }.flatMap { history(for: $0) } }
    private var finalReturn: Double { mySeries.last?.value ?? 0 }
    private var activePoint: GIVHistoryPoint? {
        guard let selectedDate else { return mySeries.last }
        return mySeries.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Total return").font(.system(size: 17, weight: .medium))
                Button { metricInfo = true } label: { Image(systemName: "questionmark.circle").font(.system(size: 14)).contentShape(Rectangle()) }.buttonStyle(.plain).accessibilityLabel("About total return")
                Spacer()
                Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 18, weight: .light))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(["All markets", "Hong Kong", "Mainland China", "Singapore", "United States"], id: \.self) { name in
                        Button { market = name; selectedDate = nil } label: {
                            Text(name).font(.system(size: 11)).padding(.horizontal, 12).padding(.vertical, 10)
                                .foregroundStyle(market == name ? .white : Theme.ink)
                                .background(market == name ? Theme.ink : .white, in: Capsule())
                                .overlay(Capsule().stroke(market == name ? .clear : Theme.line))
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("giv.performance.market.\(name)")
                            .accessibilityAddTraits(market == name ? .isSelected : [])
                    }
                }
            }
            HStack(spacing: 0) {
                periodButton("Past 1 month", value: "month")
                periodButton("Past 1 year", value: "year")
                periodButton("Customized", value: "custom")
            }.padding(2).background(Theme.background, in: Capsule())
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(period == "month" ? "Past 1 month’s total return" : period == "year" ? "Past 1 year’s total return" : "Selected period’s total return").font(.system(size: 11)).foregroundStyle(Theme.muted)
                    HStack(spacing: 3) {
                        Image(systemName: finalReturn >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill").font(.system(size: 8)).accessibilityHidden(true)
                        Text(store.amount(invested * finalReturn / 100)).font(.system(size: 21, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.65)
                    }.foregroundStyle(finalReturn >= 0 ? Theme.green : Theme.red).accessibilityElement(children: .combine).accessibilityIdentifier("giv.performance.return")
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 7) {
                    Menu {
                        Button("Time-weighted return (TWRR)") { metric = "TWRR" }
                        Button("Money-weighted return (MWRR)") { metric = "MWRR" }
                        Button("How returns are calculated") { metricInfo = true }
                    } label: { HStack(spacing: 4) { Text(metric); Image(systemName: "chevron.down") }.font(.system(size: 11)).foregroundStyle(Theme.muted).contentShape(Rectangle()) }
                        .accessibilityIdentifier("giv.performance.metric")
                    Text(String(format: "%+.2f%%", finalReturn)).font(.system(size: 21, weight: .semibold)).foregroundStyle(finalReturn >= 0 ? Theme.green : Theme.red)
                }
            }.padding(.top, 8)
            Text("\(dateText(range.lowerBound)) – \(dateText(range.upperBound))").font(.system(size: 10)).foregroundStyle(Theme.muted).padding(.top, -9)
            if entries.isEmpty {
                Text("No holdings in this market for the selected accounts.").font(.system(size: 13)).foregroundStyle(Theme.muted).frame(maxWidth: .infinity).padding(.vertical, 40)
            } else {
                tooltip
                performanceChart
                legend
            }
            Text("Illustrative performance · Demo history and benchmark series. No external cash flows are modelled, so TWRR and MWRR are equal.")
                .font(.system(size: 10)).foregroundStyle(Theme.muted).lineSpacing(3)
        }
        .padding(16)
        .sheet(isPresented: $customDates) { datePickerSheet }
        .alert("About portfolio returns", isPresented: $metricInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This demo constructs a repeatable illustrative history from the selected holdings and date range. Total return includes the modelled change in value. TWRR removes the effect of external cash flows; MWRR reflects their timing. This demo models no external flows, so both rates are equal. The chart is not an actual investment performance record.")
        }
    }

    private func periodButton(_ title: String, value: String) -> some View {
        Button {
            if value == "custom" { draftStart = start; draftEnd = end; customDates = true }
            else { period = value; selectedDate = nil }
        } label: {
            Text(title).font(.system(size: 11)).frame(maxWidth: .infinity).frame(height: 38)
                .background(period == value ? .white : .clear, in: Capsule())
                .overlay(Capsule().stroke(period == value ? Theme.line : .clear))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("giv.performance.period.\(value)")
            .accessibilityAddTraits(period == value ? .isSelected : [])
    }

    private var tooltip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text((activePoint?.date ?? range.upperBound).formatted(.dateTime.day().month(.abbreviated).year())).font(.system(size: 11)).foregroundStyle(Theme.muted)
            HStack(spacing: 6) {
                Image(systemName: "circle.fill").font(.system(size: 9)).foregroundStyle(GIVPortfolioData.colors[0])
                Text("My total return").font(.system(size: 11))
                Spacer(minLength: 0)
                let value = activePoint?.value ?? 0
                Text("\(store.amount(invested * value / 100)) (\(String(format: "%+.2f%%", value)))").font(.system(size: 11, weight: .semibold)).foregroundStyle(value >= 0 ? Theme.green : Theme.red).lineLimit(1).minimumScaleFactor(0.7)
            }
            ForEach(benchmarkNames.filter { benchmarks.contains($0) }, id: \.self) { name in
                HStack(spacing: 6) {
                    Image(systemName: "square.fill").font(.system(size: 9)).foregroundStyle(color(for: name))
                    Text(name).font(.system(size: 11))
                    let values = history(for: name)
                    let point = values.min { abs($0.date.timeIntervalSince(activePoint?.date ?? range.upperBound)) < abs($1.date.timeIntervalSince(activePoint?.date ?? range.upperBound)) }
                    Text(String(format: "%+.2f%%", point?.value ?? 0)).font(.system(size: 11, weight: .semibold)).foregroundStyle((point?.value ?? 0) >= 0 ? Theme.green : Theme.red)
                    Spacer(minLength: 0)
                }
            }
        }.padding(14).overlay(Rectangle().stroke(Theme.line)).accessibilityIdentifier("giv.performance.tooltip")
    }

    private var performanceChart: some View {
        Chart {
            ForEach(allPoints) { point in
                LineMark(x: .value("Date", point.date), y: .value("Return %", point.value), series: .value("Series", point.series))
                    .foregroundStyle(color(for: point.series)).lineStyle(StrokeStyle(lineWidth: 1.4)).interpolationMethod(.linear)
            }
            RuleMark(y: .value("Zero", 0)).foregroundStyle(Theme.muted.opacity(0.7)).lineStyle(StrokeStyle(lineWidth: 0.7))
            if let point = activePoint {
                RuleMark(x: .value("Selected date", point.date)).foregroundStyle(Theme.muted.opacity(0.6)).lineStyle(StrokeStyle(lineWidth: 0.7))
                PointMark(x: .value("Date", point.date), y: .value("Return %", point.value)).foregroundStyle(GIVPortfolioData.colors[0]).symbolSize(36)
            }
        }
        .chartXScale(domain: range).chartXSelection(value: $selectedDate)
        .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 7)) { _ in AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4)); AxisValueLabel().font(.system(size: 10)) } }
        .chartXAxis(.hidden)
        .chartYAxisLabel("%", position: .topLeading).chartLegend(.hidden)
        .frame(height: 280)
        .padding(.bottom, 22)
        .overlay(alignment: .bottom) {
            HStack {
                Text(dateText(range.lowerBound)).accessibilityIdentifier("giv.performance.range.start")
                Spacer(minLength: 12)
                Text(dateText(range.upperBound)).accessibilityIdentifier("giv.performance.range.end")
            }.font(.system(size: 10)).foregroundStyle(Theme.muted)
        }
        .accessibilityLabel("Illustrative portfolio performance. Drag to inspect a date.")
        .accessibilityIdentifier("giv.performance.chart")
    }

    private var legend: some View {
        LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 14) {
            Label("My total return", systemImage: "circle.fill").font(.system(size: 11)).foregroundStyle(GIVPortfolioData.colors[0])
            ForEach(benchmarkNames, id: \.self) { name in
                Button {
                    if benchmarks.contains(name) { benchmarks.remove(name) } else { benchmarks.insert(name) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: benchmarks.contains(name) ? "largecircle.fill.circle" : "circle").font(.system(size: 19, weight: .light))
                        Image(systemName: name == "HSI" ? "diamond.fill" : name == "S&P 500" ? "square.fill" : "triangle.fill").font(.system(size: 8)).foregroundStyle(color(for: name))
                        Text(name).font(.system(size: 10)).lineLimit(2)
                    }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("giv.performance.benchmark.\(name)")
                    .accessibilityAddTraits(benchmarks.contains(name) ? .isSelected : [])
            }
        }
    }

    private var datePickerSheet: some View {
        NavigationStack {
            Form {
                DatePicker("From", selection: $draftStart, in: ...draftEnd, displayedComponents: .date)
                DatePicker("To", selection: $draftEnd, in: draftStart...Self.anchor, displayedComponents: .date)
                Text("Choose a period to explore the illustrative return series.").font(.footnote).foregroundStyle(Theme.muted)
            }.navigationTitle("Choose a period").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { customDates = false } }
                    ToolbarItem(placement: .confirmationAction) { Button("Apply") { start = draftStart; end = draftEnd; period = "custom"; selectedDate = nil; customDates = false }.disabled(draftStart >= draftEnd).accessibilityIdentifier("giv.performance.dates.apply") }
                }
        }.presentationDetents([.medium])
    }

    private func color(for series: String) -> Color {
        switch series { case "S&P 500": Color(hex: 0xC7355C); case "HSBC reference portfolio": Color(hex: 0x4BAA08); case "HSI": Color(hex: 0xEF7046); default: GIVPortfolioData.colors[0] }
    }
    private func dateText(_ date: Date) -> String { date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits)) }

    // A deterministic scenario series, deliberately separate from the current-value calculation.
    private func history(for series: String) -> [GIVHistoryPoint] {
        let days = max(1, range.upperBound.timeIntervalSince(range.lowerBound) / 86_400)
        let duration = min(3, days / 365)
        let baseRate = invested > 0 ? entries.reduce(0) { $0 + $1.profit } / invested * 100 : 0
        // Benchmark paths must remain identical when the account or market selection changes.
        let seedSource = series == "My total return"
            ? entries.reduce(0) { $0 + $1.holding.symbol.unicodeScalars.reduce(0) { $0 + Int($1.value) } }
            : series.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let seed = Double(seedSource % 97) / 97
        let target: Double
        switch series {
        case "S&P 500": target = 8.7 * duration + 0.9 * sqrt(duration)
        case "HSBC reference portfolio": target = 5.3 * duration + 0.5 * sqrt(duration)
        case "HSI": target = 6.1 * duration - 0.7 * sqrt(duration)
        default: target = baseRate * min(1, 0.25 + duration * 0.75)
        }
        return (0...60).map { index in
            let x = Double(index) / 60
            let amplitude = series == "My total return" ? 2.6 : 0.8
            let wave = (sin(x * 19 + seed * 8) + sin(x * 61 + seed * 13) * 0.34) * sin(x * .pi) * amplitude * sqrt(max(0.08, duration))
            return GIVHistoryPoint(series: series, index: index, date: range.lowerBound.addingTimeInterval(range.upperBound.timeIntervalSince(range.lowerBound) * x), value: target * x + wave)
        }
    }
}

private struct GIVHistoryPoint: Identifiable {
    var id: String { series + String(index) }
    let series: String
    let index: Int
    let date: Date
    let value: Double
}
