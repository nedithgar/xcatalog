import Foundation

/// Errors thrown by XCStringsKit
package enum XCStringsError: Error, LocalizedError, Sendable {
    case fileNotFound(path: String)
    case fileAlreadyExists(path: String)
    case invalidFileFormat(path: String, reason: String)
    case keyNotFound(key: String)
    case keyAlreadyExists(key: String)
    case languageNotFound(language: String, key: String)
    case nonTranslatableKey(key: String)
    case unsafeFormatString(key: String, language: String, diagnostics: [String])
    case richLocalizationUnsupported(key: String, language: String)
    case concurrentWriteConflict(path: String)
    case writeError(path: String, reason: String)
    case invalidJSON(reason: String)

    package var errorDescription: String? {
        switch self {
        case let .fileNotFound(path):
            return "File not found: \(path)"
        case let .fileAlreadyExists(path):
            return "File already exists: \(path)"
        case let .invalidFileFormat(path, reason):
            return "Invalid file format at '\(path)': \(reason)"
        case let .keyNotFound(key):
            return "Key not found: '\(key)'"
        case let .keyAlreadyExists(key):
            return "Key already exists: '\(key)'"
        case let .languageNotFound(language, key):
            return "Language '\(language)' not found for key '\(key)'"
        case let .nonTranslatableKey(key):
            return "Cannot add or update translations for non-translatable key '\(key)'. Change shouldTranslate before writing localizations."
        case let .unsafeFormatString(key, language, diagnostics):
            return "Unsafe format string for key '\(key)' language '\(language)': \(diagnostics.joined(separator: " "))"
        case let .richLocalizationUnsupported(key, language):
            return "Cannot add or update plain stringUnit translation for key '\(key)' language '\(language)' because the source or target localization uses variations or substitutions. Use a variation-aware operation instead."
        case let .concurrentWriteConflict(path):
            return "Concurrent write conflict for '\(path)'. Another write is already modifying this catalog; retry the operation or use a batch write."
        case let .writeError(path, reason):
            return "Failed to write file at '\(path)': \(reason)"
        case let .invalidJSON(reason):
            return "Invalid JSON: \(reason)"
        }
    }
}

/// Result type for CLI output
package struct CLIResult: Codable, Sendable {
    package let success: Bool
    package let message: String?
    package let error: String?

    package init(success: Bool, message: String?, error: String?) {
        self.success = success
        self.message = message
        self.error = error
    }

    package static func success(message: String? = nil) -> CLIResult {
        CLIResult(success: true, message: message, error: nil)
    }

    package static func failure(error: String) -> CLIResult {
        CLIResult(success: false, message: nil, error: error)
    }
}
