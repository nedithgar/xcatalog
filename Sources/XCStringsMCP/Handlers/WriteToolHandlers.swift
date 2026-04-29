import Foundation
import MCP
import XCStringsKit

// MARK: - Add Translation Handler

struct AddTranslationHandler: ToolHandler {
    static let toolName = "xcatalog_add_translation"

    func execute(with context: ToolContext) async throws -> String {
        let file = try context.arguments.requireString("file")
        let key = try context.arguments.requireString("key")
        let language = try context.arguments.requireString("language")
        let value = try context.arguments.requireString("value")

        let parser = XCStringsParser(path: file)
        let result = try await parser.addTranslation(key: key, language: language, value: value)
        let response = MCPWriteResponse(
            file: file,
            operationType: .addTranslation,
            key: key,
            languages: [language],
            fileChanged: true,
            entries: MCPWriteResponseBuilder.entries(key: key, languageResults: result.languageResults),
            placeholderValidations: result.placeholderValidations.filter(\.checked),
            validationWarnings: MCPWriteResponseBuilder.validationWarnings(from: result.placeholderValidations)
        )
        return try JSONEncoderHelper.encode(response)
    }
}

// MARK: - Add Translations Handler

struct AddTranslationsHandler: ToolHandler {
    static let toolName = "xcatalog_add_translations"

    func execute(with context: ToolContext) async throws -> String {
        let file = try context.arguments.requireString("file")
        let key = try context.arguments.requireString("key")
        let translations = try context.arguments.requireTranslations("translations")

        let parser = XCStringsParser(path: file)
        let result = try await parser.addTranslations(key: key, translations: translations)
        let response = MCPWriteResponse(
            file: file,
            operationType: .addTranslations,
            key: key,
            languages: translations.keys.sorted(),
            fileChanged: true,
            entries: MCPWriteResponseBuilder.entries(key: key, languageResults: result.languageResults),
            placeholderValidations: result.placeholderValidations.filter(\.checked),
            validationWarnings: MCPWriteResponseBuilder.validationWarnings(from: result.placeholderValidations)
        )
        return try JSONEncoderHelper.encode(response)
    }
}

// MARK: - Update Translation Handler

struct UpdateTranslationHandler: ToolHandler {
    static let toolName = "xcatalog_update_translation"

    func execute(with context: ToolContext) async throws -> String {
        let file = try context.arguments.requireString("file")
        let key = try context.arguments.requireString("key")
        let language = try context.arguments.requireString("language")
        let value = try context.arguments.requireString("value")

        let parser = XCStringsParser(path: file)
        let result = try await parser.updateTranslation(key: key, language: language, value: value)
        let response = MCPWriteResponse(
            file: file,
            operationType: .updateTranslation,
            key: key,
            languages: [language],
            fileChanged: true,
            entries: MCPWriteResponseBuilder.entries(key: key, languageResults: result.languageResults),
            placeholderValidations: result.placeholderValidations.filter(\.checked),
            validationWarnings: MCPWriteResponseBuilder.validationWarnings(from: result.placeholderValidations)
        )
        return try JSONEncoderHelper.encode(response)
    }
}

// MARK: - Update Translations Handler

struct UpdateTranslationsHandler: ToolHandler {
    static let toolName = "xcatalog_update_translations"

    func execute(with context: ToolContext) async throws -> String {
        let file = try context.arguments.requireString("file")
        let key = try context.arguments.requireString("key")
        let translations = try context.arguments.requireTranslations("translations")

        let parser = XCStringsParser(path: file)
        let result = try await parser.updateTranslations(key: key, translations: translations)
        let response = MCPWriteResponse(
            file: file,
            operationType: .updateTranslations,
            key: key,
            languages: translations.keys.sorted(),
            fileChanged: true,
            entries: MCPWriteResponseBuilder.entries(key: key, languageResults: result.languageResults),
            placeholderValidations: result.placeholderValidations.filter(\.checked),
            validationWarnings: MCPWriteResponseBuilder.validationWarnings(from: result.placeholderValidations)
        )
        return try JSONEncoderHelper.encode(response)
    }
}

// MARK: - Rename Key Handler

struct RenameKeyHandler: ToolHandler {
    static let toolName = "xcatalog_rename_key"

    func execute(with context: ToolContext) async throws -> String {
        let file = try context.arguments.requireString("file")
        let oldKey = try context.arguments.requireString("oldKey")
        let newKey = try context.arguments.requireString("newKey")

        let parser = XCStringsParser(path: file)
        try await parser.renameKey(from: oldKey, to: newKey)
        let response = MCPWriteResponse(
            file: file,
            operationType: .renameKey,
            key: oldKey,
            fileChanged: true,
            entries: [
                MCPWriteEntryResult(
                    key: oldKey,
                    action: .renamed,
                    previousKey: oldKey,
                    finalKey: newKey
                )
            ]
        )
        return try JSONEncoderHelper.encode(response)
    }
}
