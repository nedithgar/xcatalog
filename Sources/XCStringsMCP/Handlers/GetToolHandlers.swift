import Foundation
import MCP
import XCStringsKit

// MARK: - Get Source Language Handler

struct GetSourceLanguageHandler: ToolHandler {
    static let toolName = "xcatalog_get_source_language"

    func execute(with context: ToolContext) async throws -> String {
        let file = try context.arguments.requireString("file")
        let parser = XCStringsParser(path: file)
        let sourceLanguage = try await parser.getSourceLanguage()
        return try JSONEncoderHelper.encode(sourceLanguage)
    }
}

// MARK: - Get Key Handler

struct GetKeyHandler: ToolHandler {
    static let toolName = "xcatalog_get_key"

    func execute(with context: ToolContext) async throws -> String {
        let file = try context.arguments.requireString("file")
        let key = try context.arguments.requireString("key")
        let language = context.arguments.optionalString("language")

        let parser = XCStringsParser(path: file)
        let keyInfo = try await parser.getKey(key, language: language)
        return try JSONEncoderHelper.encode(keyInfo)
    }
}

// MARK: - Check Key Handler

struct CheckKeyHandler: ToolHandler {
    static let toolName = "xcatalog_check_key"

    func execute(with context: ToolContext) async throws -> String {
        let file = try context.arguments.requireString("file")
        let key = try context.arguments.requireString("key")
        let language = context.arguments.optionalString("language")

        let parser = XCStringsParser(path: file)
        let exists = try await parser.checkKey(key, language: language)
        return try JSONEncoderHelper.encode(exists)
    }
}

// MARK: - Check Coverage Handler

struct CheckCoverageHandler: ToolHandler {
    static let toolName = "xcatalog_check_coverage"

    func execute(with context: ToolContext) async throws -> String {
        let file = try context.arguments.requireString("file")
        let key = try context.arguments.requireString("key")

        let parser = XCStringsParser(path: file)
        let coverage = try await parser.checkCoverage(key)
        return try JSONEncoderHelper.encode(coverage)
    }
}
