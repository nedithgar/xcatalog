import Foundation
import Testing
@testable import XCStringsKit

@Suite("Calculating translation coverage and progress statistics")
struct StatsOperationsTests {
    @Test("getStats returns correct total keys", arguments: FixtureType.allCases)
    func getStatsTotalKeys(fixture: FixtureType) async throws {
        let path = try TestHelper.createTempFile(content: fixture.content)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let stats = try await parser.getStats()

        #expect(stats.totalKeys == fixture.expectedKeyCount)
    }

    @Test("getStats returns correct source language", arguments: FixtureType.allCases)
    func getStatsSourceLanguage(fixture: FixtureType) async throws {
        let path = try TestHelper.createTempFile(content: fixture.content)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let stats = try await parser.getStats()

        #expect(stats.sourceLanguage == fixture.expectedSourceLanguage)
    }

    @Test("getProgress returns correct progress", arguments: [
        (FixtureType.multipleKeysPartialTranslations, "ja", 2, 1),
        (FixtureType.multipleKeysPartialTranslations, "de", 1, 2),
        (FixtureType.manyKeys, "ja", 3, 7),
        (FixtureType.manyKeys, "en", 10, 0),
    ])
    func getProgress(fixture: FixtureType, language: String, translated: Int, untranslated: Int) async throws {
        let path = try TestHelper.createTempFile(content: fixture.content)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let progress = try await parser.getProgress(for: language)

        #expect(progress.translated == translated)
        #expect(progress.untranslated == untranslated)
    }

    @Test("getStats excludes non-translatable keys from coverage totals")
    func getStatsExcludesNonTranslatableKeys() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.withNonTranslatableKey)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let stats = try await parser.getStats()
        let jaStats = try #require(stats.coverageByLanguage["ja"])

        #expect(stats.totalKeys == 2)
        #expect(jaStats.translated == 1)
        #expect(jaStats.untranslated == 0)
        #expect(jaStats.total == 1)
        #expect(jaStats.coverage.state == .measured)
        #expect(jaStats.coverage.percent == 100.0)
    }

    @Test("getProgress excludes non-translatable keys from totals")
    func getProgressExcludesNonTranslatableKeys() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.withNonTranslatableKey)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let progress = try await parser.getProgress(for: "ja")

        #expect(progress.translated == 1)
        #expect(progress.untranslated == 0)
        #expect(progress.total == 1)
        #expect(progress.coverage.state == .measured)
        #expect(progress.coverage.percent == 100.0)
    }

    @Test("getStats marks locales used only by non-translatable keys as notApplicable")
    func getStatsLocaleOnlyOnNonTranslatableKey() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.withLocaleOnlyOnNonTranslatableKey)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let stats = try await parser.getStats()
        let enStats = try #require(stats.coverageByLanguage["en"])
        let jaStats = try #require(stats.coverageByLanguage["ja"])

        #expect(enStats.translated == 1)
        #expect(enStats.untranslated == 0)
        #expect(enStats.total == 1)
        #expect(enStats.coverage.state == .measured)
        #expect(enStats.coverage.percent == 100.0)

        #expect(jaStats.translated == 0)
        #expect(jaStats.untranslated == 0)
        #expect(jaStats.total == 0)
        #expect(jaStats.coverage.state == .notApplicable)
        #expect(jaStats.coverage.percent == nil)
    }

    @Test("getProgress marks empty files as notApplicable")
    func getProgressEmptyFile() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.empty)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let progress = try await parser.getProgress(for: "en")

        #expect(progress.translated == 0)
        #expect(progress.untranslated == 0)
        #expect(progress.total == 0)
        #expect(progress.coverage.state == .notApplicable)
        #expect(progress.coverage.percent == nil)
    }

    @Test("getCompactStats reports tri-state completion for empty files")
    func getCompactStatsEmptyFile() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.empty)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let compactStats = try await parser.getCompactStats()

        #expect(compactStats.completionState == .notApplicable)
        #expect(compactStats.notApplicableLanguages == ["en"])
    }

    @Test("getStats derives coverage correctly from real-world sample")
    func getStatsRealWorldSample() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.realWorldSample)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let stats = try await parser.getStats()
        let enStats = try #require(stats.coverageByLanguage["en"])
        let frStats = try #require(stats.coverageByLanguage["fr"])
        let jaStats = try #require(stats.coverageByLanguage["ja"])

        #expect(stats.languages == ["en", "fr", "ja"])

        #expect(enStats.translated == 1)
        #expect(enStats.untranslated == 1)
        #expect(enStats.total == 2)
        #expect(enStats.coverage.percent == 50.0)

        #expect(frStats.translated == 1)
        #expect(frStats.untranslated == 1)
        #expect(frStats.total == 2)
        #expect(frStats.coverage.percent == 50.0)

        #expect(jaStats.translated == 2)
        #expect(jaStats.untranslated == 0)
        #expect(jaStats.total == 2)
        #expect(jaStats.coverage.percent == 100.0)
    }
}
