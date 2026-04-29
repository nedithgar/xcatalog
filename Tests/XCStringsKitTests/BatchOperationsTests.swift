import Foundation
import Testing
@testable import XCStringsKit

@Suite("Batch operations for checking, adding, and updating multiple keys at once")
struct BatchOperationsTests {
    // MARK: - Test Cases

    struct CheckKeysTestCase: Sendable {
        let fixture: FixtureType
        let keys: [String]
        let language: String?
        let expectedExisting: [String]
        let expectedMissing: [String]

        static let allCases: [CheckKeysTestCase] = [
            CheckKeysTestCase(
                fixture: .multipleKeysPartialTranslations,
                keys: ["Hello", "Goodbye", "Welcome", "NonExistent"],
                language: nil,
                expectedExisting: ["Goodbye", "Hello", "Welcome"],
                expectedMissing: ["NonExistent"]
            ),
            CheckKeysTestCase(
                fixture: .multipleKeysPartialTranslations,
                keys: ["Hello", "Goodbye", "Welcome"],
                language: "ja",
                expectedExisting: ["Hello", "Welcome"],
                expectedMissing: ["Goodbye"]
            ),
            CheckKeysTestCase(
                fixture: .multipleKeysPartialTranslations,
                keys: ["Hello", "Goodbye", "Welcome"],
                language: "de",
                expectedExisting: ["Welcome"],
                expectedMissing: ["Goodbye", "Hello"]
            ),
            CheckKeysTestCase(
                fixture: .singleKeySingleLang,
                keys: [],
                language: nil,
                expectedExisting: [],
                expectedMissing: []
            ),
            CheckKeysTestCase(
                fixture: .withLocaleOnlyOnNonTranslatableKey,
                keys: ["BrandName", "Hello"],
                language: "ja",
                expectedExisting: ["BrandName"],
                expectedMissing: ["Hello"]
            ),
        ]
    }

    struct BatchAddTestCase: Sendable {
        let fixture: FixtureType
        let allowOverwrite: Bool
        let expectedSuccess: Int
        let expectedFailed: Int
        let expectedSucceeded: [String]
        let expectedFailedKeys: [String]

        static let allCases: [BatchAddTestCase] = [
            BatchAddTestCase(
                fixture: .singleKeySingleLang,
                allowOverwrite: false,
                expectedSuccess: 1,
                expectedFailed: 1,
                expectedSucceeded: ["NewKey"],
                expectedFailedKeys: ["Hello"]
            ),
            BatchAddTestCase(
                fixture: .singleKeySingleLang,
                allowOverwrite: true,
                expectedSuccess: 2,
                expectedFailed: 0,
                expectedSucceeded: ["Hello", "NewKey"],
                expectedFailedKeys: []
            ),
        ]
    }

    struct BatchUpdateFailureTestCase: Sendable {
        let fixture: FixtureType
        let key: String
        let translations: [String: String]
        let expectedFailedKey: String

        static let allCases: [BatchUpdateFailureTestCase] = [
            BatchUpdateFailureTestCase(
                fixture: .singleKeySingleLang,
                key: "NonExistent",
                translations: ["en": "Value"],
                expectedFailedKey: "NonExistent"
            ),
            BatchUpdateFailureTestCase(
                fixture: .singleKeySingleLang,
                key: "Hello",
                translations: ["fr": "Bonjour"],
                expectedFailedKey: "Hello"
            ),
        ]
    }

    // MARK: - Check Keys Tests

    @Test("checkKeys returns correct results for multiple keys", arguments: CheckKeysTestCase.allCases)
    func checkKeysMultiple(testCase: CheckKeysTestCase) async throws {
        let path = try TestHelper.createTempFile(content: testCase.fixture.content)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let result = try await parser.checkKeys(testCase.keys, language: testCase.language)

        #expect(result.existingKeys == testCase.expectedExisting)
        #expect(result.missingKeys == testCase.expectedMissing)
    }

    // MARK: - Batch Add Translations Tests

    @Test("addTranslationsBatch adds multiple keys successfully")
    func addTranslationsBatchMultipleKeys() async throws {
        let path = try TestHelper.createTempFile(content: FixtureType.empty.content)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let entries = [
            BatchTranslationEntry(key: "Hello", translations: ["en": "Hello", "ja": "こんにちは"]),
            BatchTranslationEntry(key: "Goodbye", translations: ["en": "Goodbye", "ja": "さようなら"]),
            BatchTranslationEntry(key: "Thanks", translations: ["en": "Thanks"]),
        ]

        let result = try await parser.addTranslationsBatch(entries: entries)

        #expect(result.successCount == 3)
        #expect(result.failedCount == 0)
        #expect(Set(result.entryResults.map(\.key)) == Set(["Hello", "Goodbye", "Thanks"]))
        #expect(result.entryResults.allSatisfy { $0.status == .succeeded })

        // Verify data was written
        let keys = try await parser.listKeys()
        #expect(keys.count == 3)
        #expect(Set(keys) == Set(["Hello", "Goodbye", "Thanks"]))

        let translation = try await parser.getTranslation(key: "Hello", language: "ja")
        #expect(translation["ja"]?.value == "こんにちは")
    }

    @Test("addTranslationsBatch reports placeholder validations and rejects unsafe entries")
    func addTranslationsBatchReportsPlaceholderValidations() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.catalogPersistenceRegression)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let entries = [
            BatchTranslationEntry(
                key: "sample.library.itemAccessibilityLabel",
                translations: ["es": "Píxeles: %2$lld por %3$lld, elemento %1$@"]
            ),
            BatchTranslationEntry(
                key: "sample.action.preview",
                translations: ["es": "Vista previa %@"]
            ),
        ]

        let result = try await parser.addTranslationsBatch(entries: entries)

        #expect(result.successCount == 1)
        #expect(result.failedCount == 1)
        #expect(result.placeholderValidations.filter(\.checked).count == 1)
        let failure = try #require(result.entryResults.first { $0.status == .failed })
        #expect(failure.key == "sample.action.preview")
        #expect(failure.error?.contains("Unsafe format string") == true)
    }

    @Test("addTranslationsBatch handles duplicate and overwrite scenarios", arguments: BatchAddTestCase.allCases)
    func addTranslationsBatchDuplicateHandling(testCase: BatchAddTestCase) async throws {
        let path = try TestHelper.createTempFile(content: testCase.fixture.content)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let entries = [
            BatchTranslationEntry(key: "Hello", translations: ["en": "Updated Hello"]),
            BatchTranslationEntry(key: "NewKey", translations: ["en": "New Value"]),
        ]

        let result = try await parser.addTranslationsBatch(entries: entries, allowOverwrite: testCase.allowOverwrite)

        #expect(result.successCount == testCase.expectedSuccess)
        #expect(result.failedCount == testCase.expectedFailed)
        #expect(Set(result.entryResults.filter { $0.status == .succeeded }.map(\.key)) == Set(testCase.expectedSucceeded))
        #expect(Set(result.entryResults.filter { $0.status == .failed }.map(\.key)) == Set(testCase.expectedFailedKeys))
    }

    @Test("batch add compact result summarizes writes and failures")
    func addTranslationsBatchCompactResultSummarizesWritesAndFailures() async throws {
        let path = try TestHelper.createTempFile(content: FixtureType.singleKeySingleLang.content)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let entries = [
            BatchTranslationEntry(key: "NewKey", translations: ["en": "New Value"]),
            BatchTranslationEntry(key: "Hello", translations: ["en": "Duplicate"]),
        ]

        let compact = try await parser.addTranslationsBatch(entries: entries).compact

        #expect(!compact.success)
        #expect(compact.counts.inputEntries == 2)
        #expect(compact.counts.succeededEntries == 1)
        #expect(compact.counts.failedEntries == 1)
        #expect(compact.counts.languageWrites == 1)
        #expect(compact.counts.insertedTranslations == 1)
        #expect(compact.counts.updatedTranslations == 0)
        #expect(compact.writtenEntries.map(\.key) == ["NewKey"])
        #expect(compact.writtenEntries.first?.insertedLanguages == ["en"])
        #expect(compact.failedEntries.map(\.key) == ["Hello"])
    }

    @Test("addTranslationsBatch preserves duplicate mixed outcome input indexes")
    func addTranslationsBatchDuplicateMixedOutcomesPreserveInputIndexes() async throws {
        let path = try TestHelper.createTempFile(content: FixtureType.empty.content)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let entries = [
            BatchTranslationEntry(key: "NewKey", translations: ["en": "First value"]),
            BatchTranslationEntry(key: "NewKey", translations: ["en": "Second value"]),
        ]

        let result = try await parser.addTranslationsBatch(entries: entries)

        #expect(result.successCount == 1)
        #expect(result.failedCount == 1)
        #expect(result.entryResults.map(\.inputIndex) == [0, 1])
        #expect(result.entryResults.map(\.key) == ["NewKey", "NewKey"])
        #expect(result.entryResults.map(\.status) == [.succeeded, .failed])
        #expect(result.entryResults.filter { $0.status == .failed }.map(\.inputIndex) == [1])
    }

    @Test("addTranslationsBatch captures per-entry state snapshots for duplicate overwrites")
    func addTranslationsBatchDuplicateOverwriteStateSnapshots() async throws {
        let path = try TestHelper.createTempFile(content: FixtureType.empty.content)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let entries = [
            BatchTranslationEntry(key: "NewKey", translations: ["en": "First value"]),
            BatchTranslationEntry(key: "NewKey", translations: ["en": "Second value"]),
        ]

        let result = try await parser.addTranslationsBatch(entries: entries, allowOverwrite: true)

        #expect(result.successCount == 2)
        #expect(result.failedCount == 0)
        #expect(result.entryResults.map(\.inputIndex) == [0, 1])

        let firstLanguageResult = try #require(result.entryResults[0].languageResults.first)
        #expect(firstLanguageResult.language == "en")
        #expect(firstLanguageResult.action == .inserted)
        #expect(firstLanguageResult.previousState == nil)
        #expect(firstLanguageResult.finalState?.value == "First value")

        let secondLanguageResult = try #require(result.entryResults[1].languageResults.first)
        #expect(secondLanguageResult.language == "en")
        #expect(secondLanguageResult.action == .updated)
        #expect(secondLanguageResult.previousState?.value == "First value")
        #expect(secondLanguageResult.finalState?.value == "Second value")
    }

    // MARK: - Batch Update Translations Tests

    @Test("updateTranslationsBatch updates multiple keys successfully")
    func updateTranslationsBatchMultipleKeys() async throws {
        let path = try TestHelper.createTempFile(content: FixtureType.multipleKeysPartialTranslations.content)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let entries = [
            BatchTranslationEntry(key: "Hello", translations: ["en": "Hi there"]),
            BatchTranslationEntry(key: "Welcome", translations: ["en": "Welcome!", "ja": "ようこそ！"]),
        ]

        let result = try await parser.updateTranslationsBatch(entries: entries)

        #expect(result.successCount == 2)
        #expect(result.failedCount == 0)

        let helloTranslation = try await parser.getTranslation(key: "Hello", language: "en")
        #expect(helloTranslation["en"]?.value == "Hi there")

        let welcomeTranslation = try await parser.getTranslation(key: "Welcome", language: "en")
        #expect(welcomeTranslation["en"]?.value == "Welcome!")
    }

    @Test("updateTranslationsBatch fails for invalid scenarios", arguments: BatchUpdateFailureTestCase.allCases)
    func updateTranslationsBatchFailures(testCase: BatchUpdateFailureTestCase) async throws {
        let path = try TestHelper.createTempFile(content: testCase.fixture.content)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let entries = [
            BatchTranslationEntry(key: testCase.key, translations: testCase.translations),
        ]

        let result = try await parser.updateTranslationsBatch(entries: entries)

        #expect(result.successCount == 0)
        #expect(result.failedCount == 1)
        let failure = try #require(result.entryResults.first { $0.status == .failed })
        #expect(failure.key == testCase.expectedFailedKey)
    }

    @Test("updateTranslationsBatch with mixed success and failure")
    func updateTranslationsBatchMixed() async throws {
        let path = try TestHelper.createTempFile(content: FixtureType.singleKeySingleLang.content)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let entries = [
            BatchTranslationEntry(key: "Hello", translations: ["en": "Updated"]),
            BatchTranslationEntry(key: "NonExistent", translations: ["en": "Value"]),
        ]

        let result = try await parser.updateTranslationsBatch(entries: entries)

        #expect(result.successCount == 1)
        #expect(result.failedCount == 1)
        #expect(result.entryResults.contains { $0.key == "Hello" && $0.status == .succeeded })
        #expect(result.entryResults.contains { $0.key == "NonExistent" && $0.status == .failed })
    }

    @Test("batch update compact result summarizes writes and failures")
    func updateTranslationsBatchCompactResultSummarizesWritesAndFailures() async throws {
        let path = try TestHelper.createTempFile(content: FixtureType.singleKeySingleLang.content)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let entries = [
            BatchTranslationEntry(key: "Hello", translations: ["en": "Updated"]),
            BatchTranslationEntry(key: "NonExistent", translations: ["en": "Value"]),
        ]

        let compact = try await parser.updateTranslationsBatch(entries: entries).compact

        #expect(!compact.success)
        #expect(compact.counts.inputEntries == 2)
        #expect(compact.counts.succeededEntries == 1)
        #expect(compact.counts.failedEntries == 1)
        #expect(compact.counts.languageWrites == 1)
        #expect(compact.counts.insertedTranslations == 0)
        #expect(compact.counts.updatedTranslations == 1)
        #expect(compact.writtenEntries.map(\.key) == ["Hello"])
        #expect(compact.writtenEntries.first?.updatedLanguages == ["en"])
        #expect(compact.failedEntries.map(\.key) == ["NonExistent"])
    }

    @Test("updateTranslationsBatch preserves duplicate failed input indexes")
    func updateTranslationsBatchDuplicateFailuresPreserveInputIndexes() async throws {
        let path = try TestHelper.createTempFile(content: FixtureType.singleKeySingleLang.content)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let entries = [
            BatchTranslationEntry(key: "MissingKey", translations: ["ja": "Value A"]),
            BatchTranslationEntry(key: "MissingKey", translations: ["fr": "Value B"]),
        ]

        let result = try await parser.updateTranslationsBatch(entries: entries)

        #expect(result.successCount == 0)
        #expect(result.failedCount == 2)
        #expect(result.entryResults.map(\.inputIndex) == [0, 1])
        #expect(result.entryResults.map(\.key) == ["MissingKey", "MissingKey"])
        #expect(result.entryResults.map(\.status) == [.failed, .failed])
    }

    @Test("updateTranslationsBatch captures per-entry state snapshots for duplicate updates")
    func updateTranslationsBatchDuplicateUpdateStateSnapshots() async throws {
        let path = try TestHelper.createTempFile(content: FixtureType.singleKeySingleLang.content)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let entries = [
            BatchTranslationEntry(key: "Hello", translations: ["en": "First update"]),
            BatchTranslationEntry(key: "Hello", translations: ["en": "Second update"]),
        ]

        let result = try await parser.updateTranslationsBatch(entries: entries)

        #expect(result.successCount == 2)
        #expect(result.failedCount == 0)
        #expect(result.entryResults.map(\.inputIndex) == [0, 1])

        let firstLanguageResult = try #require(result.entryResults[0].languageResults.first)
        #expect(firstLanguageResult.action == .updated)
        #expect(firstLanguageResult.previousState?.value == "Hello")
        #expect(firstLanguageResult.finalState?.value == "First update")

        let secondLanguageResult = try #require(result.entryResults[1].languageResults.first)
        #expect(secondLanguageResult.action == .updated)
        #expect(secondLanguageResult.previousState?.value == "First update")
        #expect(secondLanguageResult.finalState?.value == "Second update")
    }

    // MARK: - Edge Cases

    @Test("batch operations with empty entries array", arguments: [
        FixtureType.empty,
        FixtureType.singleKeySingleLang,
    ])
    func batchOperationsEmptyEntries(fixture: FixtureType) async throws {
        let path = try TestHelper.createTempFile(content: fixture.content)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)

        let addResult = try await parser.addTranslationsBatch(entries: [])
        #expect(addResult.successCount == 0)
        #expect(addResult.failedCount == 0)

        let updateResult = try await parser.updateTranslationsBatch(entries: [])
        #expect(updateResult.successCount == 0)
        #expect(updateResult.failedCount == 0)
    }

    @Test("batch add preserves file integrity on partial failure")
    func batchAddPartialFailureIntegrity() async throws {
        let path = try TestHelper.createTempFile(content: FixtureType.singleKeySingleLang.content)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let entries = [
            BatchTranslationEntry(key: "NewKey1", translations: ["en": "Value1"]),
            BatchTranslationEntry(key: "Hello", translations: ["en": "Duplicate"]),
            BatchTranslationEntry(key: "NewKey2", translations: ["en": "Value2"]),
        ]

        let result = try await parser.addTranslationsBatch(entries: entries, allowOverwrite: false)

        #expect(result.successCount == 2)
        #expect(result.failedCount == 1)

        // Verify successful entries were added
        let keys = try await parser.listKeys()
        #expect(keys.contains("NewKey1"))
        #expect(keys.contains("NewKey2"))
        #expect(keys.contains("Hello"))
    }

    @Test("batch add fails entries targeting non-translatable keys")
    func addTranslationsBatchRejectsNonTranslatableKey() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.withNonTranslatableKey)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let entries = [
            BatchTranslationEntry(key: "BrandName", translations: ["ja": "ブランド名"]),
            BatchTranslationEntry(key: "Hello", translations: ["de": "Hallo"]),
        ]

        let result = try await parser.addTranslationsBatch(entries: entries)

        #expect(result.successCount == 1)
        #expect(result.failedCount == 1)
        #expect(result.entryResults.contains { $0.key == "Hello" && $0.status == .succeeded })
        #expect(result.entryResults.contains { $0.key == "BrandName" && $0.status == .failed })

        let brandKey = try await parser.getKey("BrandName")
        #expect(brandKey.shouldTranslate == false)
        #expect(brandKey.translations.isEmpty)
    }

    @Test("batch update fails entries targeting non-translatable keys")
    func updateTranslationsBatchRejectsNonTranslatableKey() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.withLocaleOnlyOnNonTranslatableKey)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let entries = [
            BatchTranslationEntry(key: "BrandName", translations: ["ja": "更新済み"]),
            BatchTranslationEntry(key: "Hello", translations: ["en": "Hi"]),
        ]

        let result = try await parser.updateTranslationsBatch(entries: entries)

        #expect(result.successCount == 1)
        #expect(result.failedCount == 1)
        #expect(result.entryResults.contains { $0.key == "Hello" && $0.status == .succeeded })
        #expect(result.entryResults.contains { $0.key == "BrandName" && $0.status == .failed })

        let brandKey = try await parser.getKey("BrandName")
        #expect(brandKey.shouldTranslate == false)
        #expect(brandKey.translations["ja"]?.value == "BrandName")
    }
}
