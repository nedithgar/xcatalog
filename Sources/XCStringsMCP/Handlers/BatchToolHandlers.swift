import Foundation
import MCP
import XCStringsKit

// MARK: - Batch Check Keys Handler

struct BatchCheckKeysHandler: ToolHandler {
    static let toolName = "xcatalog_batch_check_keys"

    func execute(with context: ToolContext) async throws -> String {
        let file = try context.arguments.requireString("file")
        let keys = try context.arguments.requireStringArray("keys")
        let language = context.arguments.optionalString("language")

        let parser = XCStringsParser(path: file)
        let result = try await parser.checkKeys(keys, language: language)
        return try JSONEncoderHelper.encode(result)
    }
}

// MARK: - Batch Add Translations Handler

struct BatchAddTranslationsHandler: ToolHandler {
    static let toolName = "xcatalog_batch_add_translations"

    func execute(with context: ToolContext) async throws -> String {
        let file = try context.arguments.requireString("file")
        let entries = try context.arguments.requireBatchEntries("entries")
        let overwrite = context.arguments.bool("overwrite", default: false)

        let parser = XCStringsParser(path: file)
        let previousStates = await MCPWriteResponseBuilder.snapshots(parser: parser, entries: entries)
        let result = try await parser.addTranslationsBatch(entries: entries, allowOverwrite: overwrite)
        let responseEntries = await batchResponseEntries(
            parser: parser,
            entries: entries,
            result: result,
            previousStates: previousStates,
            defaultAction: .inserted
        )
        let response = MCPWriteResponse(
            file: file,
            operationType: .batchAddTranslations,
            languages: entries.flatMap { $0.translations.keys },
            fileChanged: result.successCount > 0,
            entries: responseEntries,
            placeholderValidations: result.placeholderValidations.filter(\.checked),
            validationWarnings: MCPWriteResponseBuilder.validationWarnings(from: result.placeholderValidations),
            batchResult: result
        )
        return try JSONEncoderHelper.encode(response)
    }
}

// MARK: - Batch Update Translations Handler

struct BatchUpdateTranslationsHandler: ToolHandler {
    static let toolName = "xcatalog_batch_update_translations"

    func execute(with context: ToolContext) async throws -> String {
        let file = try context.arguments.requireString("file")
        let entries = try context.arguments.requireBatchEntries("entries")

        let parser = XCStringsParser(path: file)
        let previousStates = await MCPWriteResponseBuilder.snapshots(parser: parser, entries: entries)
        let result = try await parser.updateTranslationsBatch(entries: entries)
        let responseEntries = await batchResponseEntries(
            parser: parser,
            entries: entries,
            result: result,
            previousStates: previousStates,
            defaultAction: .updated
        )
        let response = MCPWriteResponse(
            file: file,
            operationType: .batchUpdateTranslations,
            languages: entries.flatMap { $0.translations.keys },
            fileChanged: result.successCount > 0,
            entries: responseEntries,
            placeholderValidations: result.placeholderValidations.filter(\.checked),
            validationWarnings: MCPWriteResponseBuilder.validationWarnings(from: result.placeholderValidations),
            batchResult: result
        )
        return try JSONEncoderHelper.encode(response)
    }
}

// MARK: - Supplement Locale Handler

struct SupplementLocaleHandler: ToolHandler {
    static let toolName = "xcatalog_supplement_locale"

    func execute(with context: ToolContext) async throws -> String {
        let file = try context.arguments.requireString("file")
        let language = try context.arguments.requireString("language")
        let translations = try context.arguments.requireTranslations("translations")
        let dryRun = context.arguments.bool("dryRun", default: false)
        let allowPartial = context.arguments.bool("allowPartial", default: false)
        let overwrite = context.arguments.bool("overwrite", default: false)
        let validateCompile = context.arguments.bool("validateCompile", default: false)
        let compact = context.arguments.bool("compact", default: false)

        let parser = XCStringsParser(path: file)
        let result = try await parser.supplementLocale(
            language: language,
            translations: translations,
            dryRun: dryRun,
            allowPartial: allowPartial,
            overwrite: overwrite,
            validateCompile: validateCompile
        )
        if compact {
            let remainingKeys = try? await parser.listUntranslated(for: language)
            let projectedRemainingKeys = remainingKeys.map {
                result.projectedRemainingUntranslatedKeys(currentUntranslatedKeys: $0)
            }
            return try JSONEncoderHelper.encode(result.compact(remainingUntranslatedKeys: projectedRemainingKeys))
        }
        return try JSONEncoderHelper.encode(result)
    }
}

private func batchResponseEntries(
    parser: XCStringsParser,
    entries: [BatchTranslationEntry],
    result: BatchWriteResult,
    previousStates: [String: MCPTranslationSnapshot],
    defaultAction: MCPWriteAction
) async -> [MCPWriteEntryResult] {
    let succeeded = Set(result.succeeded)
    let failures = Dictionary(uniqueKeysWithValues: result.failed.map { ($0.key, $0.error) })
    var responseEntries: [MCPWriteEntryResult] = []

    for entry in entries.sorted(by: { $0.key < $1.key }) {
        if let failure = failures[entry.key] {
            responseEntries.append(
                MCPWriteEntryResult(
                    key: entry.key,
                    action: .failed,
                    diagnostics: [failure]
                )
            )
            continue
        }

        guard succeeded.contains(entry.key) else {
            continue
        }

        for language in entry.translations.keys.sorted() {
            let snapshotKey = MCPWriteResponseBuilder.snapshotKey(entry.key, language)
            let previousState = previousStates[snapshotKey]
            let action: MCPWriteAction = defaultAction == .inserted
                ? (previousState == nil ? .inserted : .updated)
                : defaultAction
            responseEntries.append(
                MCPWriteEntryResult(
                    key: entry.key,
                    language: language,
                    action: action,
                    previousState: previousState,
                    finalState: await MCPWriteResponseBuilder.snapshot(parser: parser, key: entry.key, language: language),
                    placeholderValidation: result.placeholderValidations.first {
                        $0.key == entry.key && $0.language == language
                    }
                )
            )
        }
    }

    return responseEntries
}
