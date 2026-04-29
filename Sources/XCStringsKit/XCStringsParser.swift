import Foundation

/// Facade for xcstrings file operations
/// Delegates to specialized components following Single Responsibility Principle
package actor XCStringsParser {
    private let path: String
    private let fileHandler: XCStringsFileHandler

    package init(path: String) {
        self.path = path
        self.fileHandler = XCStringsFileHandler(path: path)
    }

    // MARK: - File Operations

    /// Load file from disk
    func load() throws -> XCStringsFile {
        try fileHandler.load()
    }

    /// Save file to disk
    func save(_ file: XCStringsFile) throws {
        try fileHandler.save(file)
    }

    /// Create a new xcstrings file
    package func createFile(sourceLanguage: String, overwrite: Bool = false) async throws {
        try await withExclusiveFileAccess { fileHandler in
            try fileHandler.create(sourceLanguage: sourceLanguage, overwrite: overwrite)
        }
    }

    /// Create a new xcstrings file (static version for convenience)
    package static func createFile(at path: String, sourceLanguage: String, overwrite: Bool = false) async throws {
        let handler = XCStringsFileHandler(path: path)
        try await XCStringsFileAccessCoordinator.withExclusiveAccess(to: path) {
            try handler.create(sourceLanguage: sourceLanguage, overwrite: overwrite)
        }
    }

    private func withExclusiveFileAccess<T: Sendable>(
        _ operation: @Sendable (XCStringsFileHandler) throws -> T
    ) async throws -> T {
        try await XCStringsFileAccessCoordinator.withExclusiveAccess(to: path) {
            try operation(fileHandler)
        }
    }

    // MARK: - Read Operations

    /// Get all keys sorted alphabetically
    package func listKeys() throws -> [String] {
        let file = try load()
        return XCStringsReader(file: file).listKeys()
    }

    /// Get all languages used in the file
    package func listLanguages() throws -> [String] {
        let file = try load()
        return XCStringsReader(file: file).listLanguages()
    }

    /// Get untranslated keys for a specific language
    package func listUntranslated(for language: String) throws -> [String] {
        let file = try load()
        return XCStringsReader(file: file).listUntranslated(for: language)
    }

    /// Get keys with stale extraction state
    package func listStaleKeys() throws -> [String] {
        let file = try load()
        return XCStringsReader(file: file).listStaleKeys()
    }

    /// Get source language
    package func getSourceLanguage() throws -> String {
        let file = try load()
        return XCStringsReader(file: file).getSourceLanguage()
    }

    /// Get key information
    package func getKey(_ key: String, language: String? = nil) throws -> KeyInfo {
        let file = try load()
        return try XCStringsReader(file: file).getKey(key, language: language)
    }

    /// Get translation for a key
    package func getTranslation(key: String, language: String?) throws -> [String: TranslationInfo] {
        let file = try load()
        return try XCStringsReader(file: file).getTranslation(key: key, language: language)
    }

    /// Check if a key exists
    package func checkKey(_ key: String, language: String?) throws -> Bool {
        let file = try load()
        return XCStringsReader(file: file).checkKey(key, language: language)
    }

    /// Check if multiple keys exist
    package func checkKeys(_ keys: [String], language: String?) throws -> BatchCheckKeysResult {
        let file = try load()
        return XCStringsReader(file: file).checkKeys(keys, language: language)
    }

    /// Check coverage for a key
    package func checkCoverage(_ key: String) throws -> CoverageInfo {
        let file = try load()
        return try XCStringsReader(file: file).checkCoverage(key)
    }

    /// Classify target-locale work before mutating the catalog
    package func preflightLocale(_ language: String) throws -> PreflightLocaleReport {
        let file = try load()
        return XCStringsPreflightClassifier(file: file).preflightLocale(language)
    }

    /// Validate JSON/model shape, optional xcstringstool compilation, placeholders, rich records, and suspicious keys.
    package func validateCatalog(
        validateCompile: Bool = false,
        compileLanguages: [String] = []
    ) -> CatalogValidationReport {
        XCStringsCatalogValidator.validateCatalog(
            path: path,
            validateCompile: validateCompile,
            compileLanguages: compileLanguages
        )
    }

    /// Validate placeholder consistency across all translated locales.
    package func validatePlaceholders() throws -> PlaceholderValidationReport {
        let file = try load()
        return XCStringsCatalogValidator.validatePlaceholders(in: file)
    }

    /// Find accidental or hygiene-risky catalog keys.
    package func findSuspiciousKeys() throws -> SuspiciousKeysReport {
        let file = try load()
        return XCStringsCatalogValidator.findSuspiciousKeys(in: file)
    }

    // MARK: - Stats Operations

    /// Get overall statistics
    package func getStats() throws -> StatsInfo {
        let file = try load()
        return XCStringsStatsCalculator(file: file).getStats()
    }

    /// Get progress for a specific language
    package func getProgress(for language: String) throws -> LanguageStats {
        let file = try load()
        return try XCStringsStatsCalculator(file: file).getProgress(for: language)
    }

    /// Get batch coverage for multiple files (token-efficient)
    package static func getBatchCoverage(paths: [String]) throws -> BatchCoverageSummary {
        let files: [(path: String, file: XCStringsFile)] = try paths.map { path in
            let handler = XCStringsFileHandler(path: path)
            let file = try handler.load()
            return (path, file)
        }
        return XCStringsStatsCalculator.getBatchCoverage(files: files)
    }

    // MARK: - Compact Stats Operations (100% languages omitted)

    /// Get compact statistics (only shows incomplete languages)
    package func getCompactStats() throws -> CompactStatsInfo {
        let file = try load()
        return XCStringsStatsCalculator(file: file).getCompactStats()
    }

    /// Get compact batch coverage for multiple files
    package static func getCompactBatchCoverage(paths: [String]) throws -> CompactBatchCoverageSummary {
        let files: [(path: String, file: XCStringsFile)] = try paths.map { path in
            let handler = XCStringsFileHandler(path: path)
            let file = try handler.load()
            return (path, file)
        }
        return XCStringsStatsCalculator.getCompactBatchCoverage(files: files)
    }

    /// Get batch stale keys for multiple files
    package static func getBatchStaleKeys(paths: [String]) throws -> BatchStaleKeysSummary {
        let fileSummaries: [FileStaleKeysSummary] = try paths.map { path in
            let handler = XCStringsFileHandler(path: path)
            let file = try handler.load()
            let staleKeys = XCStringsReader(file: file).listStaleKeys()
            return FileStaleKeysSummary(file: path, staleKeys: staleKeys)
        }
        return BatchStaleKeysSummary(files: fileSummaries)
    }

    // MARK: - Write Operations

    /// Add a translation
    @discardableResult
    package func addTranslation(
        key: String,
        language: String,
        value: String,
        allowOverwrite: Bool = false
    ) async throws -> TranslationWriteResult {
        try await withExclusiveFileAccess { fileHandler in
            let file = try fileHandler.load()
            let validations = try XCStringsWriter.validateTranslationWrite(
                for: key,
                translations: [language: value],
                in: file
            )
            let updated = try XCStringsWriter.addTranslation(to: file, key: key, language: language, value: value, allowOverwrite: allowOverwrite)
            try fileHandler.save(updated)
            return TranslationWriteResult(key: key, languages: [language], placeholderValidations: validations)
        }
    }

    /// Add translations for multiple languages
    @discardableResult
    package func addTranslations(
        key: String,
        translations: [String: String],
        allowOverwrite: Bool = false
    ) async throws -> TranslationWriteResult {
        try await withExclusiveFileAccess { fileHandler in
            let file = try fileHandler.load()
            let validations = try XCStringsWriter.validateTranslationWrite(
                for: key,
                translations: translations,
                in: file
            )
            let updated = try XCStringsWriter.addTranslations(to: file, key: key, translations: translations, allowOverwrite: allowOverwrite)
            try fileHandler.save(updated)
            return TranslationWriteResult(
                key: key,
                languages: translations.keys.sorted(),
                placeholderValidations: validations
            )
        }
    }

    /// Update an existing translation
    @discardableResult
    package func updateTranslation(key: String, language: String, value: String) async throws -> TranslationWriteResult {
        try await withExclusiveFileAccess { fileHandler in
            let file = try fileHandler.load()
            guard file.strings[key] != nil else {
                throw XCStringsError.keyNotFound(key: key)
            }
            guard file.strings[key]?.localizations?[language] != nil else {
                throw XCStringsError.languageNotFound(language: language, key: key)
            }
            let validations = try XCStringsWriter.validateTranslationWrite(
                for: key,
                translations: [language: value],
                in: file
            )
            let updated = try XCStringsWriter.updateTranslation(in: file, key: key, language: language, value: value)
            try fileHandler.save(updated)
            return TranslationWriteResult(key: key, languages: [language], placeholderValidations: validations)
        }
    }

    /// Update translations for multiple languages
    @discardableResult
    package func updateTranslations(key: String, translations: [String: String]) async throws -> TranslationWriteResult {
        try await withExclusiveFileAccess { fileHandler in
            let file = try fileHandler.load()
            guard file.strings[key] != nil else {
                throw XCStringsError.keyNotFound(key: key)
            }
            for language in translations.keys {
                guard file.strings[key]?.localizations?[language] != nil else {
                    throw XCStringsError.languageNotFound(language: language, key: key)
                }
            }
            let validations = try XCStringsWriter.validateTranslationWrite(
                for: key,
                translations: translations,
                in: file
            )
            let updated = try XCStringsWriter.updateTranslations(in: file, key: key, translations: translations)
            try fileHandler.save(updated)
            return TranslationWriteResult(
                key: key,
                languages: translations.keys.sorted(),
                placeholderValidations: validations
            )
        }
    }

    // MARK: - Batch Operations (Multiple Keys)

    /// Add translations for multiple keys at once
    package func addTranslationsBatch(entries: [BatchTranslationEntry], allowOverwrite: Bool = false) async throws -> BatchWriteResult {
        try await withExclusiveFileAccess { fileHandler in
            let file = try fileHandler.load()
            let (updated, result) = XCStringsWriter.addTranslationsBatch(to: file, entries: entries, allowOverwrite: allowOverwrite)
            try fileHandler.save(updated)
            return result
        }
    }

    /// Update translations for multiple keys at once
    package func updateTranslationsBatch(entries: [BatchTranslationEntry]) async throws -> BatchWriteResult {
        try await withExclusiveFileAccess { fileHandler in
            let file = try fileHandler.load()
            let (updated, result) = XCStringsWriter.updateTranslationsBatch(in: file, entries: entries)
            try fileHandler.save(updated)
            return result
        }
    }

    /// Atomically supplement one target locale from a key/value translation map.
    package func supplementLocale(
        language: String,
        translations: [String: String],
        dryRun: Bool = false,
        allowPartial: Bool = false,
        overwrite: Bool = false,
        validateCompile: Bool = false,
        compileValidator: @escaping LocaleSupplementCompileValidator = XCStringsCatalogCompiler.validateCompile
    ) async throws -> LocaleSupplementResult {
        try await withExclusiveFileAccess { fileHandler in
            let file = try fileHandler.load()
            let options = LocaleSupplementOptions(
                language: language,
                dryRun: dryRun,
                allowPartial: allowPartial,
                overwrite: overwrite,
                validateCompile: validateCompile
            )
            let supplementTranslations = translations.map { LocaleSupplementTranslation(key: $0.key, value: $0.value) }
            let plan = XCStringsLocaleSupplementer.plan(
                file: file,
                translations: supplementTranslations,
                options: options
            )

            if dryRun {
                let compileValidation: LocaleSupplementCompileValidation
                let compileValidationRanOnProjectedCatalog: Bool
                if validateCompile && plan.hasBlockingDiagnostics && !allowPartial {
                    compileValidation = LocaleSupplementCompileValidation(
                        status: .notRunDueToBlockingDiagnostics,
                        diagnostics: "Projected compile validation was skipped because the atomic dry-run plan has unsafe or failed entries and allowPartial is false."
                    )
                    compileValidationRanOnProjectedCatalog = false
                } else if validateCompile && plan.hasBlockingDiagnostics && allowPartial && !plan.hasWritableChanges {
                    compileValidation = LocaleSupplementCompileValidation(
                        status: .notRunDueToBlockingDiagnostics,
                        diagnostics: "Projected compile validation was skipped because partial dry-run was allowed, but no valid insert or update actions were available."
                    )
                    compileValidationRanOnProjectedCatalog = false
                } else if validateCompile {
                    let updated = XCStringsLocaleSupplementer.apply(plan: plan, to: file)
                    compileValidation = compileValidator(updated, language)
                    compileValidationRanOnProjectedCatalog = compileValidation.status == .passed || compileValidation.status == .failed
                } else {
                    compileValidation = .notRequested
                    compileValidationRanOnProjectedCatalog = false
                }

                return LocaleSupplementResult(
                    status: .dryRun,
                    fileChanged: false,
                    plan: plan,
                    compileValidation: compileValidation,
                    compileValidationRanOnProjectedCatalog: compileValidationRanOnProjectedCatalog,
                    diagnostics: ["Dry run only; no file was written."]
                )
            }

            if plan.hasBlockingDiagnostics && !allowPartial {
                let compileValidation = validateCompile
                    ? LocaleSupplementCompileValidation(
                        status: .notRunDueToBlockingDiagnostics,
                        diagnostics: "Compile validation was skipped because the atomic supplement plan has unsafe or failed entries and allowPartial is false."
                    )
                    : .notRequested
                return LocaleSupplementResult(
                    status: .refused,
                    fileChanged: false,
                    plan: plan,
                    compileValidation: compileValidation,
                    diagnostics: ["Atomic locale supplement refused because at least one entry is unsafe or failed validation."]
                )
            }

            if plan.hasBlockingDiagnostics && allowPartial && !plan.hasWritableChanges {
                return LocaleSupplementResult(
                    status: .refused,
                    fileChanged: false,
                    plan: plan,
                    diagnostics: ["Partial locale supplement was allowed, but no valid insert or update actions were available to write."]
                )
            }

            guard plan.hasWritableChanges else {
                return LocaleSupplementResult(
                    status: .unchanged,
                    fileChanged: false,
                    plan: plan,
                    diagnostics: ["No insert or update actions were required."]
                )
            }

            let updated = XCStringsLocaleSupplementer.apply(plan: plan, to: file)
            let compileValidation = validateCompile
                ? compileValidator(updated, language)
                : .notRequested
            let compileValidationRanOnProjectedCatalog = compileValidation.status == .passed || compileValidation.status == .failed

            if compileValidation.status == .failed || compileValidation.status == .unavailable {
                return LocaleSupplementResult(
                    status: .compileFailed,
                    fileChanged: false,
                    plan: plan,
                    compileValidation: compileValidation,
                    compileValidationRanOnProjectedCatalog: compileValidationRanOnProjectedCatalog,
                    diagnostics: ["Compile validation failed before saving; no file was written."]
                )
            }

            try fileHandler.save(updated)
            let status: LocaleSupplementStatus = plan.hasBlockingDiagnostics ? .partialWritten : .written
            return LocaleSupplementResult(
                status: status,
                fileChanged: true,
                plan: plan,
                compileValidation: compileValidation,
                compileValidationRanOnProjectedCatalog: compileValidationRanOnProjectedCatalog
            )
        }
    }

    /// Rename a key
    package func renameKey(from oldKey: String, to newKey: String) async throws {
        try await withExclusiveFileAccess { fileHandler in
            let file = try fileHandler.load()
            let updated = try XCStringsWriter.renameKey(in: file, from: oldKey, to: newKey)
            try fileHandler.save(updated)
        }
    }

    // MARK: - Delete Operations

    /// Delete a key entirely
    package func deleteKey(_ key: String) async throws {
        try await withExclusiveFileAccess { fileHandler in
            let file = try fileHandler.load()
            let updated = try XCStringsWriter.deleteKey(from: file, key: key)
            try fileHandler.save(updated)
        }
    }

    /// Delete a translation for a specific language
    package func deleteTranslation(key: String, language: String) async throws {
        try await withExclusiveFileAccess { fileHandler in
            let file = try fileHandler.load()
            let updated = try XCStringsWriter.deleteTranslation(from: file, key: key, language: language)
            try fileHandler.save(updated)
        }
    }

    /// Delete translations for multiple languages
    package func deleteTranslations(key: String, languages: [String]) async throws {
        try await withExclusiveFileAccess { fileHandler in
            let file = try fileHandler.load()
            let updated = try XCStringsWriter.deleteTranslations(from: file, key: key, languages: languages)
            try fileHandler.save(updated)
        }
    }
}
