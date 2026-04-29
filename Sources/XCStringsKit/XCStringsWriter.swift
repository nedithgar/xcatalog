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

        setPlainLocalization(in: &result, key: key, language: language, value: value)

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

            setPlainLocalization(in: &result, key: key, language: language, value: value)
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

        setPlainLocalization(in: &result, key: key, language: language, value: value)

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

            setPlainLocalization(in: &result, key: key, language: language, value: value)
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

        guard result.strings[oldKey] != nil else {
            throw XCStringsError.keyNotFound(key: oldKey)
        }

        if result.strings[newKey] != nil {
            throw XCStringsError.keyAlreadyExists(key: newKey)
        }

        result.strings.renameKey(from: oldKey, to: newKey)

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
        var entryResults: [BatchWriteEntryResult] = []
        var placeholderValidations: [PlaceholderValidationResult] = []

        for (inputIndex, entry) in entries.enumerated() {
            do {
                let validations = try validateTranslationWrite(
                    for: entry.key,
                    translations: entry.translations,
                    in: result
                )
                var candidate = result
                if candidate.strings[entry.key] == nil {
                    candidate.strings[entry.key] = StringEntry(localizations: [:])
                }

                if candidate.strings[entry.key]?.localizations == nil {
                    candidate.strings[entry.key]?.localizations = [:]
                }

                var languageResults: [BatchWriteLanguageResult] = []
                for (language, value) in entry.translations {
                    let previousState = translationSnapshot(in: candidate, key: entry.key, language: language)
                    if !allowOverwrite, previousState != nil {
                        throw XCStringsError.keyAlreadyExists(key: "\(entry.key):\(language)")
                    }

                    setPlainLocalization(in: &candidate, key: entry.key, language: language, value: value)
                    let finalState = translationSnapshot(in: candidate, key: entry.key, language: language)
                    languageResults.append(
                        BatchWriteLanguageResult(
                            language: language,
                            action: previousState == nil ? .inserted : .updated,
                            previousState: previousState,
                            finalState: finalState,
                            placeholderValidation: validations.first {
                                $0.key == entry.key && $0.language == language
                            }
                        )
                    )
                }

                result = candidate
                placeholderValidations.append(contentsOf: validations)
                entryResults.append(
                    BatchWriteEntryResult(
                        inputIndex: inputIndex,
                        key: entry.key,
                        status: .succeeded,
                        languageResults: languageResults
                    )
                )
            } catch {
                let message = error.localizedDescription
                entryResults.append(
                    BatchWriteEntryResult(inputIndex: inputIndex, key: entry.key, status: .failed, error: message)
                )
            }
        }

        return (
            result,
            BatchWriteResult(
                entryResults: entryResults,
                placeholderValidations: placeholderValidations
            )
        )
    }

    /// Update translations for multiple keys at once
    static func updateTranslationsBatch(
        in file: XCStringsFile,
        entries: [BatchTranslationEntry]
    ) -> (file: XCStringsFile, result: BatchWriteResult) {
        var result = file
        var entryResults: [BatchWriteEntryResult] = []
        var placeholderValidations: [PlaceholderValidationResult] = []

        for (inputIndex, entry) in entries.enumerated() {
            do {
                let validations = try validateTranslationWrite(
                    for: entry.key,
                    translations: entry.translations,
                    in: result
                )
                var candidate = result
                guard candidate.strings[entry.key] != nil else {
                    throw XCStringsError.keyNotFound(key: entry.key)
                }

                var languageResults: [BatchWriteLanguageResult] = []
                for (language, value) in entry.translations {
                    guard let previousState = translationSnapshot(in: candidate, key: entry.key, language: language) else {
                        throw XCStringsError.languageNotFound(language: language, key: entry.key)
                    }

                    setPlainLocalization(in: &candidate, key: entry.key, language: language, value: value)
                    languageResults.append(
                        BatchWriteLanguageResult(
                            language: language,
                            action: .updated,
                            previousState: previousState,
                            finalState: translationSnapshot(in: candidate, key: entry.key, language: language),
                            placeholderValidation: validations.first {
                                $0.key == entry.key && $0.language == language
                            }
                        )
                    )
                }

                result = candidate
                placeholderValidations.append(contentsOf: validations)
                entryResults.append(
                    BatchWriteEntryResult(
                        inputIndex: inputIndex,
                        key: entry.key,
                        status: .succeeded,
                        languageResults: languageResults
                    )
                )
            } catch {
                let message = error.localizedDescription
                entryResults.append(
                    BatchWriteEntryResult(inputIndex: inputIndex, key: entry.key, status: .failed, error: message)
                )
            }
        }

        return (
            result,
            BatchWriteResult(
                entryResults: entryResults,
                placeholderValidations: placeholderValidations
            )
        )
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

    private static func setPlainLocalization(
        in file: inout XCStringsFile,
        key: String,
        language: String,
        value: String
    ) {
        var entry = file.strings[key] ?? StringEntry(localizations: [:])
        var localizations = entry.localizations ?? [:]
        localizations[language] = plainLocalization(from: localizations[language], value: value)
        entry.localizations = localizations
        file.strings[key] = entry
    }

    private static func plainLocalization(from existing: Localization?, value: String) -> Localization {
        var localization = existing ?? Localization()
        localization.stringUnit = StringUnit(
            state: localization.stringUnit?.state ?? "translated",
            value: value,
            unknownFields: localization.stringUnit?.unknownFields ?? [:]
        )
        return localization
    }

    private static func translationSnapshot(
        in file: XCStringsFile,
        key: String,
        language: String
    ) -> BatchWriteTranslationSnapshot? {
        guard let localization = file.strings[key]?.localizations?[language] else {
            return nil
        }

        return BatchWriteTranslationSnapshot(
            key: key,
            language: language,
            value: localization.stringUnit?.value,
            state: localization.stringUnit?.state,
            hasVariations: localization.variations != nil,
            hasSubstitutions: localization.substitutions != nil
        )
    }
}
