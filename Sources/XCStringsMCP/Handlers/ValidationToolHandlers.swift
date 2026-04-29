import Foundation
import MCP
import XCStringsKit

// MARK: - Validate Catalog Handler

struct ValidateCatalogHandler: ToolHandler {
    static let toolName = "xcatalog_validate_catalog"

    func execute(with context: ToolContext) async throws -> String {
        let file = try context.arguments.requireString("file")
        let validateCompile = context.arguments.bool("validateCompile", default: false)
        let languages = context.arguments.optionalStringArray("languages") ?? []
        let compact = context.arguments.bool("compact", default: false)
        let parser = XCStringsParser(path: file)
        let report = await parser.validateCatalog(
            validateCompile: validateCompile,
            compileLanguages: languages
        )
        if compact {
            return try JSONEncoderHelper.encode(report.compact())
        }
        return try JSONEncoderHelper.encode(report)
    }
}

// MARK: - Validate Placeholders Handler

struct ValidatePlaceholdersHandler: ToolHandler {
    static let toolName = "xcatalog_validate_placeholders"

    func execute(with context: ToolContext) async throws -> String {
        let file = try context.arguments.requireString("file")
        let parser = XCStringsParser(path: file)
        let report = try await parser.validatePlaceholders()
        return try JSONEncoderHelper.encode(report)
    }
}

// MARK: - Find Suspicious Keys Handler

struct FindSuspiciousKeysHandler: ToolHandler {
    static let toolName = "xcatalog_find_suspicious_keys"

    func execute(with context: ToolContext) async throws -> String {
        let file = try context.arguments.requireString("file")
        let parser = XCStringsParser(path: file)
        let report = try await parser.findSuspiciousKeys()
        return try JSONEncoderHelper.encode(report)
    }
}
