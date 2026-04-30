import Foundation
import MCP
import XCStringsKit

// MARK: - Delete Key Handler

struct DeleteKeyHandler: ToolHandler {
    static let toolName = "xcatalog_delete_key"

    func execute(with context: ToolContext) async throws -> String {
        let file = try context.arguments.requireString("file")
        let key = try context.arguments.requireString("key")

        let parser = XCStringsParser(path: file)
        try await parser.deleteKey(key)
        let response = MCPWriteResponse(
            file: file,
            operationType: .deleteKey,
            key: key,
            fileChanged: true,
            entries: [
                MCPWriteEntryResult(
                    key: key,
                    action: .deleted
                )
            ]
        )
        return try JSONEncoderHelper.encode(response)
    }
}

// MARK: - Delete Translation Handler

struct DeleteTranslationHandler: ToolHandler {
    static let toolName = "xcatalog_delete_translation"

    func execute(with context: ToolContext) async throws -> String {
        let file = try context.arguments.requireString("file")
        let key = try context.arguments.requireString("key")
        let language = try context.arguments.requireString("language")

        let parser = XCStringsParser(path: file)
        let result = try await parser.deleteTranslation(key: key, language: language)
        let response = MCPWriteResponse(
            file: file,
            operationType: .deleteTranslation,
            key: key,
            languages: [language],
            fileChanged: true,
            entries: MCPWriteResponseBuilder.deletedEntries(
                key: key,
                snapshots: result.deletedTranslations
            )
        )
        return try JSONEncoderHelper.encode(response)
    }
}

// MARK: - Delete Translations Handler

struct DeleteTranslationsHandler: ToolHandler {
    static let toolName = "xcatalog_delete_translations"

    func execute(with context: ToolContext) async throws -> String {
        let file = try context.arguments.requireString("file")
        let key = try context.arguments.requireString("key")
        let languages = try context.arguments.requireStringArray("languages")

        let parser = XCStringsParser(path: file)
        let result = try await parser.deleteTranslations(key: key, languages: languages)
        let response = MCPWriteResponse(
            file: file,
            operationType: .deleteTranslations,
            key: key,
            languages: result.languages,
            fileChanged: true,
            entries: MCPWriteResponseBuilder.deletedEntries(
                key: key,
                snapshots: result.deletedTranslations
            )
        )
        return try JSONEncoderHelper.encode(response)
    }
}
