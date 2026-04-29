import ArgumentParser
import Foundation
import XCStringsKit

struct ValidateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Validate catalog structure, placeholders, and suspicious keys",
        subcommands: [Catalog.self, Placeholders.self, SuspiciousKeys.self]
    )
}

extension ValidateCommand {
    struct Catalog: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "catalog",
            abstract: "Validate JSON parseability, model shape, placeholders, rich records, suspicious keys, and optional xcstringstool compilation"
        )

        @Option(name: .shortAndLong, help: "Path to the xcstrings file")
        var file: String

        @Flag(name: .long, help: "Run xcstringstool compile --dry-run as part of validation")
        var validateCompile = false

        @Option(name: [.customShort("l"), .customLong("language")], help: "Language to pass to xcstringstool. Repeat for multiple languages. If omitted, all catalog languages compile.")
        var languages: [String] = []

        @Flag(name: .long, help: "Output in pretty-printed JSON format")
        var pretty = false

        @Flag(name: .long, help: "Output a compact validation summary instead of full nested reports")
        var compact = false

        func run() async throws {
            let parser = XCStringsParser(path: file)
            let report = await parser.validateCatalog(
                validateCompile: validateCompile,
                compileLanguages: languages
            )
            if compact {
                try CLIOutput.printJSON(report.compact(), pretty: pretty)
            } else {
                try CLIOutput.printJSON(report, pretty: pretty)
            }
        }
    }

    struct Placeholders: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "placeholders",
            abstract: "Validate placeholder consistency across all translated locales"
        )

        @Option(name: .shortAndLong, help: "Path to the xcstrings file")
        var file: String

        @Flag(name: .long, help: "Output in pretty-printed JSON format")
        var pretty = false

        func run() async throws {
            let parser = XCStringsParser(path: file)
            let report = try await parser.validatePlaceholders()
            try CLIOutput.printJSON(report, pretty: pretty)
        }
    }

    struct SuspiciousKeys: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "suspicious-keys",
            abstract: "Find empty, punctuation-only, or format-only keys that are likely accidental catalog entries"
        )

        @Option(name: .shortAndLong, help: "Path to the xcstrings file")
        var file: String

        @Flag(name: .long, help: "Output in pretty-printed JSON format")
        var pretty = false

        func run() async throws {
            let parser = XCStringsParser(path: file)
            let report = try await parser.findSuspiciousKeys()
            try CLIOutput.printJSON(report, pretty: pretty)
        }
    }
}
