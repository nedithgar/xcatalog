import Foundation

/// Handles write operations for xcstrings files
enum XCStringsWriter {
    /// Add a translation for a key
    static func addTranslation(
        to file: XCStringsFile,
        key: String,
        language: String,
        value: String,
        allowOverwrite: Bool = false
    ) throws -> XCStringsFile {
        var result = file

        _ = try validateTranslationWrite(for: key, translations: [language: value], in: result)

        if result.strings[key] == nil {
            result.strings[key] = StringEntry(localizations: [:])
        }

        if !allowOverwrite, result.strings[key]?.localizations?[language] != nil {
            throw XCStringsError.keyAlreadyExists(key: "\(key):\(language)")
        }

        if result.strings[key]?.localizations == nil {
            result.strings[key]?.localizations = [:]
        }

        result.strings[key]?.localizations?[language] = Localization(
            stringUnit: StringUnit(state: "translated", value: value)
        )

        return result
    }

    /// Add translations for multiple languages
    static func addTranslations(
        to file: XCStringsFile,
        key: String,
        translations: [String: String],
        allowOverwrite: Bool = false
    ) throws -> XCStringsFile {
        var result = file

        _ = try validateTranslationWrite(for: key, translations: translations, in: result)

        if result.strings[key] == nil {
            result.strings[key] = StringEntry(localizations: [:])
        }

        if result.strings[key]?.localizations == nil {
            result.strings[key]?.localizations = [:]
        }

        for (language, value) in translations {
            if !allowOverwrite, result.strings[key]?.localizations?[language] != nil {
                throw XCStringsError.keyAlreadyExists(key: "\(key):\(language)")
            }

            result.strings[key]?.localizations?[language] = Localization(
                stringUnit: StringUnit(state: "translated", value: value)
            )
        }

        return result
    }

    /// Update an existing translation
    static func updateTranslation(
        in file: XCStringsFile,
        key: String,
        language: String,
        value: String
    ) throws -> XCStringsFile {
        var result = file

        guard result.strings[key] != nil else {
            throw XCStringsError.keyNotFound(key: key)
        }

        _ = try validateTranslationWrite(for: key, translations: [language: value], in: result)

        guard result.strings[key]?.localizations?[language] != nil else {
            throw XCStringsError.languageNotFound(language: language, key: key)
        }

        result.strings[key]?.localizations?[language] = Localization(
            stringUnit: StringUnit(state: "translated", value: value)
        )

        return result
    }

    /// Update translations for multiple languages
    static func updateTranslations(
        in file: XCStringsFile,
        key: String,
        translations: [String: String]
    ) throws -> XCStringsFile {
        var result = file

        guard result.strings[key] != nil else {
            throw XCStringsError.keyNotFound(key: key)
        }

        _ = try validateTranslationWrite(for: key, translations: translations, in: result)

        for (language, value) in translations {
            guard result.strings[key]?.localizations?[language] != nil else {
                throw XCStringsError.languageNotFound(language: language, key: key)
            }

            result.strings[key]?.localizations?[language] = Localization(
                stringUnit: StringUnit(state: "translated", value: value)
            )
        }

        return result
    }

    /// Rename a key
    static func renameKey(
        in file: XCStringsFile,
        from oldKey: String,
        to newKey: String
    ) throws -> XCStringsFile {
        var result = file

        guard let entry = result.strings[oldKey] else {
            throw XCStringsError.keyNotFound(key: oldKey)
        }

        if result.strings[newKey] != nil {
            throw XCStringsError.keyAlreadyExists(key: newKey)
        }

        result.strings[newKey] = entry
        result.strings.removeValue(forKey: oldKey)

        return result
    }

    /// Delete a key entirely
    static func deleteKey(
        from file: XCStringsFile,
        key: String
    ) throws -> XCStringsFile {
        var result = file

        guard result.strings[key] != nil else {
            throw XCStringsError.keyNotFound(key: key)
        }

        result.strings.removeValue(forKey: key)

        return result
    }

    /// Delete a translation for a specific language
    static func deleteTranslation(
        from file: XCStringsFile,
        key: String,
        language: String
    ) throws -> XCStringsFile {
        var result = file

        guard result.strings[key] != nil else {
            throw XCStringsError.keyNotFound(key: key)
        }

        guard result.strings[key]?.localizations?[language] != nil else {
            throw XCStringsError.languageNotFound(language: language, key: key)
        }

        result.strings[key]?.localizations?.removeValue(forKey: language)

        return result
    }

    /// Delete translations for multiple languages
    static func deleteTranslations(
        from file: XCStringsFile,
        key: String,
        languages: [String]
    ) throws -> XCStringsFile {
        var result = file

        guard result.strings[key] != nil else {
            throw XCStringsError.keyNotFound(key: key)
        }

        for language in languages {
            guard result.strings[key]?.localizations?[language] != nil else {
                throw XCStringsError.languageNotFound(language: language, key: key)
            }

            result.strings[key]?.localizations?.removeValue(forKey: language)
        }

        return result
    }

    // MARK: - Batch Operations

    /// Add translations for multiple keys at once
    static func addTranslationsBatch(
        to file: XCStringsFile,
        entries: [BatchTranslationEntry],
        allowOverwrite: Bool = false
    ) -> (file: XCStringsFile, result: BatchWriteResult) {
        var result = file
        var succeeded: [String] = []
        var failed: [BatchWriteError] = []
        var placeholderValidations: [PlaceholderValidationResult] = []

        for entry in entries {
            do {
                let validations = try validateTranslationWrite(
                    for: entry.key,
                    translations: entry.translations,
                    in: result
                )
                result = try addTranslations(
                    to: result,
                    key: entry.key,
                    translations: entry.translations,
                    allowOverwrite: allowOverwrite
                )
                placeholderValidations.append(contentsOf: validations)
                succeeded.append(entry.key)
            } catch {
                failed.append(BatchWriteError(key: entry.key, error: error.localizedDescription))
            }
        }

        return (result, BatchWriteResult(succeeded: succeeded, failed: failed, placeholderValidations: placeholderValidations))
    }

    /// Update translations for multiple keys at once
    static func updateTranslationsBatch(
        in file: XCStringsFile,
        entries: [BatchTranslationEntry]
    ) -> (file: XCStringsFile, result: BatchWriteResult) {
        var result = file
        var succeeded: [String] = []
        var failed: [BatchWriteError] = []
        var placeholderValidations: [PlaceholderValidationResult] = []

        for entry in entries {
            do {
                let validations = try validateTranslationWrite(
                    for: entry.key,
                    translations: entry.translations,
                    in: result
                )
                result = try updateTranslations(
                    in: result,
                    key: entry.key,
                    translations: entry.translations
                )
                placeholderValidations.append(contentsOf: validations)
                succeeded.append(entry.key)
            } catch {
                failed.append(BatchWriteError(key: entry.key, error: error.localizedDescription))
            }
        }

        return (result, BatchWriteResult(succeeded: succeeded, failed: failed, placeholderValidations: placeholderValidations))
    }

    static func validateTranslationWrite(
        for key: String,
        translations: [String: String],
        in file: XCStringsFile
    ) throws -> [PlaceholderValidationResult] {
        guard file.strings[key]?.shouldTranslate != false else {
            throw XCStringsError.nonTranslatableKey(key: key)
        }

        guard let entry = file.strings[key] else {
            let sourceValue = translations[file.sourceLanguage] ?? key
            return try translations.map { language, value in
                let validation = FormatStringSafety.validate(
                    key: key,
                    language: language,
                    sourceValue: language == file.sourceLanguage ? value : sourceValue,
                    targetValue: value
                )
                try throwIfInvalid(validation)
                return validation
            }
        }

        return try translations.map { language, value in
            guard entry.localizations?[file.sourceLanguage]?.hasRichContent != true,
                  entry.localizations?[language]?.hasRichContent != true else {
                throw XCStringsError.richLocalizationUnsupported(key: key, language: language)
            }

            let sourceValue = entry.localizations?[file.sourceLanguage]?.stringUnit?.value
                ?? translations[file.sourceLanguage]
                ?? key
            let validation = FormatStringSafety.validate(
                key: key,
                language: language,
                sourceValue: language == file.sourceLanguage ? value : sourceValue,
                targetValue: value
            )
            try throwIfInvalid(validation)
            return validation
        }
    }

    private static func throwIfInvalid(_ validation: PlaceholderValidationResult) throws {
        if !validation.isValid {
            throw XCStringsError.unsafeFormatString(
                key: validation.key,
                language: validation.language,
                diagnostics: validation.diagnostics
            )
        }
    }
}
