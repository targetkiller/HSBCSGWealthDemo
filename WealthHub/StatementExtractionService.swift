import Foundation
import PDFKit
import UIKit
import Vision
import ImageIO

/// Reads local statements only. Imported rows always need confirmation before saving.
enum StatementExtractionService {
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

    static func extract(url: URL) async throws -> [Holding] {
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
                return try validated(StatementParser.parse(text))
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
            return try recognizedHoldings(in: recognize(cgImage, orientation: .up))
        }.value
    }

    static func extract(image: UIImage) async throws -> [Holding] {
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
            return try recognizedHoldings(in: recognize(cgImage, orientation: orientation))
        }.value
    }

    private static func extractPDF(_ data: Data) throws -> [Holding] {
        guard let document = PDFDocument(data: data), !document.isLocked else {
            throw ExtractionError.invalid("This PDF could not be opened. Export an unlocked statement and try again.")
        }
        guard document.pageCount > 0, document.pageCount <= maximumPages else {
            throw ExtractionError.invalid("Import a statement of up to 5 pages. Export just the holdings pages from a longer statement.")
        }
        var holdings: [Holding] = []
        for index in 0..<document.pageCount {
            try Task.checkCancellation()
            guard let page = document.page(at: index) else { continue }
            let textRows = try parseText(page.string ?? "")
            if !textRows.isEmpty {
                holdings.append(contentsOf: textRows)
                continue
            }
            let bounds = page.bounds(for: .mediaBox)
            guard bounds.width > 0, bounds.height > 0 else { continue }
            let scale = min(3, 2_400 / max(bounds.width, bounds.height))
            let thumbnail = page.thumbnail(of: CGSize(width: bounds.width * scale, height: bounds.height * scale), for: .mediaBox)
            if let cgImage = thumbnail.cgImage {
                holdings.append(contentsOf: try parseText(recognize(cgImage, orientation: .up)))
            }
        }
        return try validated(holdings)
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
        return lines.map { line in
            line.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\t")
        }.joined(separator: "\n")
    }

    private static func recognizedHoldings(in text: String) throws -> [Holding] {
        try validated(parseText(text))
    }

    /// Parses explicit "NAME 100 shares" rows or tables with named quantity columns.
    /// Unlabeled numbers are never guessed to be prices; unknown prices/costs remain zero.
    static func parseText(_ text: String) throws -> [Holding] {
        guard text.utf8.count <= 500_000 else {
            throw ExtractionError.invalid("This statement has too much text. Export only the holdings pages.")
        }
        let lines = text.components(separatedBy: .newlines)
        let defaultCurrency = currency(in: text) ?? .HKD
        var header: [String]?
        var result: [Holding] = []
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
            }
            guard result.count <= maximumRows else {
                throw ExtractionError.invalid("Import up to 1,000 holdings at a time.")
            }
        }
        return result
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
