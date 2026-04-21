import Foundation

/// Handles statistics calculations for xcstrings files
struct XCStringsStatsCalculator: Sendable {
    private let file: XCStringsFile
    private let reader: XCStringsReader

    init(file: XCStringsFile) {
        self.file = file
        self.reader = XCStringsReader(file: file)
    }

    /// Get overall statistics
    func getStats() -> StatsInfo {
        let allLanguages = reader.listLanguages()
        let translatableLanguages = Set(reader.listTranslatableLanguages())
        let translatableEntries = file.strings.values.filter(\.requiresTranslation)

        let coverageByLanguage = Dictionary(uniqueKeysWithValues: allLanguages.lazy.map { language in
            // Locales that appear only on non-translatable entries are out of scope
            // for translation coverage; report them as not-applicable with zero totals.
            guard translatableLanguages.contains(language) else {
                return (language, LanguageStats(
                    translated: 0,
                    untranslated: 0,
                    total: 0,
                    coverage: .notApplicable
                ))
            }

            let translated = translatableEntries.lazy.filter { $0.countsAsTranslated(for: language) }.count
            let total = translatableEntries.count
            let untranslated = total - translated
            let coverage = CoverageMeasurement.measured(translated: translated, total: total)

            return (language, LanguageStats(
                translated: translated,
                untranslated: untranslated,
                total: total,
                coverage: coverage
            ))
        })

        return StatsInfo(
            totalKeys: file.strings.count,
            sourceLanguage: file.sourceLanguage,
            languages: allLanguages,
            coverageByLanguage: coverageByLanguage
        )
    }

    /// Get progress for a specific language
    func getProgress(for language: String) throws -> LanguageStats {
        let stats = getStats()

        guard let langStats = stats.coverageByLanguage[language] else {
            throw XCStringsError.languageNotFound(language: language, key: "")
        }

        return langStats
    }

    /// Get compact coverage summary (token-efficient)
    func getCoverageSummary(fileName: String) -> FileCoverageSummary {
        let stats = getStats()
        let languages = stats.coverageByLanguage.mapValues(\.coverage)
        return FileCoverageSummary(
            file: fileName,
            totalKeys: stats.totalKeys,
            languages: languages
        )
    }

    /// Get batch coverage for multiple files
    static func getBatchCoverage(files: [(path: String, file: XCStringsFile)]) -> BatchCoverageSummary {
        let summaries = files.map { (path, file) in
            XCStringsStatsCalculator(file: file).getCoverageSummary(fileName: path)
        }

        // Aggregate stats
        let totalFiles = summaries.count
        let totalKeys = summaries.reduce(0) { $0 + $1.totalKeys }

        // Average only measurable coverage values. If a language has no translatable
        // work across all files, surface that as notApplicable instead of inventing a percent.
        let allLanguages = Set(summaries.lazy.flatMap { $0.languages.keys })
        let languageTotals = summaries.lazy
            .flatMap(\.languages)
            .reduce(into: [String: (sum: Decimal, count: Int)]()) { totals, pair in
                guard let percent = pair.value.rawPercent else {
                    totals[pair.key] = totals[pair.key] ?? (sum: .zero, count: 0)
                    return
                }

                let current = totals[pair.key] ?? (sum: .zero, count: 0)
                totals[pair.key] = (sum: current.sum + percent, count: current.count + 1)
            }
        let averageCoverage = Dictionary(uniqueKeysWithValues: allLanguages.map { language in
            let totals = languageTotals[language] ?? (sum: .zero, count: 0)
            let measurement = totals.count == 0
                ? CoverageMeasurement.notApplicable
                : .measured(totals.sum / Decimal(totals.count))
            return (language, measurement)
        })

        return BatchCoverageSummary(
            files: summaries,
            aggregated: AggregatedCoverage(
                totalFiles: totalFiles,
                totalKeys: totalKeys,
                averageCoverageByLanguage: averageCoverage
            )
        )
    }

    // MARK: - Compact Output (100% languages omitted)

    /// Get compact stats (only shows incomplete languages)
    func getCompactStats() -> CompactStatsInfo {
        CompactStatsInfo(from: getStats())
    }

    /// Get compact batch coverage for multiple files
    static func getCompactBatchCoverage(files: [(path: String, file: XCStringsFile)]) -> CompactBatchCoverageSummary {
        CompactBatchCoverageSummary(from: getBatchCoverage(files: files))
    }
}
