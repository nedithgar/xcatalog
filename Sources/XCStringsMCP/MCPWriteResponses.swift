import Foundation
import XCStringsKit

enum MCPWriteOperationType: String, Codable, Equatable, Sendable {
    case addTranslation
    case addTranslations
    case updateTranslation
    case updateTranslations
    case renameKey
    case deleteKey
    case deleteTranslation
    case deleteTranslations
    case batchAddTranslations
    case batchUpdateTranslations
}

enum MCPWriteAction: String, Codable, Equatable, Sendable {
    case inserted
    case updated
    case deleted
    case renamed
    case failed
}

struct MCPTranslationSnapshot: Codable, Sendable {
    let key: String
    let language: String
    let value: String?
    let state: String?
    let hasVariations: Bool
    let hasSubstitutions: Bool

    init(snapshot: BatchWriteTranslationSnapshot) {
        self.key = snapshot.key
        self.language = snapshot.language
        self.value = snapshot.value
        self.state = snapshot.state
        self.hasVariations = snapshot.hasVariations
        self.hasSubstitutions = snapshot.hasSubstitutions
    }
}

struct MCPWriteEntryResult: Codable, Sendable {
    let inputIndex: Int?
    let key: String
    let language: String?
    let action: MCPWriteAction
    let previousState: MCPTranslationSnapshot?
    let finalState: MCPTranslationSnapshot?
    let previousKey: String?
    let finalKey: String?
    let diagnostics: [String]
    let placeholderValidation: PlaceholderValidationResult?

    init(
        inputIndex: Int? = nil,
        key: String,
        language: String? = nil,
        action: MCPWriteAction,
        previousState: MCPTranslationSnapshot? = nil,
        finalState: MCPTranslationSnapshot? = nil,
        previousKey: String? = nil,
        finalKey: String? = nil,
        diagnostics: [String] = [],
        placeholderValidation: PlaceholderValidationResult? = nil
    ) {
        self.inputIndex = inputIndex
        self.key = key
        self.language = language
        self.action = action
        self.previousState = previousState
        self.finalState = finalState
        self.previousKey = previousKey
        self.finalKey = finalKey
        self.diagnostics = diagnostics
        self.placeholderValidation = placeholderValidation
    }
}

struct MCPWriteResponse: Codable, Sendable {
    let success: Bool
    let file: String
    let operationType: MCPWriteOperationType
    let key: String?
    let languages: [String]
    let fileChanged: Bool
    let insertedCount: Int
    let updatedCount: Int
    let deletedCount: Int
    let renamedCount: Int
    let failedCount: Int
    let entries: [MCPWriteEntryResult]
    let placeholderValidations: [PlaceholderValidationResult]
    let validationWarnings: [String]
    let batchResult: BatchWriteResult?

    init(
        file: String,
        operationType: MCPWriteOperationType,
        key: String? = nil,
        languages: [String] = [],
        fileChanged: Bool,
        entries: [MCPWriteEntryResult],
        placeholderValidations: [PlaceholderValidationResult] = [],
        validationWarnings: [String] = [],
        batchResult: BatchWriteResult? = nil
    ) {
        self.success = entries.allSatisfy { $0.action != .failed }
        self.file = file
        self.operationType = operationType
        self.key = key
        self.languages = languages.sorted()
        self.fileChanged = fileChanged
        self.insertedCount = entries.filter { $0.action == .inserted }.count
        self.updatedCount = entries.filter { $0.action == .updated }.count
        self.deletedCount = entries.filter { $0.action == .deleted }.count
        self.renamedCount = entries.filter { $0.action == .renamed }.count
        self.failedCount = entries.filter { $0.action == .failed }.count
        self.entries = entries
        self.placeholderValidations = placeholderValidations
        self.validationWarnings = validationWarnings
        self.batchResult = batchResult
    }
}

enum MCPWriteResponseBuilder {
    static func entries(
        key: String,
        languageResults: [BatchWriteLanguageResult]
    ) -> [MCPWriteEntryResult] {
        languageResults.sorted { $0.language < $1.language }.map { languageResult in
            MCPWriteEntryResult(
                key: key,
                language: languageResult.language,
                action: MCPWriteAction(languageResult.action),
                previousState: languageResult.previousState.map(MCPTranslationSnapshot.init(snapshot:)),
                finalState: languageResult.finalState.map(MCPTranslationSnapshot.init(snapshot:)),
                placeholderValidation: languageResult.placeholderValidation
            )
        }
    }

    static func deletedEntries(
        key: String,
        snapshots: [BatchWriteTranslationSnapshot]
    ) -> [MCPWriteEntryResult] {
        snapshots.sorted { $0.language < $1.language }.map { snapshot in
            MCPWriteEntryResult(
                key: key,
                language: snapshot.language,
                action: .deleted,
                previousState: MCPTranslationSnapshot(snapshot: snapshot)
            )
        }
    }

    static func validationWarnings(from validations: [PlaceholderValidationResult]) -> [String] {
        let checkedCount = validations.filter(\.checked).count
        guard checkedCount > 0 else {
            return []
        }

        return [
            "Placeholder validation passed for \(checkedCount) language\(checkedCount == 1 ? "" : "s")."
        ]
    }
}

extension MCPWriteAction {
    init(_ action: BatchWriteTranslationAction) {
        switch action {
        case .inserted:
            self = .inserted
        case .updated:
            self = .updated
        }
    }
}
