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
        let result = try await parser.addTranslationsBatch(entries: entries, allowOverwrite: overwrite)
        let responseEntries = batchResponseEntries(
            entries: entries,
            result: result
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
        let result = try await parser.updateTranslationsBatch(entries: entries)
        let responseEntries = batchResponseEntries(
            entries: entries,
            result: result
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
    entries: [BatchTranslationEntry],
    result: BatchWriteResult
) -> [MCPWriteEntryResult] {
    var responseEntries: [MCPWriteEntryResult] = []

    for entryResult in result.entryResults.sorted(by: { $0.inputIndex < $1.inputIndex }) {
        guard entries.indices.contains(entryResult.inputIndex) else {
            responseEntries.append(
                MCPWriteEntryResult(
                    inputIndex: entryResult.inputIndex,
                    key: entryResult.key,
                    action: .failed,
                    diagnostics: ["Batch result referenced an input index that does not exist."]
                )
            )
            continue
        }

        let entry = entries[entryResult.inputIndex]
        if entryResult.status == .failed {
            responseEntries.append(
                MCPWriteEntryResult(
                    inputIndex: entryResult.inputIndex,
                    key: entry.key,
                    action: .failed,
                    diagnostics: [entryResult.error ?? "Batch entry failed."]
                )
            )
            continue
        }

        for languageResult in entryResult.languageResults.sorted(by: { $0.language < $1.language }) {
            responseEntries.append(
                MCPWriteEntryResult(
                    inputIndex: entryResult.inputIndex,
                    key: entry.key,
                    language: languageResult.language,
                    action: MCPWriteAction(languageResult.action),
                    previousState: languageResult.previousState.map(MCPTranslationSnapshot.init(snapshot:)),
                    finalState: languageResult.finalState.map(MCPTranslationSnapshot.init(snapshot:)),
                    placeholderValidation: languageResult.placeholderValidation
                )
            )
        }
    }

    return responseEntries
}

private extension MCPWriteAction {
    init(_ action: BatchWriteTranslationAction) {
        switch action {
        case .inserted:
            self = .inserted
        case .updated:
            self = .updated
        }
    }
}
