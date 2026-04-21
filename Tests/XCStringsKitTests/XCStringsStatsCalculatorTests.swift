import Foundation
import Testing
@testable import XCStringsKit

@Suite("Statistics and coverage calculations for xcstrings files")
struct XCStringsStatsCalculatorTests {
    // MARK: - getStats

    @Test("getStats returns correct total key count")
    func getStatsTotalKeys() throws {
        let file = try loadFixture(TestFixtures.manyKeys)
        let calculator = XCStringsStatsCalculator(file: file)

        let stats = calculator.getStats()

        #expect(stats.totalKeys == 10)
    }

    @Test("getStats returns correct source language")
    func getStatsSourceLanguage() throws {
        let file = try loadFixture(TestFixtures.japaneseSource)
        let calculator = XCStringsStatsCalculator(file: file)

        let stats = calculator.getStats()

        #expect(stats.sourceLanguage == "ja")
    }

    @Test("getStats returns all languages")
    func getStatsLanguages() throws {
        let file = try loadFixture(TestFixtures.manyLanguages)
        let calculator = XCStringsStatsCalculator(file: file)

        let stats = calculator.getStats()

        #expect(stats.languages.contains("en"))
        #expect(stats.languages.contains("ja"))
        #expect(stats.languages.contains("de"))
        #expect(stats.languages.contains("fr"))
        #expect(stats.languages.contains("es"))
    }

    @Test("getStats calculates coverage by language")
    func getStatsCoverage() throws {
        let file = try loadFixture(TestFixtures.singleKeyMultipleLangs)
        let calculator = XCStringsStatsCalculator(file: file)

        let stats = calculator.getStats()

        #expect(stats.coverageByLanguage["en"]?.coverage.state == .measured)
        #expect(stats.coverageByLanguage["en"]?.coverage.percent == 100.0)
        #expect(stats.coverageByLanguage["ja"]?.coverage.state == .measured)
        #expect(stats.coverageByLanguage["ja"]?.coverage.percent == 100.0)
    }

    @Test("getStats marks empty files as notApplicable")
    func getStatsEmpty() throws {
        let file = try loadFixture(TestFixtures.empty)
        let calculator = XCStringsStatsCalculator(file: file)

        let stats = calculator.getStats()
        let sourceStats = try #require(stats.coverageByLanguage["en"])

        #expect(stats.totalKeys == 0)
        #expect(sourceStats.total == 0)
        #expect(sourceStats.coverage.state == .notApplicable)
        #expect(sourceStats.coverage.percent == nil)
    }

    @Test("getStats calculates partial coverage correctly")
    func getStatsPartialCoverage() throws {
        let file = try loadFixture(TestFixtures.multipleKeysPartialTranslations)
        let calculator = XCStringsStatsCalculator(file: file)

        let stats = calculator.getStats()

        // English should have higher coverage than other languages
        let enStats = stats.coverageByLanguage["en"]
        let jaStats = stats.coverageByLanguage["ja"]

        #expect(enStats != nil)
        #expect(jaStats != nil)
        #expect(enStats!.translated >= jaStats!.translated)
    }

    // MARK: - getProgress

    @Test("getProgress returns stats for specific language")
    func getProgressSpecificLanguage() throws {
        let file = try loadFixture(TestFixtures.singleKeyMultipleLangs)
        let calculator = XCStringsStatsCalculator(file: file)

        let progress = try calculator.getProgress(for: "ja")

        #expect(progress.translated == 1)
        #expect(progress.total == 1)
        #expect(progress.coverage.state == .measured)
        #expect(progress.coverage.percent == 100.0)
    }

    @Test("getProgress throws for non-existent language")
    func getProgressLanguageNotFound() throws {
        let file = try loadFixture(TestFixtures.singleKeySingleLang)
        let calculator = XCStringsStatsCalculator(file: file)

        #expect(throws: XCStringsError.self) {
            _ = try calculator.getProgress(for: "fr")
        }
    }

    @Test("getProgress calculates untranslated count correctly")
    func getProgressUntranslated() throws {
        let file = try loadFixture(TestFixtures.multipleKeysPartialTranslations)
        let calculator = XCStringsStatsCalculator(file: file)

        let progress = try calculator.getProgress(for: "ja")

        #expect(progress.untranslated > 0)
        #expect(progress.total == progress.translated + progress.untranslated)
    }

    @Test("getBatchCoverage keeps non-applicable coverage explicit")
    func getBatchCoverageNotApplicable() throws {
        let emptyFile = try loadFixture(TestFixtures.empty)
        let batchCoverage = XCStringsStatsCalculator.getBatchCoverage(files: [
            ("Empty.xcstrings", emptyFile)
        ])

        let aggregated = try #require(batchCoverage.aggregated.averageCoverageByLanguage["en"])
        let fileCoverage = try #require(batchCoverage.files.first?.languages["en"])

        #expect(aggregated.state == .notApplicable)
        #expect(aggregated.percent == nil)
        #expect(fileCoverage.state == .notApplicable)
        #expect(fileCoverage.percent == nil)
    }

    @Test("getCompactStats reports incomplete state when translations are missing")
    func getCompactStatsIncomplete() throws {
        let file = try loadFixture(TestFixtures.multipleKeysPartialTranslations)
        let compactStats = XCStringsStatsCalculator(file: file).getCompactStats()

        #expect(compactStats.completionState == .incomplete)
        #expect(compactStats.incompleteLanguages?.isEmpty == false)
    }

    @Test("getCompactStats reports notApplicable state for empty files")
    func getCompactStatsEmpty() throws {
        let file = try loadFixture(TestFixtures.empty)
        let compactStats = XCStringsStatsCalculator(file: file).getCompactStats()

        #expect(compactStats.completionState == .notApplicable)
        #expect(compactStats.notApplicableLanguages == ["en"])
    }

    @Test("getCompactStats reports notApplicable state for non-translatable-only files")
    func getCompactStatsNonTranslatableOnly() throws {
        let file = try loadFixture("""
        {
          "sourceLanguage": "en",
          "strings": {
            "BrandName": {
              "comment": "Proper noun shown as-is in every locale",
              "shouldTranslate": false
            }
          },
          "version": "1.0"
        }
        """)
        let compactStats = XCStringsStatsCalculator(file: file).getCompactStats()

        #expect(compactStats.completionState == .notApplicable)
        #expect(compactStats.notApplicableLanguages == ["en"])
    }

    @Test("getCompactBatchCoverage reports tri-state completion")
    func getCompactBatchCoverageStates() throws {
        let emptyFile = try loadFixture(TestFixtures.empty)
        let partialFile = try loadFixture(TestFixtures.multipleKeysPartialTranslations)
        let compactBatch = XCStringsStatsCalculator.getCompactBatchCoverage(files: [
            ("Empty.xcstrings", emptyFile),
            ("Partial.xcstrings", partialFile)
        ])

        let emptySummary = try #require(compactBatch.files.first)
        let partialSummary = try #require(compactBatch.files.last)

        #expect(emptySummary.completionState == .notApplicable)
        #expect(partialSummary.completionState == .incomplete)
        #expect(compactBatch.aggregated.completionState == .incomplete)
    }

    // MARK: - Helper

    private func loadFixture(_ content: String) throws -> XCStringsFile {
        let data = content.data(using: .utf8)!
        return try JSONDecoder().decode(XCStringsFile.self, from: data)
    }
}
