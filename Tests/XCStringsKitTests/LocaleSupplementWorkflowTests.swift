import Foundation
import Testing
@testable import XCStringsKit

@Suite("Atomic locale supplement workflow")
struct LocaleSupplementWorkflowTests {
    @Test("supplementLocale dry run returns a plan without writing")
    func supplementLocaleDryRunPlansWithoutWriting() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.catalogPersistenceRegression)
        defer { TestHelper.removeTempFile(at: path) }
        let original = try String(contentsOfFile: path, encoding: .utf8)

        let parser = XCStringsParser(path: path)
        let result = try await parser.supplementLocale(
            language: "es",
            translations: [
                "sample.action.import": "Importar",
                "sample.library.itemAccessibilityLabel": "Elemento, %1$@, %2$lld por %3$lld pixeles",
            ],
            dryRun: true
        )

        #expect(result.status == .dryRun)
        #expect(result.success)
        #expect(result.fileChanged == false)
        #expect(result.wouldWrite)
        #expect(result.compileValidation.status == .notRequested)
        #expect(result.compileValidationRanOnProjectedCatalog == false)
        #expect(result.counts.inserted == 2)
        #expect(result.counts.unsafe == 0)
        #expect(result.placeholderValidations.count == 1)
        #expect(result.placeholderValidations[0].isValid)
        #expect(result.plan.entries.map(\.action) == [.insert, .insert])
        #expect(try String(contentsOfFile: path, encoding: .utf8) == original)
    }

    @Test("supplementLocale dry-run compile validation preserves the real file")
    func supplementLocaleDryRunCompileValidationPreservesFile() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.catalogPersistenceRegression)
        defer { TestHelper.removeTempFile(at: path) }
        let originalData = try Data(contentsOf: URL(fileURLWithPath: path))
        let originalHash = try fileHash(at: path)

        let parser = XCStringsParser(path: path)
        let validator: LocaleSupplementCompileValidator = { file, language in
            let projectedValue = file.strings["sample.action.import"]?
                .localizations?[language]?
                .stringUnit?
                .value
            guard projectedValue == "Importar" else {
                return LocaleSupplementCompileValidation(
                    status: .failed,
                    diagnostics: "Projected catalog did not include the proposed translation."
                )
            }
            return LocaleSupplementCompileValidation(
                status: .passed,
                command: ["test-validator"]
            )
        }

        let result = try await parser.supplementLocale(
            language: "es",
            translations: ["sample.action.import": "Importar"],
            dryRun: true,
            validateCompile: true,
            compileValidator: validator
        )

        #expect(result.status == .dryRun)
        #expect(result.success)
        #expect(result.fileChanged == false)
        #expect(result.wouldWrite)
        #expect(result.compileValidation.status == .passed)
        #expect(result.compileValidationRanOnProjectedCatalog)
        #expect(try fileHash(at: path) == originalHash)
        #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == originalData)
        #expect(try await parser.checkKey("sample.action.import", language: "es") == false)
    }

    @Test("supplementLocale dry-run compile validation reports projected compile failures")
    func supplementLocaleDryRunCompileValidationReportsFailure() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.catalogPersistenceRegression)
        defer { TestHelper.removeTempFile(at: path) }
        let originalData = try Data(contentsOf: URL(fileURLWithPath: path))

        let parser = XCStringsParser(path: path)
        let validator: LocaleSupplementCompileValidator = { _, _ in
            LocaleSupplementCompileValidation(
                status: .failed,
                command: ["test-validator"],
                diagnostics: "Projected catalog failed compile validation."
            )
        }

        let result = try await parser.supplementLocale(
            language: "es",
            translations: ["sample.action.import": "Importar"],
            dryRun: true,
            validateCompile: true,
            compileValidator: validator
        )

        #expect(result.status == .dryRun)
        #expect(result.success == false)
        #expect(result.fileChanged == false)
        #expect(result.wouldWrite)
        #expect(result.compileValidation.status == .failed)
        #expect(result.compileValidationRanOnProjectedCatalog)
        #expect(result.compileValidation.diagnostics == "Projected catalog failed compile validation.")
        #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == originalData)
    }

    @Test("supplementLocale dry-run compile validation skips blocked atomic plans")
    func supplementLocaleDryRunCompileValidationSkipsBlockedPlan() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.catalogPersistenceRegression)
        defer { TestHelper.removeTempFile(at: path) }
        let originalData = try Data(contentsOf: URL(fileURLWithPath: path))

        let parser = XCStringsParser(path: path)
        let validator: LocaleSupplementCompileValidator = { _, _ in
            LocaleSupplementCompileValidation(
                status: .failed,
                diagnostics: "The validator should not run for a blocked atomic dry run."
            )
        }

        let result = try await parser.supplementLocale(
            language: "es",
            translations: [
                "sample.action.import": "Importar",
                "sample.library.itemAccessibilityLabel": "Elemento sin dimensiones",
            ],
            dryRun: true,
            validateCompile: true,
            compileValidator: validator
        )

        #expect(result.status == .dryRun)
        #expect(result.success == false)
        #expect(result.fileChanged == false)
        #expect(result.wouldWrite == false)
        #expect(result.counts.inserted == 1)
        #expect(result.counts.unsafe == 1)
        #expect(result.compileValidation.status == .notRunDueToBlockingDiagnostics)
        #expect(result.compileValidationRanOnProjectedCatalog == false)
        #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == originalData)
    }

    @Test("supplementLocale dry-run compile validation projects partial writes when allowed")
    func supplementLocaleDryRunCompileValidationProjectsPartialWrites() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.catalogPersistenceRegression)
        defer { TestHelper.removeTempFile(at: path) }
        let originalData = try Data(contentsOf: URL(fileURLWithPath: path))

        let parser = XCStringsParser(path: path)
        let validator: LocaleSupplementCompileValidator = { file, language in
            let validValue = file.strings["sample.action.import"]?
                .localizations?[language]?
                .stringUnit?
                .value
            let unsafeLocalization = file.strings["sample.library.itemAccessibilityLabel"]?
                .localizations?[language]
            guard validValue == "Importar", unsafeLocalization == nil else {
                return LocaleSupplementCompileValidation(
                    status: .failed,
                    diagnostics: "Projected partial catalog did not contain exactly the valid writes."
                )
            }
            return LocaleSupplementCompileValidation(status: .passed, command: ["test-validator"])
        }

        let result = try await parser.supplementLocale(
            language: "es",
            translations: [
                "sample.action.import": "Importar",
                "sample.library.itemAccessibilityLabel": "Elemento sin dimensiones",
            ],
            dryRun: true,
            allowPartial: true,
            validateCompile: true,
            compileValidator: validator
        )

        #expect(result.status == .dryRun)
        #expect(result.success)
        #expect(result.fileChanged == false)
        #expect(result.wouldWrite)
        #expect(result.counts.inserted == 1)
        #expect(result.counts.unsafe == 1)
        #expect(result.compileValidation.status == .passed)
        #expect(result.compileValidationRanOnProjectedCatalog)
        #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == originalData)
    }

    @Test("supplementLocale dry-run compile validation runs xcstringstool when available")
    func supplementLocaleDryRunCompileValidationRunsXCStringsTool() async throws {
        guard xcstringstoolIsAvailable() else {
            return
        }

        let path = try TestHelper.createTempFile(content: TestFixtures.catalogPersistenceRegression)
        defer { TestHelper.removeTempFile(at: path) }
        let originalData = try Data(contentsOf: URL(fileURLWithPath: path))

        let parser = XCStringsParser(path: path)
        let result = try await parser.supplementLocale(
            language: "es",
            translations: [
                "sample.action.import": "Importar",
                "sample.library.itemAccessibilityLabel": "Elemento, %1$@, %2$lld por %3$lld pixeles",
            ],
            dryRun: true,
            validateCompile: true
        )

        #expect(result.status == .dryRun)
        #expect(result.success)
        #expect(result.fileChanged == false)
        #expect(result.wouldWrite)
        #expect(result.compileValidation.status == .passed)
        #expect(result.compileValidationRanOnProjectedCatalog)
        #expect(result.compileValidation.command.contains("--dry-run"))
        #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == originalData)
    }

    @Test("compact supplement result reports counts validation and projected remaining keys")
    func compactSupplementResultReportsDecisionSummary() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.multipleKeysPartialTranslations)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let result = try await parser.supplementLocale(
            language: "ja",
            translations: [
                "Goodbye": "さようなら",
                "Hello": "こんにちは",
            ],
            dryRun: true
        )
        let currentUntranslated = try await parser.listUntranslated(for: "ja")
        let compact = result.compact(
            remainingUntranslatedKeys: result.projectedRemainingUntranslatedKeys(
                currentUntranslatedKeys: currentUntranslated
            )
        )

        #expect(compact.status == .dryRun)
        #expect(compact.success)
        #expect(compact.fileChanged == false)
        #expect(compact.wouldWrite)
        #expect(compact.compileValidationRanOnProjectedCatalog == false)
        #expect(compact.targetLanguage == "ja")
        #expect(compact.counts.inserted == 1)
        #expect(compact.counts.unchanged == 1)
        #expect(compact.placeholderValidation.checked == 0)
        #expect(compact.placeholderValidation.failed == 0)
        #expect(compact.compileValidationStatus == .notRequested)
        #expect(compact.remainingUntranslatedCount == 0)
        #expect(compact.remainingUntranslatedKeys == [])
    }

    @Test("supplementLocale refuses partial writes by default")
    func supplementLocaleRefusesPartialWritesByDefault() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.catalogPersistenceRegression)
        defer { TestHelper.removeTempFile(at: path) }
        let original = try String(contentsOfFile: path, encoding: .utf8)

        let parser = XCStringsParser(path: path)
        let result = try await parser.supplementLocale(
            language: "es",
            translations: [
                "sample.action.import": "Importar",
                "sample.library.itemAccessibilityLabel": "Elemento sin dimensiones",
            ]
        )

        #expect(result.status == .refused)
        #expect(result.success == false)
        #expect(result.wouldWrite == false)
        #expect(result.fileChanged == false)
        #expect(result.counts.inserted == 1)
        #expect(result.counts.unsafe == 1)
        #expect(result.placeholderValidations.count == 1)
        #expect(result.placeholderValidations[0].diagnostics.contains { $0.contains("missing required format placeholders") })
        #expect(try String(contentsOfFile: path, encoding: .utf8) == original)
        #expect(try await parser.checkKey("sample.action.import", language: "es") == false)
    }

    @Test("supplementLocale writes only valid entries when partial writes are explicit")
    func supplementLocaleAllowsExplicitPartialWrites() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.catalogPersistenceRegression)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let result = try await parser.supplementLocale(
            language: "es",
            translations: [
                "sample.action.import": "Importar",
                "sample.library.itemAccessibilityLabel": "Elemento sin dimensiones",
            ],
            allowPartial: true
        )

        #expect(result.status == .partialWritten)
        #expect(result.wouldWrite)
        #expect(result.fileChanged)
        #expect(result.counts.inserted == 1)
        #expect(result.counts.unsafe == 1)
        #expect(result.plan.entries.first { $0.key == "sample.action.import" }?.action == .insert)
        #expect(result.plan.entries.first { $0.key == "sample.library.itemAccessibilityLabel" }?.action == .unsafe)

        let inserted = try await parser.getTranslation(key: "sample.action.import", language: "es")
        #expect(inserted["es"]?.value == "Importar")
        #expect(try await parser.checkKey("sample.library.itemAccessibilityLabel", language: "es") == false)
    }

    @Test("supplementLocale distinguishes unchanged skipped and updated entries")
    func supplementLocaleHandlesExistingTranslations() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.multipleKeysPartialTranslations)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let initial = try await parser.supplementLocale(
            language: "ja",
            translations: [
                "Goodbye": "さようなら",
                "Hello": "こんにちは",
            ]
        )

        #expect(initial.status == .written)
        #expect(initial.counts.inserted == 1)
        #expect(initial.counts.unchanged == 1)

        let skipped = try await parser.supplementLocale(
            language: "ja",
            translations: ["Hello": "やあ"]
        )

        #expect(skipped.status == .unchanged)
        #expect(skipped.counts.skipped == 1)
        #expect(skipped.fileChanged == false)

        let updated = try await parser.supplementLocale(
            language: "ja",
            translations: ["Hello": "やあ"],
            overwrite: true
        )

        #expect(updated.status == .written)
        #expect(updated.counts.updated == 1)

        let hello = try await parser.getTranslation(key: "Hello", language: "ja")
        #expect(hello["ja"]?.value == "やあ")
    }

    @Test("supplementLocale reports missing keys as failed and preserves the file")
    func supplementLocaleReportsMissingKeysAsFailed() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.singleKeySingleLang)
        defer { TestHelper.removeTempFile(at: path) }
        let original = try String(contentsOfFile: path, encoding: .utf8)

        let parser = XCStringsParser(path: path)
        let result = try await parser.supplementLocale(
            language: "es",
            translations: [
                "Hello": "Hola",
                "Missing": "Falta",
            ]
        )

        #expect(result.status == .refused)
        #expect(result.success == false)
        #expect(result.wouldWrite == false)
        #expect(result.counts.inserted == 1)
        #expect(result.counts.failed == 1)
        #expect(result.plan.entries.first { $0.key == "Missing" }?.diagnostics == ["Key not found in catalog."])
        #expect(try String(contentsOfFile: path, encoding: .utf8) == original)
    }

    private func xcstringstoolIsAvailable() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["--find", "xcstringstool"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func fileHash(at path: String) throws -> UInt64 {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return data.reduce(UInt64(0xcbf29ce484222325)) { hash, byte in
            (hash ^ UInt64(byte)) &* UInt64(0x100000001b3)
        }
    }
}
