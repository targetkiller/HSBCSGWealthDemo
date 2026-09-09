import Foundation

enum StatementParser {
    enum ParseError: LocalizedError {
        case invalid(String)
        var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
    }
    static let template = "name,symbol,category,currency,quantity,price,averageCost\nApple,AAPL,Stocks,USD,50,226.8,205\nSingapore dollar balance,SGD,Cash and FX,SGD,10000,1,1\n"
    static func parse(_ text: String) throws -> [Holding] {
        let lines = text.replacingOccurrences(of: "\u{FEFF}", with: "").components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count >= 2, lines[0].trimmingCharacters(in: .whitespaces) == "name,symbol,category,currency,quantity,price,averageCost" else { throw ParseError.invalid("Use the CSV template with the required seven columns.") }
        guard lines.count <= 1001 else { throw ParseError.invalid("Import up to 1,000 holdings at a time.") }
        return try lines.dropFirst().enumerated().map { index, line in
            let cells = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard cells.count == 7, !cells[0].isEmpty, !cells[1].isEmpty, let category = AssetClass(rawValue: cells[2]), let currency = Currency(rawValue: cells[3]), let q = Double(cells[4]), let p = Double(cells[5]), let c = Double(cells[6]), q.isFinite, p.isFinite, c.isFinite, q > 0, p >= 0, c >= 0, (q * max(p, c)).isFinite, q * max(p, c) < 1e14 else { throw ParseError.invalid("Invalid data on row \(index + 2). Check the category, currency and numeric values. Quoted commas are not supported.") }
            return Holding(name: cells[0], symbol: cells[1], category: category, currency: currency, quantity: q, price: p, averageCost: c)
        }
    }
}
