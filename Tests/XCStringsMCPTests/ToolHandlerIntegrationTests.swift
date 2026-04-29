import Foundation
import MCP
import Testing

@testable import XCStringsMCP
@testable import XCStringsKit

@Suite("Tool handler integration tests")
struct ToolHandlerIntegrationTests {

    // MARK: - Health Handler

    @Test("HealthHandler returns public runtime metadata by default")
    func healthHandler() async throws {
        let handler = HealthHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [:]))

        let result = try await handler.execute(with: context)
        let health = try decodeJSON(result, as: HealthInfo.self)

        #expect(health.version == XCStringsMCPMetadata.version)
        #expect(health.serverName == XCStringsMCPMetadata.serverName)
        #expect(health.toolSchemaVersion == XCStringsMCPMetadata.toolSchemaVersion)
        #expect(health.binaryPath == nil)
        #expect(health.currentWorkingDirectory == nil)
        #expect(health.allowedRoots == nil)
        #expect(!result.contains("binaryPath"))
        #expect(!result.contains("currentWorkingDirectory"))
        #expect(!result.contains("allowedRoots"))
    }

    @Test("HealthInfo omits sensitive local paths by default")
    func healthInfoOmitsSensitiveLocalPathsByDefault() {
        let health = HealthInfo.current(
            environment: [
                "XCATALOG_GIT_COMMIT": "abc1234",
                "XCATALOG_BUILD_CONFIGURATION": "debug",
                "XCATALOG_BUILD_DATE": "2026-04-28T00:00:00Z",
                "XCATALOG_ALLOWED_ROOTS": "/tmp/one,/tmp/two:/tmp/three",
                "XCATALOG_HEALTH_INCLUDE_SENSITIVE": "true",
            ],
            currentDirectoryPath: "/tmp/work",
            executablePath: "/tmp/work/.build/debug/xcatalog"
        )

        #expect(health.gitCommit == "abc1234")
        #expect(health.buildConfiguration == "debug")
        #expect(health.buildDate == "2026-04-28T00:00:00Z")
        #expect(health.currentWorkingDirectory == nil)
        #expect(health.binaryPath == nil)
        #expect(health.allowedRoots == nil)
    }

    @Test("HealthInfo requires request and environment opt-in for sensitive local paths")
    func healthInfoRequiresRequestAndEnvironmentOptInForSensitiveLocalPaths() {
        let environment = [
            "XCATALOG_GIT_COMMIT": "abc1234",
            "XCATALOG_BUILD_CONFIGURATION": "debug",
            "XCATALOG_BUILD_DATE": "2026-04-28T00:00:00Z",
            "XCATALOG_ALLOWED_ROOTS": "/tmp/one,/tmp/two:/tmp/three",
            "XCATALOG_HEALTH_INCLUDE_SENSITIVE": "true",
        ]

        let health = HealthInfo.current(
            includeSensitivePaths: true,
            environment: environment,
            currentDirectoryPath: "/tmp/work",
            executablePath: "/tmp/work/.build/debug/xcatalog"
        )

        #expect(health.currentWorkingDirectory == "/tmp/work")
        #expect(health.binaryPath == "/tmp/work/.build/debug/xcatalog")
        #expect(health.allowedRoots == ["/tmp/one", "/tmp/two", "/tmp/three"])

        let blockedHealth = HealthInfo.current(
            includeSensitivePaths: true,
            environment: environment.filter { $0.key != "XCATALOG_HEALTH_INCLUDE_SENSITIVE" },
            currentDirectoryPath: "/tmp/work",
            executablePath: "/tmp/work/.build/debug/xcatalog"
        )

        #expect(blockedHealth.currentWorkingDirectory == nil)
        #expect(blockedHealth.binaryPath == nil)
        #expect(blockedHealth.allowedRoots == nil)
    }

    // MARK: - List Handlers

    @Test("ListKeysHandler returns all keys")
    func listKeysHandler() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.multipleKeysPartialTranslations)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = ListKeysHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path)
        ]))

        let result = try await handler.execute(with: context)
        #expect(result.contains("Hello"))
        #expect(result.contains("Goodbye"))
        #expect(result.contains("Welcome"))
    }

    @Test("ListLanguagesHandler returns all languages")
    func listLanguagesHandler() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.singleKeyMultipleLangs)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = ListLanguagesHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path)
        ]))

        let result = try await handler.execute(with: context)
        #expect(result.contains("en"))
        #expect(result.contains("ja"))
        #expect(result.contains("de"))
    }

    @Test("ListUntranslatedHandler returns untranslated keys")
    func listUntranslatedHandler() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.multipleKeysPartialTranslations)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = ListUntranslatedHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "language": .string("ja")
        ]))

        let result = try await handler.execute(with: context)
        #expect(result.contains("Goodbye"))
    }

    @Test("ListUntranslatedHandler uses derived real-world sample semantics")
    func listUntranslatedHandlerRealWorldSample() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.realWorldSample)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = ListUntranslatedHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "language": .string("en")
        ]))

        let result = try await handler.execute(with: context)
        let untranslated: [String] = try decodeJSON(result, as: [String].self)

        #expect(untranslated == ["This view now has a bit more to say."])
    }

    @Test("ListStaleHandler returns stale keys")
    func listStaleHandler() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.withStaleKeys)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = ListStaleHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path)
        ]))

        let result = try await handler.execute(with: context)
        #expect(result.contains("StaleKey1"))
        #expect(result.contains("StaleKey2"))
        #expect(!result.contains("\"ActiveKey\""))
    }

    @Test("BatchListStaleHandler returns stale keys across multiple files")
    func batchListStaleHandler() async throws {
        let path1 = try TestHelper.createTempFile(content: TestFixtures.withStaleKeys)
        let path2 = try TestHelper.createTempFile(content: TestFixtures.singleKeySingleLang)
        defer {
            TestHelper.removeTempFile(at: path1)
            TestHelper.removeTempFile(at: path2)
        }

        let handler = BatchListStaleHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "files": .array([.string(path1), .string(path2)])
        ]))

        let result = try await handler.execute(with: context)
        #expect(result.contains("StaleKey1"))
        #expect(result.contains("StaleKey2"))
        #expect(result.contains("totalStaleKeys"))
        #expect(result.contains("note"))
    }

    @Test("PreflightLocaleHandler classifies target locale work")
    func preflightLocaleHandler() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.preflightMixedCatalog)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = PreflightLocaleHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "language": .string("es")
        ]))

        let result = try await handler.execute(with: context)
        let report = try decodeJSON(result, as: PreflightLocaleReport.self)

        #expect(report.summary.safeToBatchAddKeys == ["plain.missing", "stale.missing"])
        #expect(report.summary.formatStringKeysRequiringValidation == ["format.missing"])
        #expect(report.summary.richKeysRequiringSpecialHandling == ["substitution.missing", "variation.missing"])
        #expect(report.unsafeToWriteKeys.map(\.key) == ["brand.name", "substitution.missing", "variation.missing"])
    }

    @Test("PreflightLocaleHandler returns compact planning summary")
    func preflightLocaleHandlerCompact() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.preflightMixedCatalog)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = PreflightLocaleHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "language": .string("es"),
            "compact": .bool(true),
        ]))

        let result = try await handler.execute(with: context)
        let report = try decodeJSON(result, as: PreflightCompactReport.self)

        #expect(report.summary.missingSimpleKeys == 2)
        #expect(report.summary.missingFormatKeys == 1)
        #expect(report.summary.missingRichKeys == 2)
        #expect(report.safeKeys == ["plain.missing", "stale.missing"])
        #expect(report.formatSensitiveKeys == ["format.missing"])
        #expect(report.richOrUnsafeKeys == ["brand.name", "substitution.missing", "variation.missing"])
    }

    @Test("ValidateCatalogHandler returns structured catalog report")
    func validateCatalogHandler() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.preflightMixedCatalog)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = ValidateCatalogHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path)
        ]))

        let result = try await handler.execute(with: context)
        let report = try decodeJSON(result, as: CatalogValidationReport.self)

        #expect(report.success)
        #expect(report.jsonParseable)
        #expect(report.modelDecodable)
        #expect(report.richRecordReport?.richLocalizationCount == 2)
    }

    @Test("ValidateCatalogHandler returns compact validation summary")
    func validateCatalogHandlerCompact() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithBrokenFormatTranslation)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = ValidateCatalogHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "compact": .bool(true),
        ]))

        let result = try await handler.execute(with: context)
        let report = try decodeJSON(result, as: CatalogValidationCompactReport.self)

        #expect(report.success == false)
        #expect(report.summary.invalidPlaceholderValidationCount == 1)
        #expect(report.summary.errorCount == 1)
        #expect(report.compileValidationStatus == .notRequested)
        #expect(report.issues.map(\.code) == ["placeholder_mismatch"])
        #expect(report.issues.first?.key == "format.bad")
    }

    @Test("ValidatePlaceholdersHandler reports invalid translated placeholders")
    func validatePlaceholdersHandler() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithBrokenFormatTranslation)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = ValidatePlaceholdersHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path)
        ]))

        let result = try await handler.execute(with: context)
        let report = try decodeJSON(result, as: PlaceholderValidationReport.self)

        #expect(!report.success)
        #expect(report.summary.invalidTranslations == 1)
        #expect(report.issues.first?.code == "placeholder_mismatch")
    }

    @Test("FindSuspiciousKeysHandler reports accidental keys")
    func findSuspiciousKeysHandler() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithSuspiciousKeys)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = FindSuspiciousKeysHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path)
        ]))

        let result = try await handler.execute(with: context)
        let report = try decodeJSON(result, as: SuspiciousKeysReport.self)

        #expect(!report.success)
        #expect(report.findings.map(\.key) == ["", "(%@)", "/"])
    }

    // MARK: - Get Handlers

    @Test("GetSourceLanguageHandler returns source language")
    func getSourceLanguageHandler() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.japaneseSource)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = GetSourceLanguageHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path)
        ]))

        let result = try await handler.execute(with: context)
        #expect(result == "ja")
    }

    @Test("GetKeyHandler returns translations for key")
    func getKeyHandler() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.singleKeyMultipleLangs)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = GetKeyHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "key": .string("Hello")
        ]))

        let result = try await handler.execute(with: context)
        let keyInfo: KeyInfo = try decodeJSON(result, as: KeyInfo.self)
        #expect(keyInfo.key == "Hello")
        #expect(keyInfo.languages == ["de", "en", "ja"])
        #expect(keyInfo.translations["ja"]?.value == "こんにちは")
        #expect(keyInfo.translations["de"]?.value == "Hallo")
    }

    @Test("GetKeyHandler returns metadata for non-translatable key")
    func getKeyHandlerNonTranslatable() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.withNonTranslatableKey)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = GetKeyHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "key": .string("BrandName")
        ]))

        let result = try await handler.execute(with: context)
        let keyInfo: KeyInfo = try decodeJSON(result, as: KeyInfo.self)

        #expect(keyInfo.comment == "Proper noun shown as-is in every locale")
        #expect(keyInfo.isCommentAutoGenerated == true)
        #expect(keyInfo.shouldTranslate == false)
        #expect(keyInfo.translations.isEmpty)
    }

    @Test("GetKeyHandler keeps metadata when requested language is absent")
    func getKeyHandlerMissingLanguage() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.withNonTranslatableKey)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = GetKeyHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "key": .string("BrandName"),
            "language": .string("ja")
        ]))

        let result = try await handler.execute(with: context)
        let keyInfo: KeyInfo = try decodeJSON(result, as: KeyInfo.self)

        #expect(keyInfo.key == "BrandName")
        #expect(keyInfo.shouldTranslate == false)
        #expect(keyInfo.languages.isEmpty)
        #expect(keyInfo.translations.isEmpty)
    }

    @Test("GetKeyHandler returns metadata when requested language is absent for translatable key")
    func getKeyHandlerMissingLanguageForTranslatableKey() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.withNonTranslatableKey)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = GetKeyHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "key": .string("Hello"),
            "language": .string("fr")
        ]))

        let result = try await handler.execute(with: context)
        let keyInfo: KeyInfo = try decodeJSON(result, as: KeyInfo.self)

        #expect(keyInfo.key == "Hello")
        #expect(keyInfo.comment == "Greeting")
        #expect(keyInfo.languages == ["en", "ja"])
        #expect(keyInfo.translations.isEmpty)
    }

    @Test("GetKeyHandler surfaces metadata and states from derived real-world sample")
    func getKeyHandlerRealWorldSample() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.realWorldSample)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = GetKeyHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "key": .string("This view now has a bit more to say.")
        ]))

        let result = try await handler.execute(with: context)
        let keyInfo: KeyInfo = try decodeJSON(result, as: KeyInfo.self)

        #expect(keyInfo.comment == "A description of the additional content in the `ContentView`.")
        #expect(keyInfo.isCommentAutoGenerated == true)
        #expect(keyInfo.languages == ["fr", "ja"])
        #expect(keyInfo.translations["fr"]?.value == "French placeholder translation")
        #expect(keyInfo.translations["ja"]?.state == "needs_review")
    }

    @Test("CheckKeyHandler returns true for existing key")
    func checkKeyHandlerExists() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.singleKeySingleLang)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = CheckKeyHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "key": .string("Hello")
        ]))

        let result = try await handler.execute(with: context)
        #expect(result == "true")
    }

    @Test("CheckKeyHandler returns false for non-existing key")
    func checkKeyHandlerNotExists() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.singleKeySingleLang)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = CheckKeyHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "key": .string("NonExistent")
        ]))

        let result = try await handler.execute(with: context)
        #expect(result == "false")
    }

    @Test("CheckKeyHandler uses actual localizations for non-translatable keys")
    func checkKeyHandlerNonTranslatableWithLanguage() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.withNonTranslatableKey)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = CheckKeyHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "key": .string("BrandName"),
            "language": .string("ja")
        ]))

        let result = try await handler.execute(with: context)
        #expect(result == "false")
    }

    @Test("CheckKeyHandler treats empty localization shells as missing")
    func checkKeyHandlerEmptyLocalizationShell() async throws {
        let path = try TestHelper.createTempFile(content: """
        {
          "sourceLanguage": "en",
          "strings": {
            "Hello": {
              "localizations": {
                "en": {
                  "stringUnit": {
                    "state": "translated",
                    "value": "Hello"
                  }
                },
                "ja": {}
              }
            }
          },
          "version": "1.0"
        }
        """)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = CheckKeyHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "key": .string("Hello"),
            "language": .string("ja")
        ]))

        let result = try await handler.execute(with: context)
        #expect(result == "false")
    }

    // MARK: - Stats Handlers

    @Test("StatsCoverageHandler returns coverage stats")
    func statsCoverageHandler() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.manyKeys)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = StatsCoverageHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "compact": .bool(false)
        ]))

        let result = try await handler.execute(with: context)
        let stats: StatsInfo = try decodeJSON(result, as: StatsInfo.self)
        let jaStats = try #require(stats.coverageByLanguage["ja"])

        #expect(stats.totalKeys == 10)
        #expect(jaStats.translated == 3)
        #expect(jaStats.coverage.state == .measured)
        #expect(jaStats.coverage.percent == 30.0)
    }

    @Test("StatsProgressHandler returns progress for language")
    func statsProgressHandler() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.manyKeys)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = StatsProgressHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "language": .string("ja")
        ]))

        let result = try await handler.execute(with: context)
        let progress: LanguageStats = try decodeJSON(result, as: LanguageStats.self)

        #expect(progress.translated == 3)
        #expect(progress.total == 10)
        #expect(progress.coverage.state == .measured)
        #expect(progress.coverage.percent == 30.0)
    }

    @Test("StatsCoverageHandler surfaces notApplicable coverage for empty files")
    func statsCoverageHandlerEmptyFile() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.empty)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = StatsCoverageHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "compact": .bool(false)
        ]))

        let result = try await handler.execute(with: context)
        let stats: StatsInfo = try decodeJSON(result, as: StatsInfo.self)
        let enStats = try #require(stats.coverageByLanguage["en"])

        #expect(enStats.total == 0)
        #expect(enStats.coverage.state == .notApplicable)
        #expect(enStats.coverage.percent == nil)
    }

    @Test("StatsCoverageHandler defaults to compact tri-state summaries")
    func statsCoverageHandlerDefaultCompact() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.empty)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = StatsCoverageHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path)
        ]))

        let result = try await handler.execute(with: context)
        let compactStats: CompactStatsInfo = try decodeJSON(result, as: CompactStatsInfo.self)

        #expect(compactStats.completionState == .notApplicable)
        #expect(compactStats.notApplicableLanguages == ["en"])
    }

    // MARK: - Create Handlers

    @Test("CreateFileHandler creates new file")
    func createFileHandler() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let path = tempDir.appendingPathComponent("create_test_\(UUID().uuidString).xcstrings").path
        defer { TestHelper.removeTempFile(at: path) }

        let handler = CreateFileHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "sourceLanguage": .string("ja")
        ]))

        let result = try await handler.execute(with: context)
        #expect(result.contains("Created"))
        #expect(FileManager.default.fileExists(atPath: path))
    }

    // MARK: - Write Handlers

    @Test("AddTranslationHandler adds translation")
    func addTranslationHandler() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.singleKeySingleLang)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = AddTranslationHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "key": .string("NewKey"),
            "language": .string("ja"),
            "value": .string("新しいキー")
        ]))

        let result = try await handler.execute(with: context)
        let response = try decodeJSON(result, as: MCPWriteResponse.self)
        #expect(response.success)
        #expect(response.file == path)
        #expect(response.operationType == .addTranslation)
        #expect(response.key == "NewKey")
        #expect(response.languages == ["ja"])
        #expect(response.fileChanged)
        #expect(response.insertedCount == 1)
        #expect(response.updatedCount == 0)
        #expect(response.entries.count == 1)
        #expect(response.entries[0].action == .inserted)
        #expect(response.entries[0].previousState == nil)
        #expect(response.entries[0].finalState?.value == "新しいキー")

        // Verify the translation was added
        let parser = XCStringsParser(path: path)
        let translation = try await parser.getTranslation(key: "NewKey", language: "ja")
        #expect(translation["ja"]?.value == "新しいキー")
    }

    @Test("AddTranslationsHandler returns structured response for multiple languages")
    func addTranslationsHandler() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.singleKeySingleLang)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = AddTranslationsHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "key": .string("Goodbye"),
            "translations": .object([
                "de": .string("Auf Wiedersehen"),
                "ja": .string("さようなら"),
            ])
        ]))

        let result = try await handler.execute(with: context)
        let response = try decodeJSON(result, as: MCPWriteResponse.self)

        #expect(response.success)
        #expect(response.operationType == .addTranslations)
        #expect(response.key == "Goodbye")
        #expect(response.languages == ["de", "ja"])
        #expect(response.insertedCount == 2)
        #expect(response.entries.allSatisfy { $0.action == .inserted && $0.previousState == nil })
        #expect(response.entries.first { $0.language == "ja" }?.finalState?.value == "さようなら")
    }

    @Test("UpdateTranslationHandler updates translation")
    func updateTranslationHandler() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.singleKeySingleLang)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = UpdateTranslationHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "key": .string("Hello"),
            "language": .string("en"),
            "value": .string("Hi there")
        ]))

        let result = try await handler.execute(with: context)
        let response = try decodeJSON(result, as: MCPWriteResponse.self)
        #expect(response.success)
        #expect(response.file == path)
        #expect(response.operationType == .updateTranslation)
        #expect(response.key == "Hello")
        #expect(response.languages == ["en"])
        #expect(response.fileChanged)
        #expect(response.insertedCount == 0)
        #expect(response.updatedCount == 1)
        #expect(response.entries[0].action == .updated)
        #expect(response.entries[0].previousState?.value == "Hello")
        #expect(response.entries[0].finalState?.value == "Hi there")

        // Verify the translation was updated
        let parser = XCStringsParser(path: path)
        let translation = try await parser.getTranslation(key: "Hello", language: "en")
        #expect(translation["en"]?.value == "Hi there")
    }

    @Test("UpdateTranslationsHandler returns structured response for multiple languages")
    func updateTranslationsHandler() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.singleKeyMultipleLangs)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = UpdateTranslationsHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "key": .string("Hello"),
            "translations": .object([
                "de": .string("Guten Tag"),
                "ja": .string("やあ"),
            ])
        ]))

        let result = try await handler.execute(with: context)
        let response = try decodeJSON(result, as: MCPWriteResponse.self)

        #expect(response.success)
        #expect(response.operationType == .updateTranslations)
        #expect(response.languages == ["de", "ja"])
        #expect(response.updatedCount == 2)
        #expect(response.entries.first { $0.language == "de" }?.previousState?.value == "Hallo")
        #expect(response.entries.first { $0.language == "de" }?.finalState?.value == "Guten Tag")
        #expect(response.entries.first { $0.language == "ja" }?.previousState?.value == "こんにちは")
        #expect(response.entries.first { $0.language == "ja" }?.finalState?.value == "やあ")
    }

    @Test("RenameKeyHandler renames key")
    func renameKeyHandler() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.singleKeySingleLang)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = RenameKeyHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "oldKey": .string("Hello"),
            "newKey": .string("Greeting")
        ]))

        let result = try await handler.execute(with: context)
        let response = try decodeJSON(result, as: MCPWriteResponse.self)
        #expect(response.success)
        #expect(response.operationType == .renameKey)
        #expect(response.fileChanged)
        #expect(response.renamedCount == 1)
        #expect(response.entries[0].previousKey == "Hello")
        #expect(response.entries[0].finalKey == "Greeting")

        // Verify the key was renamed
        let parser = XCStringsParser(path: path)
        let oldExists = try await parser.checkKey("Hello", language: nil)
        let newExists = try await parser.checkKey("Greeting", language: nil)
        #expect(!oldExists)
        #expect(newExists)
    }

    // MARK: - Delete Handlers

    @Test("DeleteKeyHandler deletes key")
    func deleteKeyHandler() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.multipleKeysPartialTranslations)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = DeleteKeyHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "key": .string("Hello")
        ]))

        let result = try await handler.execute(with: context)
        let response = try decodeJSON(result, as: MCPWriteResponse.self)
        #expect(response.success)
        #expect(response.operationType == .deleteKey)
        #expect(response.fileChanged)
        #expect(response.deletedCount == 1)
        #expect(response.entries[0].key == "Hello")
        #expect(response.entries[0].action == .deleted)

        // Verify the key was deleted
        let parser = XCStringsParser(path: path)
        let exists = try await parser.checkKey("Hello", language: nil)
        #expect(!exists)
    }

    @Test("DeleteTranslationHandler deletes translation")
    func deleteTranslationHandler() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.singleKeyMultipleLangs)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = DeleteTranslationHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "key": .string("Hello"),
            "language": .string("ja")
        ]))

        let result = try await handler.execute(with: context)
        let response = try decodeJSON(result, as: MCPWriteResponse.self)
        #expect(response.success)
        #expect(response.operationType == .deleteTranslation)
        #expect(response.fileChanged)
        #expect(response.deletedCount == 1)
        #expect(response.languages == ["ja"])
        #expect(response.entries[0].previousState?.value == "こんにちは")
        #expect(response.entries[0].finalState == nil)

        // Verify the translation was deleted
        let parser = XCStringsParser(path: path)
        let exists = try await parser.checkKey("Hello", language: "ja")
        #expect(!exists)
    }

    // MARK: - Batch Handlers

    @Test("BatchCheckKeysHandler checks multiple keys")
    func batchCheckKeysHandler() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.multipleKeysPartialTranslations)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = BatchCheckKeysHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "keys": .array([.string("Hello"), .string("Goodbye"), .string("NonExistent")])
        ]))

        let result = try await handler.execute(with: context)
        #expect(result.contains("existingKeys"))
        #expect(result.contains("missingKeys"))
        #expect(result.contains("NonExistent"))
    }

    @Test("BatchAddTranslationsHandler adds multiple translations")
    func batchAddTranslationsHandler() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.empty)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = BatchAddTranslationsHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "entries": .array([
                .object([
                    "key": .string("Hello"),
                    "translations": .object([
                        "ja": .string("こんにちは"),
                        "en": .string("Hello")
                    ])
                ]),
                .object([
                    "key": .string("Goodbye"),
                    "translations": .object([
                        "ja": .string("さようなら")
                    ])
                ])
            ])
        ]))

        let result = try await handler.execute(with: context)
        let response = try decodeJSON(result, as: MCPWriteResponse.self)
        #expect(response.success)
        #expect(response.operationType == .batchAddTranslations)
        #expect(response.file == path)
        #expect(response.fileChanged)
        #expect(response.insertedCount == 3)
        #expect(response.batchResult?.successCount == 2)
        #expect(response.entries.contains { $0.key == "Hello" && $0.language == "ja" && $0.action == .inserted })
        #expect(response.entries.contains { $0.key == "Goodbye" && $0.language == "ja" && $0.action == .inserted })

        // Verify translations were added
        let parser = XCStringsParser(path: path)
        let keys = try await parser.listKeys()
        #expect(keys.contains("Hello"))
        #expect(keys.contains("Goodbye"))
    }

    @Test("BatchAddTranslationsHandler preserves duplicate mixed outcome entries")
    func batchAddTranslationsHandlerDuplicateMixedOutcomes() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.empty)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = BatchAddTranslationsHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "entries": .array([
                .object([
                    "key": .string("NewKey"),
                    "translations": .object([
                        "en": .string("First value")
                    ])
                ]),
                .object([
                    "key": .string("NewKey"),
                    "translations": .object([
                        "en": .string("Second value")
                    ])
                ])
            ])
        ]))

        let result = try await handler.execute(with: context)
        let response = try decodeJSON(result, as: MCPWriteResponse.self)

        #expect(!response.success)
        #expect(response.insertedCount == 1)
        #expect(response.failedCount == 1)
        #expect(response.entries.compactMap(\.inputIndex) == [0, 1])
        #expect(response.entries.map(\.key) == ["NewKey", "NewKey"])
        #expect(response.entries.map(\.action) == [.inserted, .failed])
        #expect(response.entries[1].diagnostics.first?.contains("Key already exists") == true)
        let batchResult = try #require(response.batchResult)
        #expect(batchResult.entryResults.map(\.inputIndex) == [0, 1])
        #expect(batchResult.entryResults.map(\.status) == [.succeeded, .failed])
    }

    @Test("BatchAddTranslationsHandler reports per-entry state for duplicate overwrites")
    func batchAddTranslationsHandlerDuplicateOverwriteStateSnapshots() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.empty)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = BatchAddTranslationsHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "overwrite": .bool(true),
            "entries": .array([
                .object([
                    "key": .string("NewKey"),
                    "translations": .object([
                        "en": .string("First value")
                    ])
                ]),
                .object([
                    "key": .string("NewKey"),
                    "translations": .object([
                        "en": .string("Second value")
                    ])
                ])
            ])
        ]))

        let result = try await handler.execute(with: context)
        let response = try decodeJSON(result, as: MCPWriteResponse.self)

        #expect(response.success)
        #expect(response.insertedCount == 1)
        #expect(response.updatedCount == 1)
        #expect(response.failedCount == 0)
        #expect(response.entries.compactMap(\.inputIndex) == [0, 1])
        #expect(response.entries.map(\.action) == [.inserted, .updated])
        #expect(response.entries[0].previousState == nil)
        #expect(response.entries[0].finalState?.value == "First value")
        #expect(response.entries[1].previousState?.value == "First value")
        #expect(response.entries[1].finalState?.value == "Second value")

        let batchResult = try #require(response.batchResult)
        #expect(batchResult.entryResults[0].languageResults.first?.finalState?.value == "First value")
        #expect(batchResult.entryResults[1].languageResults.first?.previousState?.value == "First value")
    }

    @Test("BatchUpdateTranslationsHandler preserves duplicate failed entries")
    func batchUpdateTranslationsHandlerDuplicateFailures() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.singleKeySingleLang)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = BatchUpdateTranslationsHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "entries": .array([
                .object([
                    "key": .string("MissingKey"),
                    "translations": .object([
                        "ja": .string("Value A")
                    ])
                ]),
                .object([
                    "key": .string("MissingKey"),
                    "translations": .object([
                        "fr": .string("Value B")
                    ])
                ])
            ])
        ]))

        let result = try await handler.execute(with: context)
        let response = try decodeJSON(result, as: MCPWriteResponse.self)

        #expect(!response.success)
        #expect(response.failedCount == 2)
        #expect(response.entries.compactMap(\.inputIndex) == [0, 1])
        #expect(response.entries.map(\.key) == ["MissingKey", "MissingKey"])
        #expect(response.entries.allSatisfy { $0.action == .failed })
        let batchResult = try #require(response.batchResult)
        #expect(batchResult.entryResults.map(\.inputIndex) == [0, 1])
        #expect(batchResult.entryResults.map(\.status) == [.failed, .failed])
    }

    @Test("SupplementLocaleHandler returns atomic supplement result")
    func supplementLocaleHandler() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.multipleKeysPartialTranslations)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = SupplementLocaleHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "language": .string("ja"),
            "translations": .object([
                "Goodbye": .string("さようなら"),
                "Hello": .string("こんにちは"),
            ]),
            "dryRun": .bool(true),
        ]))

        let result = try await handler.execute(with: context)
        let supplement = try decodeJSON(result, as: LocaleSupplementResult.self)

        #expect(supplement.status == .dryRun)
        #expect(supplement.success)
        #expect(supplement.fileChanged == false)
        #expect(supplement.wouldWrite)
        #expect(supplement.compileValidationRanOnProjectedCatalog == false)
        #expect(supplement.counts.inserted == 1)
        #expect(supplement.counts.unchanged == 1)
    }

    @Test("SupplementLocaleHandler skips dry-run compile validation for blocked atomic plans")
    func supplementLocaleHandlerDryRunCompileValidationSkipsBlockedPlan() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogForSupplementBlocking)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = SupplementLocaleHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "language": .string("es"),
            "translations": .object([
                "sample.action.import": .string("Importar"),
                "sample.library.itemAccessibilityLabel": .string("Elemento sin dimensiones"),
            ]),
            "dryRun": .bool(true),
            "validateCompile": .bool(true),
        ]))

        let result = try await handler.execute(with: context)
        let supplement = try decodeJSON(result, as: LocaleSupplementResult.self)

        #expect(supplement.status == .dryRun)
        #expect(supplement.success == false)
        #expect(supplement.fileChanged == false)
        #expect(supplement.wouldWrite == false)
        #expect(supplement.counts.inserted == 1)
        #expect(supplement.counts.unsafe == 1)
        #expect(supplement.compileValidation.status == .notRunDueToBlockingDiagnostics)
        #expect(supplement.compileValidationRanOnProjectedCatalog == false)
    }

    @Test("SupplementLocaleHandler returns compact supplement summary")
    func supplementLocaleHandlerCompact() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.multipleKeysPartialTranslations)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = SupplementLocaleHandler()
        let context = ToolContext(arguments: ToolArguments(raw: [
            "file": .string(path),
            "language": .string("ja"),
            "translations": .object([
                "Goodbye": .string("さようなら"),
                "Hello": .string("こんにちは"),
            ]),
            "dryRun": .bool(true),
            "compact": .bool(true),
        ]))

        let result = try await handler.execute(with: context)
        let supplement = try decodeJSON(result, as: LocaleSupplementCompactResult.self)

        #expect(supplement.status == .dryRun)
        #expect(supplement.fileChanged == false)
        #expect(supplement.wouldWrite)
        #expect(supplement.compileValidationRanOnProjectedCatalog == false)
        #expect(supplement.counts.inserted == 1)
        #expect(supplement.counts.unchanged == 1)
        #expect(supplement.placeholderValidation.checked == 0)
        #expect(supplement.compileValidationStatus == .notRequested)
        #expect(supplement.remainingUntranslatedCount == 0)
    }

    private static let catalogForSupplementBlocking = """
    {
      "sourceLanguage": "en",
      "strings": {
        "sample.action.import": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "Import"
              }
            }
          }
        },
        "sample.library.itemAccessibilityLabel": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "Item, %1$@, %2$lld by %3$lld pixels"
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private static let catalogWithBrokenFormatTranslation = """
    {
      "sourceLanguage": "en",
      "strings": {
        "format.bad": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "Item %@ has %lld matches"
              }
            },
            "es": {
              "stringUnit": {
                "state": "translated",
                "value": "Elemento %@"
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private static let catalogWithSuspiciousKeys = """
    {
      "sourceLanguage": "en",
      "strings": {
        "": {},
        "(%@)": {},
        "/": {},
        "normal.key": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "Normal"
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private func decodeJSON<T: Decodable>(_ string: String, as type: T.Type) throws -> T {
        let data = try #require(string.data(using: .utf8))
        return try JSONDecoder().decode(T.self, from: data)
    }
}
