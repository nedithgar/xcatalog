import ArgumentParser
import Foundation
import XCStringsKit

struct BatchCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "batch",
        abstract: "Batch operations for multiple keys",
        subcommands: [Check.self, Add.self, Update.self, Supplement.self, Stale.self]
    )
}

extension BatchCommand {
    struct Check: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "check",
            abstract: "Check if multiple keys exist"
        )

        @Option(name: .shortAndLong, parsing: .upToNextOption, help: "Keys to check")
        var keys: [String]

        @Option(name: .shortAndLong, help: "Path to the xcstrings file")
        var file: String

        @Option(name: .shortAndLong, help: "Specific language to check (optional)")
        var lang: String?

        @Flag(name: .long, help: "Output in pretty-printed JSON format")
        var pretty = false

        func validate() throws {
            if keys.isEmpty {
                throw ValidationError("At least one key must be specified")
            }
        }

        func run() async throws {
            let parser = XCStringsParser(path: file)
            let result = try await parser.checkKeys(keys, language: lang)
            try CLIOutput.printJSON(result, pretty: pretty)
        }
    }

    struct Add: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "add",
            abstract: "Add translations for multiple keys at once"
        )

        @Option(name: .shortAndLong, help: "Path to the xcstrings file")
        var file: String

        @Option(name: .shortAndLong, parsing: .upToNextOption, help: "Entries in key=lang:value,lang:value format (e.g., -e Hello=ja:こんにちは,en:Hello -e Goodbye=ja:さようなら)")
        var entries: [String]

        @Flag(name: .long, help: "Allow overwriting existing translations")
        var overwrite = false

        @Flag(name: .long, help: "Output in pretty-printed JSON format")
        var pretty = false

        func validate() throws {
            if entries.isEmpty {
                throw ValidationError("At least one entry must be specified")
            }
        }

        func run() async throws {
            let parser = XCStringsParser(path: file)
            let batchEntries = try entries.map { try BatchEntryParser.parse($0) }
            let result = try await parser.addTranslationsBatch(entries: batchEntries, allowOverwrite: overwrite)
            try CLIOutput.printJSON(result, pretty: pretty)
        }
    }

    struct Update: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "update",
            abstract: "Update translations for multiple keys at once"
        )

        @Option(name: .shortAndLong, help: "Path to the xcstrings file")
        var file: String

        @Option(name: .shortAndLong, parsing: .upToNextOption, help: "Entries in key=lang:value,lang:value format (e.g., -e Hello=ja:こんにちは,en:Hello -e Goodbye=ja:さようなら)")
        var entries: [String]

        @Flag(name: .long, help: "Output in pretty-printed JSON format")
        var pretty = false

        @Flag(name: .long, help: "Output a compact supplement summary instead of the full plan")
        var compact = false

        func validate() throws {
            if entries.isEmpty {
                throw ValidationError("At least one entry must be specified")
            }
        }

        func run() async throws {
            let parser = XCStringsParser(path: file)
            let batchEntries = try entries.map { try BatchEntryParser.parse($0) }
            let result = try await parser.updateTranslationsBatch(entries: batchEntries)
            try CLIOutput.printJSON(result, pretty: pretty)
        }
    }

    struct Supplement: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "supplement",
            abstract: "Atomically supplement one target locale from a key=value translation map"
        )

        @Option(name: .shortAndLong, help: "Path to the xcstrings file")
        var file: String

        @Option(name: .shortAndLong, help: "Target language code to supplement")
        var lang: String

        @Option(name: .shortAndLong, parsing: .upToNextOption, help: "Entries in key=value format (e.g., -e Hello=こんにちは -e Goodbye=さようなら)")
        var entries: [String]

        @Flag(name: .long, help: "Plan and validate without writing")
        var dryRun = false

        @Flag(name: .long, help: "Allow writing valid entries even when other entries are unsafe or failed")
        var allowPartial = false

        @Flag(name: .long, help: "Update existing target localizations when their values differ")
        var overwrite = false

        @Flag(name: .long, help: "Compile a projected temporary catalog with xcstringstool before saving, or during dry-run without saving")
        var validateCompile = false

        @Flag(name: .long, help: "Output in pretty-printed JSON format")
        var pretty = false

        @Flag(name: .long, help: "Output a compact supplement summary instead of the full plan")
        var compact = false

        func validate() throws {
            if entries.isEmpty {
                throw ValidationError("At least one entry must be specified")
            }
        }

        func run() async throws {
            let parser = XCStringsParser(path: file)
            let supplementEntries = try entries.map { try LocaleSupplementEntryParser.parse($0) }
            let translations = supplementEntries.reduce(into: [String: String]()) { result, entry in
                result[entry.key] = entry.value
            }
            let result = try await parser.supplementLocale(
                language: lang,
                translations: translations,
                dryRun: dryRun,
                allowPartial: allowPartial,
                overwrite: overwrite,
                validateCompile: validateCompile
            )
            if compact {
                let remainingKeys = try? await parser.listUntranslated(for: lang)
                let projectedRemainingKeys = remainingKeys.map {
                    result.projectedRemainingUntranslatedKeys(currentUntranslatedKeys: $0)
                }
                try CLIOutput.printJSON(result.compact(remainingUntranslatedKeys: projectedRemainingKeys), pretty: pretty)
            } else {
                try CLIOutput.printJSON(result, pretty: pretty)
            }
        }
    }

    struct Stale: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "stale",
            abstract: "List stale keys across multiple xcstrings files"
        )

        @Option(name: .shortAndLong, parsing: .upToNextOption, help: "Paths to xcstrings files")
        var files: [String]

        @Flag(name: .long, help: "Output in pretty-printed JSON format")
        var pretty = false

        func validate() throws {
            if files.isEmpty {
                throw ValidationError("At least one file must be specified")
            }
        }

        func run() async throws {
            let result = try XCStringsParser.getBatchStaleKeys(paths: files)
            try CLIOutput.printJSON(result, pretty: pretty)
        }
    }
}
