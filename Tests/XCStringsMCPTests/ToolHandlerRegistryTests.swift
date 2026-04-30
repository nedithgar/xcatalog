import Foundation
import MCP
import Testing

@testable import XCStringsMCP

@Suite("ToolHandlerRegistry tests")
struct ToolHandlerRegistryTests {

    @Test("All expected handlers are registered")
    func allHandlersRegistered() async {
        let registry = ToolHandlerRegistry.shared
        let registeredTools = await registry.registeredToolNames

        // Health handlers
        #expect(registeredTools.contains("xcatalog_health"))

        // List handlers
        #expect(registeredTools.contains("xcatalog_list_keys"))
        #expect(registeredTools.contains("xcatalog_list_languages"))
        #expect(registeredTools.contains("xcatalog_list_untranslated"))
        #expect(registeredTools.contains("xcatalog_list_stale"))
        #expect(registeredTools.contains("xcatalog_preflight_locale"))

        // Validation handlers
        #expect(registeredTools.contains("xcatalog_validate_catalog"))
        #expect(registeredTools.contains("xcatalog_validate_placeholders"))
        #expect(registeredTools.contains("xcatalog_find_suspicious_keys"))

        // Get handlers
        #expect(registeredTools.contains("xcatalog_get_source_language"))
        #expect(registeredTools.contains("xcatalog_get_key"))
        #expect(registeredTools.contains("xcatalog_check_key"))
        #expect(registeredTools.contains("xcatalog_check_coverage"))

        // Stats handlers
        #expect(registeredTools.contains("xcatalog_stats_coverage"))
        #expect(registeredTools.contains("xcatalog_stats_progress"))
        #expect(registeredTools.contains("xcatalog_batch_stats_coverage"))

        // Create handlers
        #expect(registeredTools.contains("xcatalog_create_file"))

        // Write handlers
        #expect(registeredTools.contains("xcatalog_add_translation"))
        #expect(registeredTools.contains("xcatalog_add_translations"))
        #expect(registeredTools.contains("xcatalog_update_translation"))
        #expect(registeredTools.contains("xcatalog_update_translations"))
        #expect(registeredTools.contains("xcatalog_rename_key"))

        // Delete handlers
        #expect(registeredTools.contains("xcatalog_delete_key"))
        #expect(registeredTools.contains("xcatalog_delete_translation"))
        #expect(registeredTools.contains("xcatalog_delete_translations"))

        // Batch handlers
        #expect(registeredTools.contains("xcatalog_batch_check_keys"))
        #expect(registeredTools.contains("xcatalog_batch_add_translations"))
        #expect(registeredTools.contains("xcatalog_batch_update_translations"))
        #expect(registeredTools.contains("xcatalog_supplement_locale"))
    }

    @Test("Execute throws for unknown tool")
    func executeUnknownToolThrows() async {
        let registry = ToolHandlerRegistry.shared

        await #expect(throws: Error.self) {
            _ = try await registry.execute(toolName: "unknown_tool", arguments: [:])
        }
    }

    @Test("handler(for:) returns handler for registered tool")
    func handlerForRegisteredTool() async {
        let registry = ToolHandlerRegistry.shared
        let handler = await registry.handler(for: "xcatalog_list_keys")
        #expect(handler != nil)
    }

    @Test("handler(for:) returns nil for unregistered tool")
    func handlerForUnregisteredTool() async {
        let registry = ToolHandlerRegistry.shared
        let handler = await registry.handler(for: "nonexistent_tool")
        #expect(handler == nil)
    }
}
