import Foundation

enum StatementParser {
    enum ParseError: LocalizedError {
        case invalid(String)
        var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
    }
    static var template: String { SampleData.statementCSV }
    static func parse(_ text: String) throws -> [Holding] {
        let rows = try SampleCSV.parse(text, source: "Statement")
        let columns = ["name", "symbol", "category", "currency", "quantity", "price", "averageCost"]
        guard !rows.isEmpty, rows.allSatisfy({ Set($0.values.keys) == Set(columns) }) else { throw ParseError.invalid("Use the CSV template with the required seven columns.") }
        guard rows.count <= 1000 else { throw ParseError.invalid("Import up to 1,000 holdings at a time.") }
        return try rows.map { row in
            let cells = columns.map { row.string($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            guard !cells[0].isEmpty, !cells[1].isEmpty, let category = AssetClass(rawValue: cells[2]), let currency = Currency(rawValue: cells[3]), let q = Double(cells[4]), let p = Double(cells[5]), let c = Double(cells[6]), q.isFinite, p.isFinite, c.isFinite, q > 0, p >= 0, c >= 0, (q * max(p, c)).isFinite, q * max(p, c) < 1e14 else { throw ParseError.invalid("Invalid data on row \(row.lineNumber). Check the category, currency and numeric values.") }
            return Holding(name: cells[0], symbol: cells[1], category: category, currency: currency, quantity: q, price: p, averageCost: c)
        }
    }
}
