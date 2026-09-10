import Foundation

@main
enum SampleDataTool {
    static func main() {
        do {
            try run(Array(CommandLine.arguments.dropFirst()))
        } catch {
            let message = "Sample data error: \(error.localizedDescription)\n"
            FileHandle.standardError.write(Data(message.utf8))
            exit(1)
        }
    }

    private static func run(_ arguments: [String]) throws {
        guard arguments.count >= 2 else { throw UsageError() }
        let command = arguments[0]
        guard (command == "validate" && arguments.count == 2)
                || (command == "export-statement" && arguments.count == 3) else {
            throw UsageError()
        }

        let directory = URL(fileURLWithPath: arguments[1], isDirectory: true)
        let catalog = try SampleCatalog.load(directory: directory)
        switch command {
        case "validate":
            let accounts = catalog.accounts
            let holdingCount = accounts.reduce(0) { $0 + $1.holdings.count }
            print("Valid Sample configuration: \(accounts.count) accounts, \(holdingCount) account holdings, \(catalog.rows("holdings").count) configured holdings.")
        case "export-statement":
            let output = URL(fileURLWithPath: arguments[2]).standardizedFileURL
            try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
            try catalog.statementCSV(in: "csv-file-export").write(to: output, atomically: true, encoding: .utf8)
            print("\(output.path) — importable statement generated from Sample/holdings.csv (csv-file-export set).")
        default:
            throw UsageError()
        }
    }

    private struct UsageError: LocalizedError {
        var errorDescription: String? {
            "Use ./scripts/sample-data.sh validate or ./scripts/sample-data.sh export-statement [outputPath]."
        }
    }
}
