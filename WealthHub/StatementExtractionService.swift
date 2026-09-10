import Foundation
import PDFKit
import UIKit
import Vision
import ImageIO

/// Reads local statements only. Imported rows always need confirmation before saving.
enum StatementExtractionService {
    struct ExtractionResult {
        var holdings: [Holding]
        var account: DetectedAccount?
        var warnings: [String]
    }

    struct DetectedAccount {
        var name: String
        var institution: String
        var currency: Currency
        var market: String?
        var accountNumber: String?
        var evidence: String
    }

    enum ExtractionError: LocalizedError {
        case invalid(String)
        var errorDescription: String? {
            if case .invalid(let message) = self { return message }
            return nil
        }
    }

    private static let maximumBytes = 10 * 1_024 * 1_024
    private static let maximumPages = 5
    private static let maximumRows = 1_000

    /// Explicitly illustrative sample data; never used as a fallback for a user's file.
    static var sampleHoldings: [Holding] {
        SampleData.holdings(in: "statement-preview")
    }

    static func extract(url: URL) async throws -> ExtractionResult {
        try await Task.detached(priority: .userInitiated) {
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
            try Task.checkCancellation()
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
            guard let size, size > 0, size <= maximumBytes else {
                throw ExtractionError.invalid("Choose a statement smaller than 10 MB.")
            }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard data.count <= maximumBytes else {
                throw ExtractionError.invalid("Choose a statement smaller than 10 MB.")
            }
            let fileExtension = url.pathExtension.lowercased()
            if fileExtension == "csv" {
                guard let text = String(data: data, encoding: .utf8) else {
                    throw ExtractionError.invalid("Save the CSV as UTF-8 and try again.")
                }
                return ExtractionResult(holdings: try validated(StatementParser.parse(text)), account: nil, warnings: [])
            }
            if fileExtension == "pdf" || data.starts(with: Data("%PDF-".utf8)) {
                return try extractPDF(data)
            }
            // ImageIO checks dimensions before decoding an untrusted image.
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
                  let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
                  width.doubleValue * height.doubleValue <= 40_000_000,
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 3_000
                  ] as CFDictionary) else {
                throw ExtractionError.invalid("Choose a PDF, a supported image, or the CSV template. Images must be under 40 megapixels.")
            }
            return try parseStatementText(recognize(cgImage, orientation: .up))
        }.value
    }

    static func extract(image: UIImage) async throws -> ExtractionResult {
        try await Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            guard let cgImage = image.cgImage,
                  Double(cgImage.width) * Double(cgImage.height) <= 40_000_000 else {
                throw ExtractionError.invalid("Choose a clear statement image under 40 megapixels.")
            }
            let orientation: CGImagePropertyOrientation
            switch image.imageOrientation {
            case .up: orientation = .up
            case .down: orientation = .down
            case .left: orientation = .left
            case .right: orientation = .right
            case .upMirrored: orientation = .upMirrored
            case .downMirrored: orientation = .downMirrored
            case .leftMirrored: orientation = .leftMirrored
            case .rightMirrored: orientation = .rightMirrored
            @unknown default: orientation = .up
            }
            return try parseStatementText(recognize(cgImage, orientation: orientation))
        }.value
    }

    private static func extractPDF(_ data: Data) throws -> ExtractionResult {
        guard let document = PDFDocument(data: data), !document.isLocked else {
            throw ExtractionError.invalid("This PDF could not be opened. Export an unlocked statement and try again.")
        }
        guard document.pageCount > 0, document.pageCount <= maximumPages else {
            throw ExtractionError.invalid("Import a statement of up to 5 pages. Export just the holdings pages from a longer statement.")
        }
        var result = ExtractionResult(holdings: [], account: nil, warnings: [])
        for index in 0..<document.pageCount {
            try Task.checkCancellation()
            guard let page = document.page(at: index) else { continue }
            var pageResult = try parseDocumentText(page.string ?? "")
            if pageResult.holdings.isEmpty {
                let bounds = page.bounds(for: .mediaBox)
                if bounds.width > 0, bounds.height > 0 {
                    let scale = min(3, 2_400 / max(bounds.width, bounds.height))
                    let thumbnail = page.thumbnail(of: CGSize(width: bounds.width * scale, height: bounds.height * scale), for: .mediaBox)
                    if let cgImage = thumbnail.cgImage {
                        pageResult = try parseDocumentText(recognize(cgImage, orientation: .up))
                    }
                }
            }
            result.holdings.append(contentsOf: pageResult.holdings)
            result.warnings.append(contentsOf: pageResult.warnings)
            if pageResult.holdings.isEmpty {
                result.warnings.append("No holdings were recognized on page \(index + 1). Check that no positions are missing.")
            }
            if result.account == nil { result.account = pageResult.account }
        }
        result.holdings = try validated(result.holdings)
        result.warnings = uniqueWarnings(result.warnings)
        return result
    }

    private static func recognize(_ image: CGImage, orientation: CGImagePropertyOrientation) throws -> String {
        try Task.checkCancellation()
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false // Preserve ticker symbols and company names.
        request.recognitionLanguages = ["en-US", "zh-Hant", "zh-Hans"]
        try VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])
        let observations = (request.results ?? []).filter {
            ($0.topCandidates(1).first?.confidence ?? 0) >= 0.35
        }.sorted { $0.boundingBox.midY > $1.boundingBox.midY }
        // Vision may return each table cell separately; rebuild rows using their positions.
        var lines: [[VNRecognizedTextObservation]] = []
        for observation in observations {
            if let last = lines.last, let anchor = last.first,
               abs(anchor.boundingBox.midY - observation.boundingBox.midY) <= min(anchor.boundingBox.height, observation.boundingBox.height) * 0.45 {
                lines[lines.count - 1].append(observation)
            } else {
                lines.append([observation])
            }
        }
        let text = lines.map { line in
            line.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\t")
        }.joined(separator: "\n")
        guard isFutuTable(text),
              let quantityColumn = observations.first(where: { compactText($0.topCandidates(1).first?.string ?? "").contains("mv/qty") }),
              let priceColumn = observations.first(where: { compactText($0.topCandidates(1).first?.string ?? "") == "price/" }),
              let profitColumn = observations.first(where: { compactText($0.topCandidates(1).first?.string ?? "").hasPrefix("today") }),
              quantityColumn.boundingBox.minX < priceColumn.boundingBox.minX,
              priceColumn.boundingBox.minX < profitColumn.boundingBox.minX else { return text }

        // FUTU stacks name/MV/price/P&L above symbol/quantity/cost. Preserve empty
        // cells by position so a missing price cannot shift today's P&L into its place.
        return lines.map { line in
            let ordered = line.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
            let raw = ordered.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\t")
            guard let first = ordered.first, let firstText = first.topCandidates(1).first?.string,
                  first.boundingBox.minX < quantityColumn.boundingBox.minX - 0.03,
                  validName(firstText), ordered.dropFirst().contains(where: {
                      number($0.topCandidates(1).first?.string ?? "") != nil
                  }) else { return raw }
            var columns = Array(repeating: "", count: 4)
            for observation in ordered {
                guard let value = observation.topCandidates(1).first?.string else { continue }
                let index: Int
                if observation.boundingBox.minX < quantityColumn.boundingBox.minX - 0.03 { index = 0 }
                else if observation.boundingBox.midX < priceColumn.boundingBox.minX - 0.015 { index = 1 }
                else if observation.boundingBox.midX < profitColumn.boundingBox.minX - 0.015 { index = 2 }
                else { index = 3 }
                columns[index] += (columns[index].isEmpty ? "" : " ") + value
            }
            return columns.joined(separator: "\t")
        }.joined(separator: "\n")
    }

    /// A local, editable import proposal. Recognition never establishes a bank link.
    static func parseStatementText(_ text: String) throws -> ExtractionResult {
        var result = try parseDocumentText(text)
        result.holdings = try validated(result.holdings)
        result.warnings = uniqueWarnings(result.warnings)
        return result
    }

    private static func parseDocumentText(_ text: String) throws -> ExtractionResult {
        guard text.utf8.count <= 500_000 else {
            throw ExtractionError.invalid("This statement has too much text. Export only the holdings pages.")
        }
        if isFutuTable(text) { return try parseFutuTable(text) }
        var result = try parseGenericText(text)
        let header = statementHeader(in: text)
        let normalized = compactText(header)
        let hasBrand = firstMatch(#"\b(?:futu|moomoo)\b|富途"#, in: header) != nil
        if hasBrand && (normalized.contains("accounts") || normalized.contains("statement")), !result.holdings.isEmpty {
            result.account = futuAccount(currency: result.holdings.first?.currency ?? .SGD,
                                         evidence: "FUTU / moomoo is printed in the imported statement. Confirm the institution and account details.")
        }
        return result
    }

    private static func compactText(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
    }

    private static func statementHeader(in text: String) -> String {
        // A held security can itself be FUTU. Institution evidence must precede
        // the holdings table or explicit position rows, never come from a ticker.
        text.components(separatedBy: .newlines).prefix { line in
            let columns = tableColumns(line)
            let header = columns.map(normalizedHeader)
            if header.contains("quantity") && (header.contains("name") || header.contains("symbol")) { return false }
            if compactText(line).contains("mv/qty") { return false }
            if explicitHolding(line, defaultCurrency: .SGD) != nil { return false }
            if columns.count >= 3 && columns.dropFirst().contains(where: { number($0) != nil }) { return false }
            return true
        }.joined(separator: "\n")
    }

    private static func isFutuTable(_ text: String) -> Bool {
        let value = compactText(text)
        let columns = value.contains("mv/qty") && value.contains("price/") && value.contains("cost") && value.contains("symbol")
        let brand = firstMatch(#"\b(?:futu|moomoo)\b|富途"#, in: statementHeader(in: text)) != nil
        let signature = ["accounts", "maxbuyingpower", "excessliquidity", "riskstatus", "marketvalue", "positionp/l"]
            .allSatisfy(value.contains)
        return columns && (brand || signature)
    }

    private static func futuAccount(currency: Currency, evidence: String) -> DetectedAccount {
        DetectedAccount(name: "FUTU investment account", institution: "FUTU", currency: currency,
                        market: nil, accountNumber: nil, evidence: evidence)
    }

    private static func parseFutuTable(_ text: String) throws -> ExtractionResult {
        let lines = text.components(separatedBy: .newlines)
        var holdings: [Holding] = []
        var warnings = ["Only visible holdings are included. Account balances and buying power are excluded."]
        var sectionCurrency: Currency?
        var sectionRegion: String?
        var firstCurrency: Currency?
        var insideTable = false
        var pending: [String]?

        func unfinishedRow() {
            if let pending {
                warnings.append("\(pending[0]): quantity or average cost could not be read. This position was not imported.")
            }
            pending = nil
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            // A market/currency section is a holdings currency, not evidence of the
            // account's opening market. Totals in these headings are deliberately ignored.
            if let match = firstMatch(#"(?:^|\s)(SG|US|HK|CN)\s+(?:[+−-]?[0-9]|\()"#, in: line),
               let range = Range(match.range(at: 1), in: line) {
                unfinishedRow()
                insideTable = false
                sectionCurrency = nil
                sectionRegion = nil
                let market = String(line[range]).uppercased()
                let expected: [String: (Currency, String)] = [
                    "SG": (.SGD, "Singapore"), "US": (.USD, "United States"),
                    "HK": (.HKD, "Hong Kong"), "CN": (.CNY, "Mainland China")
                ]
                if let (expectedCurrency, region) = expected[market], currency(in: line) == expectedCurrency {
                    sectionCurrency = expectedCurrency
                    sectionRegion = region
                    if firstCurrency == nil { firstCurrency = expectedCurrency }
                } else {
                    warnings.append("\(market): the section currency is missing or does not match its market. Positions in this section were not imported.")
                }
                continue
            }
            let compact = compactText(line)
            if compact.contains("cashuniversalaccount") || compact.contains("watchlists") {
                unfinishedRow()
                insideTable = false
                continue
            }
            if compact.contains("mv/qty") {
                unfinishedRow()
                insideTable = true
                continue
            }
            guard insideTable else { continue }
            if compact.contains("marketvalue") || compact.contains("positionp/l") {
                unfinishedRow()
                insideTable = false
                continue
            }
            // Reconstructed Vision rows retain empty columns. Plain text tables may
            // instead use pipes or repeated spaces, which are handled without guessing.
            let columns = rawLine.contains("\t")
                ? rawLine.components(separatedBy: "\t").map { $0.trimmingCharacters(in: .whitespaces) }
                : tableColumns(line)
            guard let name = columns.first, validName(name), !isFutuHeader(name) else { continue }

            if let top = pending {
                let isTicker = name.range(of: #"^[A-Z0-9][A-Z0-9.\-]{0,11}$"#, options: .regularExpression) != nil
                // The second line has symbol/quantity/cost, with no daily P&L cell.
                let isDetail = isTicker && columns.count >= 3 && (columns.count == 3 || columns.dropFirst(3).allSatisfy(\.isEmpty))
                if isDetail {
                    pending = nil
                    guard let quantity = number(columns[1]), quantity > 0,
                          let cost = number(columns[2]), let price = number(top[2]),
                          let sectionCurrency else {
                        warnings.append("\(top[0]): quantity, price, cost or currency is missing or unclear. This position was not imported.")
                        continue
                    }
                    let holding = Holding(name: top[0], symbol: name, category: .stock, currency: sectionCurrency,
                                          quantity: quantity, price: price, averageCost: cost, region: sectionRegion)
                    guard validAmounts(holding) else {
                        warnings.append("\(top[0]): check the quantity and amounts. This position was not imported.")
                        continue
                    }
                    holdings.append(holding)
                    if top[0].contains("...") || top[0].contains("…") {
                        warnings.append("\(name): the security name is truncated in the image. Confirm or edit its full name.")
                    }
                    if let shownValue = number(top[1]), abs(shownValue - holding.value) > max(0.05, holding.value * 0.005) {
                        warnings.append("\(name): the displayed market value differs from quantity × price. Check the recognized values.")
                    }
                    guard holdings.count <= maximumRows else {
                        throw ExtractionError.invalid("Import up to 1,000 holdings at a time.")
                    }
                    continue
                }
                unfinishedRow()
            }
            // A first line needs the complete four-column layout. A loose three-cell
            // fragment could be a ticker/quantity/cost line with its name row cropped.
            if columns.count >= 4, number(columns[1]) != nil, number(columns[2]) != nil {
                pending = columns
            } else if columns.count > 1, columns.dropFirst().contains(where: { number($0) != nil }) {
                warnings.append("\(name): the position row is incomplete. It was not imported; check the original image.")
            }
        }
        unfinishedRow()
        return ExtractionResult(holdings: holdings,
                                account: futuAccount(currency: firstCurrency ?? holdings.first?.currency ?? .SGD,
                                                     evidence: "Suggested from the FUTU / moomoo account screen. Confirm the account market and reporting currency."),
                                warnings: uniqueWarnings(warnings))
    }

    private static func isFutuHeader(_ text: String) -> Bool {
        let value = compactText(text)
        return ["symbol", "mv/qty", "price", "cost", "today", "p/l"].contains(where: value.hasPrefix)
    }

    private static func uniqueWarnings(_ warnings: [String]) -> [String] {
        var seen = Set<String>()
        return warnings.filter { seen.insert($0).inserted }
    }

    /// Parses explicit "NAME 100 shares" rows or tables with named quantity columns.
    /// Unlabeled numbers are never guessed to be prices; unknown prices/costs remain zero.
    static func parseText(_ text: String) throws -> [Holding] {
        try parseGenericText(text).holdings
    }

    private static func parseGenericText(_ text: String) throws -> ExtractionResult {
        guard text.utf8.count <= 500_000 else {
            throw ExtractionError.invalid("This statement has too much text. Export only the holdings pages.")
        }
        let lines = text.components(separatedBy: .newlines)
        let defaultCurrency = currency(in: text) ?? .HKD
        var header: [String]?
        var result: [Holding] = []
        var warnings: [String] = []
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            let columns = tableColumns(line)
            let normalized = columns.map(normalizedHeader)
            if normalized.contains("quantity"), normalized.contains("name") || normalized.contains("symbol") {
                header = normalized
                continue
            }
            if let header, columns.count == header.count,
               let row = tableHolding(columns, header: header, defaultCurrency: defaultCurrency) {
                result.append(row)
            } else if let row = explicitHolding(line, defaultCurrency: defaultCurrency) {
                result.append(row)
            } else if header != nil, columns.count > 1, let name = columns.first, validName(name) {
                warnings.append("\(name): a table row could not be fully recognized. Check that no positions are missing.")
            }
            guard result.count <= maximumRows else {
                throw ExtractionError.invalid("Import up to 1,000 holdings at a time.")
            }
        }
        if result.contains(where: { $0.price == 0 || $0.averageCost == 0 }) {
            warnings.append("Some prices or average costs are missing or zero. Review them before saving.")
        }
        if currency(in: text) == nil, !result.isEmpty {
            warnings.append("Check each holding's currency, especially if the statement contains several currencies.")
        }
        return ExtractionResult(holdings: result, account: nil, warnings: uniqueWarnings(warnings))
    }

    private static func tableColumns(_ text: String) -> [String] {
        text.components(separatedBy: "|").flatMap { part in
            part.components(separatedBy: "\t").flatMap { segment in
                segment.replacingOccurrences(of: #" {2,}"#, with: "\t", options: .regularExpression).components(separatedBy: "\t")
            }
        }.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private static func normalizedHeader(_ text: String) -> String {
        let value = text.lowercased().trimmingCharacters(in: .whitespaces)
        switch value {
        case "name", "security", "security name", "description", "stock", "holding", "instrument": return "name"
        case "symbol", "ticker", "stock code", "code": return "symbol"
        case "quantity", "qty", "shares", "units", "no. of shares", "holding quantity": return "quantity"
        case "price", "unit price", "market price", "current price": return "price"
        case "average cost", "avg cost", "avg. cost", "cost per share", "unit cost": return "averageCost"
        case "currency", "ccy": return "currency"
        default: return value
        }
    }

    private static func tableHolding(_ columns: [String], header: [String], defaultCurrency: Currency) -> Holding? {
        func cell(_ key: String) -> String? {
            guard let index = header.firstIndex(of: key), columns.indices.contains(index) else { return nil }
            return columns[index]
        }
        guard let quantityText = cell("quantity"), let quantity = number(quantityText), quantity > 0,
              let name = cell("name") ?? cell("symbol"), validName(name) else { return nil }
        guard let price = optionalAmount(cell("price")),
              let cost = optionalAmount(cell("averageCost")) else { return nil }
        let holding = Holding(name: name, symbol: cell("symbol") ?? inferredSymbol(name), category: .stock,
                              currency: cell("currency").flatMap(currency(in:)) ?? defaultCurrency,
                              quantity: quantity, price: price, averageCost: cost)
        return validAmounts(holding) ? holding : nil
    }

    private static func explicitHolding(_ line: String, defaultCurrency: Currency) -> Holding? {
        let pattern = #"^(.+?)\s+([0-9][0-9,.\u00a0\u202f'’ ]*)\s+(?:shares?|units?)(?:\b)(.*)$"#
        guard let match = firstMatch(pattern, in: line),
              let nameRange = Range(match.range(at: 1), in: line),
              let quantityRange = Range(match.range(at: 2), in: line),
              let suffixRange = Range(match.range(at: 3), in: line) else { return nil }
        let name = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
        guard validName(name), let quantity = number(String(line[quantityRange])), quantity > 0 else { return nil }
        let suffix = String(line[suffixRange])
        guard let price = optionalAmount(labeledAmount(#"(?:unit price|market price|current price|price)"#, in: suffix)),
              let cost = optionalAmount(labeledAmount(#"(?:average cost|avg\.? cost|cost per share|unit cost)"#, in: suffix)) else { return nil }
        let holding = Holding(name: name, symbol: inferredSymbol(name), category: .stock,
                              currency: currency(in: line) ?? defaultCurrency,
                              quantity: quantity, price: price, averageCost: cost)
        return validAmounts(holding) ? holding : nil
    }

    private static func labeledAmount(_ label: String, in text: String) -> String? {
        let pattern = #"\b"# + label + #"\s*[:=]?\s*(?:(?:HKD|SGD|USD|CNY|HK\$|S\$|US\$|\$|¥)\s*)?([^\s;|]+)"#
        guard let match = firstMatch(pattern, in: text), let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    private static func optionalAmount(_ text: String?) -> Double? {
        guard let text else { return 0 }
        if ["", "—", "–", "-", "n/a"].contains(text.trimmingCharacters(in: .whitespaces).lowercased()) { return 0 }
        return number(text)
    }

    private static func number(_ text: String) -> Double? {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        value = value.replacingOccurrences(of: #"^(HKD|SGD|USD|CNY|HK\$|S\$|US\$|\$|¥)\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
        guard !value.isEmpty, value.range(of: #"^[0-9][0-9,.\u00a0\u202f'’ ]*$"#, options: .regularExpression) != nil else { return nil }
        // Spaces and apostrophes are accepted only as complete three-digit grouping.
        for separator in [" ", "\u{00a0}", "\u{202f}", "'", "’"] where value.contains(separator) {
            let escaped = NSRegularExpression.escapedPattern(for: separator)
            guard value.range(of: "^[0-9]{1,3}(" + escaped + "[0-9]{3})+([.,][0-9]+)?$", options: .regularExpression) != nil else { return nil }
            value = value.replacingOccurrences(of: separator, with: "")
        }
        if value.contains(","), value.contains(".") {
            let decimal = value.lastIndex(of: ",")! > value.lastIndex(of: ".")! ? "," : "."
            let grouping = decimal == "," ? "." : ","
            let d = NSRegularExpression.escapedPattern(for: decimal)
            let g = NSRegularExpression.escapedPattern(for: grouping)
            guard value.range(of: "^[0-9]{1,3}(" + g + "[0-9]{3})+" + d + "[0-9]+$", options: .regularExpression) != nil else { return nil }
            value = value.replacingOccurrences(of: grouping, with: "").replacingOccurrences(of: decimal, with: ".")
        } else if value.contains(",") {
            if value.range(of: #"^[1-9][0-9]{0,2}(,[0-9]{3})+$"#, options: .regularExpression) != nil {
                value = value.replacingOccurrences(of: ",", with: "")
            } else if value.range(of: #"^[0-9]+,[0-9]{1,2}$"#, options: .regularExpression) != nil {
                value = value.replacingOccurrences(of: ",", with: ".")
            } else { return nil }
        } else if value.filter({ $0 == "." }).count > 1 {
            guard value.range(of: #"^[1-9][0-9]{0,2}(\.[0-9]{3})+$"#, options: .regularExpression) != nil else { return nil }
            value = value.replacingOccurrences(of: ".", with: "")
        }
        guard let result = Double(value), result.isFinite, result >= 0, result <= 1_000_000_000 else { return nil }
        return result
    }

    private static func currency(in text: String) -> Currency? {
        let normalized = text.uppercased()
        let matches: [(Currency, String)] = [(.HKD, #"\bHKD\b|HK\$"#), (.SGD, #"\bSGD\b|S\$"#), (.USD, #"\bUSD\b|US\$"#), (.CNY, #"\bCNY\b|\bRMB\b|¥"#)]
        let found = matches.filter { normalized.range(of: $0.1, options: .regularExpression) != nil }.map(\.0)
        return found.count == 1 ? found.first : nil
    }

    private static func validName(_ text: String) -> Bool {
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...100).contains(name.count), name.rangeOfCharacter(from: .letters) != nil || name.range(of: #"^[0-9]{1,6}$"#, options: .regularExpression) != nil else { return false }
        let blocked = #"^(?:total|grand total|sub\s?total|total holdings|total shares|total units|portfolio total|holdings|quantity|shares|units|security|description|account|account number|opening balance|closing balance|balance|statement|page|you own|you hold|number of|no\. of)(?:\s*[:0-9].*)?$"#
        return name.range(of: blocked, options: [.regularExpression, .caseInsensitive]) == nil
    }

    private static func inferredSymbol(_ name: String) -> String {
        if let match = firstMatch(#"\(([A-Z0-9][A-Z0-9.\-]{0,11})\)"#, in: name), let range = Range(match.range(at: 1), in: name) {
            return String(name[range]).uppercased()
        }
        // A company name is an editable identifier when no ticker was printed.
        return name.uppercased()
    }

    private static func firstMatch(_ pattern: String, in text: String) -> NSTextCheckingResult? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        return expression.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text))
    }

    private static func validAmounts(_ holding: Holding) -> Bool {
        [holding.quantity, holding.price, holding.averageCost].allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1_000_000_000 }
            && holding.quantity > 0 && holding.value < 1e14 && holding.cost < 1e14
    }

    private static func validated(_ holdings: [Holding]) throws -> [Holding] {
        guard !holdings.isEmpty else {
            throw ExtractionError.invalid("No recognizable holdings were found. Use a clear statement with security names and quantities, or import the CSV template. You can also add holdings manually.")
        }
        guard holdings.count <= maximumRows, holdings.allSatisfy(validAmounts) else {
            throw ExtractionError.invalid("Check the statement quantities and amounts. Import up to 1,000 holdings with values below 100 trillion.")
        }
        return holdings
    }
}
