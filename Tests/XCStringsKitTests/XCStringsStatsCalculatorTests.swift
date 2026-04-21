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

    @Test("getCompactBatchCoverage reports complete state without optional payloads")
    func getCompactBatchCoverageComplete() throws {
        let completeFile = try loadFixture(TestFixtures.singleKeySingleLang)
        let compactBatch = XCStringsStatsCalculator.getCompactBatchCoverage(files: [
            ("Complete.xcstrings", completeFile)
        ])

        let fileSummary = try #require(compactBatch.files.first)

        #expect(fileSummary.completionState == .complete)
        #expect(fileSummary.incompleteLanguages == nil)
        #expect(fileSummary.notApplicableLanguages == nil)
        #expect(compactBatch.aggregated.completionState == .complete)
        #expect(compactBatch.aggregated.incompleteLanguages == nil)
        #expect(compactBatch.aggregated.notApplicableLanguages == nil)
    }

    @Test("measured coverage rounds serialized percentages to two decimals")
    func measuredCoverageRoundingContract() {
        let oneThird = CoverageMeasurement.measured(100.0 / 3.0)
        let noisyWholeNumber = CoverageMeasurement.measured(30.000000000000004)
        let twoThirds = CoverageMeasurement.measured(200.0 / 3.0)

        #expect(oneThird.state == .measured)
        #expect(oneThird.percent == 33.33)
        #expect(noisyWholeNumber.percent == 30.0)
        #expect(twoThirds.percent == 66.67)
    }

    @Test("measured coverage from counts shares the same output contract")
    func measuredCoverageFromCounts() {
        let partialCoverage = CoverageMeasurement.measured(translated: 1, total: 3)
        let exactCoverage = CoverageMeasurement.measured(translated: 3, total: 10)
        let emptyCoverage = CoverageMeasurement.measured(translated: 0, total: 0)

        #expect(partialCoverage.state == .measured)
        #expect(partialCoverage.percent == 33.33)
        #expect(exactCoverage.percent == 30.0)
        #expect(emptyCoverage.state == .notApplicable)
        #expect(emptyCoverage.percent == nil)
    }

    @Test("serialized percentages do not round incomplete coverage up to 100")
    func measuredCoverageDoesNotPromoteIncompleteValuesToComplete() {
        let coverage = CoverageMeasurement.measured(99.995)

        #expect(coverage.state == .measured)
        #expect(coverage.percent == 99.99)
        #expect(coverage.isIncomplete)
    }

    @Test("count-derived coverage serializes exact half-cent percentages correctly")
    func measuredCoverageRoundsHalfCentValuesCorrectly() throws {
        let coverage = CoverageMeasurement.measured(translated: 3333, total: 20_000)
        let encoded = try encodeJSON(coverage)

        #expect(coverage.state == .measured)
        #expect(encoded.contains("\"percent\":16.67"))
    }

    @Test("batch coverage averages exact file percentages before rounding")
    func batchCoverageUsesExactPercentagesBeforeRounding() throws {
        let batchCoverage = XCStringsStatsCalculator.getBatchCoverage(files: [
            ("Zero.xcstrings", makeFile(translated: 0, total: 1)),
            ("Third.xcstrings", makeFile(translated: 1, total: 3)),
            ("FourNinths.xcstrings", makeFile(translated: 4, total: 9)),
        ])

        let aggregated = try #require(batchCoverage.aggregated.averageCoverageByLanguage["en"])

        #expect(batchCoverage.files[0].languages["en"]?.percent == 0.0)
        #expect(batchCoverage.files[1].languages["en"]?.percent == 33.33)
        #expect(batchCoverage.files[2].languages["en"]?.percent == 44.44)
        #expect(aggregated.percent == 25.93)
    }

    // MARK: - Helper

    private func loadFixture(_ content: String) throws -> XCStringsFile {
        let data = content.data(using: .utf8)!
        return try JSONDecoder().decode(XCStringsFile.self, from: data)
    }

    private func makeFile(translated: Int, total: Int, language: String = "en") -> XCStringsFile {
        let strings = Dictionary(uniqueKeysWithValues: (0..<total).map { index in
            let localizations: [String: Localization]? = index < translated
                ? [language: Localization(stringUnit: StringUnit(value: "Value \(index)"))]
                : nil
            return ("Key\(index)", StringEntry(localizations: localizations))
        })

        return XCStringsFile(sourceLanguage: language, strings: strings, version: "1.0")
    }

    private func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONEncoder().encode(value)
        return try #require(String(data: data, encoding: .utf8))
    }
}
