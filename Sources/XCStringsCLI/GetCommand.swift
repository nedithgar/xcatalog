import ArgumentParser
import Foundation
import XCStringsKit

struct GetCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Get information about keys or translations",
        subcommands: [Key.self, SourceLanguage.self]
    )
}

extension GetCommand {
    struct Key: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "key",
            abstract: "Get details for a specific key"
        )

        @Argument(help: "The key to get details for")
        var key: String

        @Option(name: .shortAndLong, help: "Path to the xcstrings file")
        var file: String

        @Option(name: .shortAndLong, help: "Specific language to get (optional)")
        var lang: String?

        @Flag(name: .long, help: "Output in pretty-printed JSON format")
        var pretty = false

        func run() async throws {
            let parser = XCStringsParser(path: file)
            let keyInfo = try await parser.getKey(key, language: lang)
            try CLIOutput.printJSON(keyInfo, pretty: pretty)
        }
    }

    struct SourceLanguage: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "source-language",
            abstract: "Get the source language of the xcstrings file"
        )

        @Option(name: .shortAndLong, help: "Path to the xcstrings file")
        var file: String

        func run() async throws {
            let parser = XCStringsParser(path: file)
            let sourceLanguage = try await parser.getSourceLanguage()
            print(sourceLanguage)
        }
    }
}
