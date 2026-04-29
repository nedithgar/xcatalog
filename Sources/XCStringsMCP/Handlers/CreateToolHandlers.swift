import Foundation
import MCP
import XCStringsKit

// MARK: - Create File Handler

struct CreateFileHandler: ToolHandler {
    static let toolName = "xcatalog_create_file"

    func execute(with context: ToolContext) async throws -> String {
        let file = try context.arguments.requireString("file")
        let sourceLanguage = context.arguments.optionalString("sourceLanguage") ?? "en"
        let overwrite = context.arguments.bool("overwrite", default: false)

        let overwrote = try await XCStringsParser.createFile(at: file, sourceLanguage: sourceLanguage, overwrite: overwrite)
        let response = MCPCreateFileResponse(
            success: true,
            file: file,
            sourceLanguage: sourceLanguage,
            overwrote: overwrote
        )
        return try JSONEncoderHelper.encode(response)
    }
}

struct MCPCreateFileResponse: Codable, Equatable, Sendable {
    let success: Bool
    let file: String
    let sourceLanguage: String
    let overwrote: Bool
}
