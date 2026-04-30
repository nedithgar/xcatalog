import Foundation
import MCP
import XCStringsKit

public struct XCStringsMCPServer {
    public init() {}

    public func run() async throws {
        let server = Server(
            name: XCStringsMCPMetadata.serverName,
            version: XCStringsMCPMetadata.version,
            capabilities: .init(
                tools: .init(listChanged: false)
            )
        )

        // Register tool list handler
        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: Self.allTools)
        }

        // Register tool call handler
        await server.withMethodHandler(CallTool.self) { params in
            await Self.handleToolCall(params)
        }

        let stdioTransport = StdioTransport()
        let transport = SerialOutboundTransport(
            base: stdioTransport,
            inboundMessages: await stdioTransport.receive(),
            logger: stdioTransport.logger
        )
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }

    // MARK: - Tool Definitions

    private static var allTools: [Tool] {
        [
            Tool(
                name: "xcatalog_health",
                description: "Report the running xcatalog version and schema metadata. Local filesystem paths are omitted unless explicitly enabled.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "includeSensitivePaths": .object([
                            "type": .string("boolean"),
                            "description": .string("Include binaryPath, currentWorkingDirectory, and allowedRoots only when XCATALOG_HEALTH_INCLUDE_SENSITIVE is enabled. Defaults to false."),
                        ]),
                    ]),
                ])
            ),
            // Read operations
            Tool(
                name: "xcatalog_list_keys",
                description: "List all keys in the xcstrings file",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "file": .object(["type": .string("string"), "description": .string("Path to the xcstrings file")]),
                    ]),
                    "required": .array([.string("file")]),
                ])
            ),
            Tool(
                name: "xcatalog_list_languages",
                description: "List all languages in the xcstrings file",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "file": .object(["type": .string("string"), "description": .string("Path to the xcstrings file")]),
                    ]),
                    "required": .array([.string("file")]),
                ])
            ),
            Tool(
                name: "xcatalog_list_untranslated",
                description: "List untranslated keys for a specific language",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "file": .object(["type": .string("string"), "description": .string("Path to the xcstrings file")]),
                        "language": .object(["type": .string("string"), "description": .string("Language code to check")]),
                    ]),
                    "required": .array([.string("file"), .string("language")]),
                ])
            ),
            Tool(
                name: "xcatalog_list_stale",
                description: "List keys with stale extraction state (potentially unused keys) in a single file. Note: This only detects keys marked as 'stale' by Xcode. To verify if these keys are truly unused, you should search for their usage in the module or project's source code.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "file": .object(["type": .string("string"), "description": .string("Path to the xcstrings file")]),
                    ]),
                    "required": .array([.string("file")]),
                ])
            ),
            Tool(
                name: "xcatalog_preflight_locale",
                description: "Classify target-locale work before writing translations. Reports missing simple stringUnit keys, format-string keys, rich variation/substitution keys, stale keys, non-translatable keys, already translated keys, unsafe keys, source metadata, and placeholder metadata.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "file": .object(["type": .string("string"), "description": .string("Path to the xcstrings file")]),
                        "language": .object(["type": .string("string"), "description": .string("Target language code to classify")]),
                        "compact": .object(["type": .string("boolean"), "description": .string("If true, return summary counts and key lists instead of full per-key metadata (default: false)")]),
                    ]),
                    "required": .array([.string("file"), .string("language")]),
                ])
            ),
            Tool(
                name: "xcatalog_validate_catalog",
                description: "Validate JSON parseability, model decoding, placeholder consistency, rich substitution/variation preservation, suspicious keys, and optional xcstringstool compile --dry-run.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "file": .object(["type": .string("string"), "description": .string("Path to the xcstrings file")]),
                        "validateCompile": .object(["type": .string("boolean"), "description": .string("If true, run xcstringstool compile --dry-run (default: false)")]),
                        "languages": .object([
                            "type": .string("array"),
                            "items": .object(["type": .string("string")]),
                            "description": .string("Optional languages to pass to xcstringstool. If omitted, all catalog languages compile."),
                        ]),
                        "compact": .object(["type": .string("boolean"), "description": .string("If true, return summary counts and a short issue list instead of full nested validation reports (default: false)")]),
                    ]),
                    "required": .array([.string("file")]),
                ])
            ),
            Tool(
                name: "xcatalog_validate_placeholders",
                description: "Validate placeholder consistency for every translated locale in a catalog, including printf placeholders, substitution placeholders, and variation values.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "file": .object(["type": .string("string"), "description": .string("Path to the xcstrings file")]),
                    ]),
                    "required": .array([.string("file")]),
                ])
            ),
            Tool(
                name: "xcatalog_find_suspicious_keys",
                description: "Find empty, punctuation-only, or format-only keys that are likely accidental SwiftUI catalog entries such as \"\", \"/\", or \"(%@)\".",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "file": .object(["type": .string("string"), "description": .string("Path to the xcstrings file")]),
                    ]),
                    "required": .array([.string("file")]),
                ])
            ),
            Tool(
                name: "xcatalog_batch_list_stale",
                description: "List keys with stale extraction state across multiple xcstrings files at once. Returns stale keys per file and total count.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "files": .object([
                            "type": .string("array"),
                            "items": .object(["type": .string("string")]),
                            "description": .string("Array of paths to xcstrings files"),
                        ]),
                    ]),
                    "required": .array([.string("files")]),
                ])
            ),
            Tool(
                name: "xcatalog_get_source_language",
                description: "Get the source language of the xcstrings file",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "file": .object(["type": .string("string"), "description": .string("Path to the xcstrings file")]),
                    ]),
                    "required": .array([.string("file")]),
                ])
            ),
            Tool(
                name: "xcatalog_get_key",
                description: "Get metadata and translations for a specific key",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "file": .object(["type": .string("string"), "description": .string("Path to the xcstrings file")]),
                        "key": .object(["type": .string("string"), "description": .string("The key to get details for")]),
                        "language": .object(["type": .string("string"), "description": .string("Optional specific language to get")]),
                    ]),
                    "required": .array([.string("file"), .string("key")]),
                ])
            ),
            Tool(
                name: "xcatalog_check_key",
                description: "Check if a key exists in the xcstrings file",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "file": .object(["type": .string("string"), "description": .string("Path to the xcstrings file")]),
                        "key": .object(["type": .string("string"), "description": .string("The key to check")]),
                        "language": .object(["type": .string("string"), "description": .string("Optional specific language to check")]),
                    ]),
                    "required": .array([.string("file"), .string("key")]),
                ])
            ),
            Tool(
                name: "xcatalog_check_coverage",
                description: "Get translation coverage for a specific key",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "file": .object(["type": .string("string"), "description": .string("Path to the xcstrings file")]),
                        "key": .object(["type": .string("string"), "description": .string("The key to check coverage for")]),
                    ]),
                    "required": .array([.string("file"), .string("key")]),
                ])
            ),
            Tool(
                name: "xcatalog_stats_coverage",
                description: "Get overall translation statistics. Compact mode keeps incomplete languages and reports not-applicable coverage explicitly.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "file": .object(["type": .string("string"), "description": .string("Path to the xcstrings file")]),
                        "compact": .object(["type": .string("boolean"), "description": .string("If true, keep incomplete languages and report not-applicable coverage explicitly (default: true)")]),
                    ]),
                    "required": .array([.string("file")]),
                ])
            ),
            Tool(
                name: "xcatalog_stats_progress",
                description: "Get translation progress for a specific language",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "file": .object(["type": .string("string"), "description": .string("Path to the xcstrings file")]),
                        "language": .object(["type": .string("string"), "description": .string("Language code to check progress for")]),
                    ]),
                    "required": .array([.string("file"), .string("language")]),
                ])
            ),
            Tool(
                name: "xcatalog_batch_stats_coverage",
                description: "Get token-efficient coverage statistics for multiple xcstrings files at once. Returns compact summaries per language for each file and aggregated totals, including explicit not-applicable coverage states.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "files": .object(["type": .string("array"), "items": .object(["type": .string("string")]), "description": .string("Array of paths to xcstrings files")]),
                        "compact": .object(["type": .string("boolean"), "description": .string("If true, keep incomplete languages and report not-applicable coverage explicitly (default: true)")]),
                    ]),
                    "required": .array([.string("files")]),
                ])
            ),
            Tool(
                name: "xcatalog_batch_check_keys",
                description: "Check if multiple keys exist in the xcstrings file. Returns results for each key.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "file": .object(["type": .string("string"), "description": .string("Path to the xcstrings file")]),
                        "keys": .object(["type": .string("array"), "items": .object(["type": .string("string")]), "description": .string("Array of keys to check")]),
                        "language": .object(["type": .string("string"), "description": .string("Optional specific language to check")]),
                    ]),
                    "required": .array([.string("file"), .string("keys")]),
                ])
            ),
            Tool(
                name: "xcatalog_batch_add_translations",
                description: "Add translations for multiple keys at once. Each entry contains a key and its translations for multiple languages.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "file": .object(["type": .string("string"), "description": .string("Path to the xcstrings file")]),
                        "entries": .object([
                            "type": .string("array"),
                            "items": .object([
                                "type": .string("object"),
                                "properties": .object([
                                    "key": .object(["type": .string("string"), "description": .string("The key to add translations for")]),
                                    "translations": .object(["type": .string("object"), "description": .string("Object mapping language codes to translation values")]),
                                ]),
                                "required": .array([.string("key"), .string("translations")]),
                            ]),
                            "description": .string("Array of entries, each with a key and translations object"),
                        ]),
                        "overwrite": .object(["type": .string("boolean"), "description": .string("Allow overwriting existing translations (default: false)")]),
                    ]),
                    "required": .array([.string("file"), .string("entries")]),
                ])
            ),
            Tool(
                name: "xcatalog_batch_update_translations",
                description: "Update translations for multiple keys at once. Each entry contains a key and its translations for multiple languages.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "file": .object(["type": .string("string"), "description": .string("Path to the xcstrings file")]),
                        "entries": .object([
                            "type": .string("array"),
                            "items": .object([
                                "type": .string("object"),
                                "properties": .object([
                                    "key": .object(["type": .string("string"), "description": .string("The key to update translations for")]),
                                    "translations": .object(["type": .string("object"), "description": .string("Object mapping language codes to translation values")]),
                                ]),
                                "required": .array([.string("key"), .string("translations")]),
                            ]),
                            "description": .string("Array of entries, each with a key and translations object"),
                        ]),
                    ]),
                    "required": .array([.string("file"), .string("entries")]),
                ])
            ),
            Tool(
                name: "xcatalog_supplement_locale",
                description: "Atomically supplement one target locale from a key-to-value translation map. Validates the whole plan before writing, supports dryRun, refuses partial writes by default, reports per-key diagnostics and placeholder validation details, and can optionally compile a temporary catalog before saving.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "file": .object(["type": .string("string"), "description": .string("Path to the xcstrings file")]),
                        "language": .object(["type": .string("string"), "description": .string("Target language code to supplement")]),
                        "translations": .object(["type": .string("object"), "description": .string("Object mapping string keys to target-language values")]),
                        "dryRun": .object(["type": .string("boolean"), "description": .string("If true, return the write plan without mutating the catalog; with validateCompile, compile the projected temporary catalog only (default: false)")]),
                        "allowPartial": .object(["type": .string("boolean"), "description": .string("If true, write valid entries even when other entries are unsafe or failed (default: false)")]),
                        "overwrite": .object(["type": .string("boolean"), "description": .string("If true, update existing target localizations when values differ (default: false)")]),
                        "validateCompile": .object(["type": .string("boolean"), "description": .string("If true, run xcstringstool compile --dry-run on a projected temporary catalog before saving or during dry-run (default: false)")]),
                        "compact": .object(["type": .string("boolean"), "description": .string("If true, return summary counts, placeholder/compile status, and remaining untranslated keys instead of the full plan (default: false)")]),
                    ]),
                    "required": .array([.string("file"), .string("language"), .string("translations")]),
                ])
            ),
            // Create operations
            Tool(
                name: "xcatalog_create_file",
                description: "Create a new xcstrings file with the specified source language",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "file": .object(["type": .string("string"), "description": .string("Path for the new xcstrings file")]),
                        "sourceLanguage": .object(["type": .string("string"), "description": .string("Source language code (default: en)")]),
                        "overwrite": .object(["type": .string("boolean"), "description": .string("Overwrite existing file if it exists (default: false)")]),
                    ]),
                    "required": .array([.string("file")]),
                ])
            ),
            // Write operations
            Tool(
                name: "xcatalog_add_translation",
                description: "Add a translation for a key",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "file": .object(["type": .string("string"), "description": .string("Path to the xcstrings file")]),
                        "key": .object(["type": .string("string"), "description": .string("The key to add translation for")]),
                        "language": .object(["type": .string("string"), "description": .string("Language code for the translation")]),
                        "value": .object(["type": .string("string"), "description": .string("Translation value")]),
                    ]),
                    "required": .array([.string("file"), .string("key"), .string("language"), .string("value")]),
                ])
            ),
            Tool(
                name: "xcatalog_add_translations",
                description: "Add translations for multiple languages at once",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "file": .object(["type": .string("string"), "description": .string("Path to the xcstrings file")]),
                        "key": .object(["type": .string("string"), "description": .string("The key to add translations for")]),
                        "translations": .object(["type": .string("object"), "description": .string("Object mapping language codes to translation values, e.g. {\"ja\": \"こんにちは\", \"en\": \"Hello\"}")]),
                    ]),
                    "required": .array([.string("file"), .string("key"), .string("translations")]),
                ])
            ),
            Tool(
                name: "xcatalog_update_translation",
                description: "Update a translation for a key",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "file": .object(["type": .string("string"), "description": .string("Path to the xcstrings file")]),
                        "key": .object(["type": .string("string"), "description": .string("The key to update translation for")]),
                        "language": .object(["type": .string("string"), "description": .string("Language code for the translation")]),
                        "value": .object(["type": .string("string"), "description": .string("New translation value")]),
                    ]),
                    "required": .array([.string("file"), .string("key"), .string("language"), .string("value")]),
                ])
            ),
            Tool(
                name: "xcatalog_update_translations",
                description: "Update translations for multiple languages at once",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "file": .object(["type": .string("string"), "description": .string("Path to the xcstrings file")]),
                        "key": .object(["type": .string("string"), "description": .string("The key to update translations for")]),
                        "translations": .object(["type": .string("object"), "description": .string("Object mapping language codes to translation values, e.g. {\"ja\": \"こんにちは\", \"en\": \"Hello\"}")]),
                    ]),
                    "required": .array([.string("file"), .string("key"), .string("translations")]),
                ])
            ),
            Tool(
                name: "xcatalog_rename_key",
                description: "Rename a key",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "file": .object(["type": .string("string"), "description": .string("Path to the xcstrings file")]),
                        "oldKey": .object(["type": .string("string"), "description": .string("Current key name")]),
                        "newKey": .object(["type": .string("string"), "description": .string("New key name")]),
                    ]),
                    "required": .array([.string("file"), .string("oldKey"), .string("newKey")]),
                ])
            ),
            // Delete operations
            Tool(
                name: "xcatalog_delete_key",
                description: "Delete a key entirely",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "file": .object(["type": .string("string"), "description": .string("Path to the xcstrings file")]),
                        "key": .object(["type": .string("string"), "description": .string("The key to delete")]),
                    ]),
                    "required": .array([.string("file"), .string("key")]),
                ])
            ),
            Tool(
                name: "xcatalog_delete_translation",
                description: "Delete a specific translation for a key",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "file": .object(["type": .string("string"), "description": .string("Path to the xcstrings file")]),
                        "key": .object(["type": .string("string"), "description": .string("The key to delete translation from")]),
                        "language": .object(["type": .string("string"), "description": .string("Language code to delete")]),
                    ]),
                    "required": .array([.string("file"), .string("key"), .string("language")]),
                ])
            ),
            Tool(
                name: "xcatalog_delete_translations",
                description: "Delete translations for multiple languages at once",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "file": .object(["type": .string("string"), "description": .string("Path to the xcstrings file")]),
                        "key": .object(["type": .string("string"), "description": .string("The key to delete translations from")]),
                        "languages": .object(["type": .string("array"), "items": .object(["type": .string("string")]), "description": .string("Array of language codes to delete, e.g. [\"ja\", \"en\", \"fr\"]")]),
                    ]),
                    "required": .array([.string("file"), .string("key"), .string("languages")]),
                ])
            ),
        ]
    }

    // MARK: - Tool Call Handler

    private static func handleToolCall(_ params: CallTool.Parameters) async -> CallTool.Result {
        do {
            let args = params.arguments ?? [:]
            let result = try await ToolHandlerRegistry.shared.execute(toolName: params.name, arguments: args)
            return .init(content: [.text(text: result, annotations: nil, _meta: nil)], isError: false)
        } catch {
            return .init(content: [.text(text: "Error: \(error.localizedDescription)", annotations: nil, _meta: nil)], isError: true)
        }
    }
}
