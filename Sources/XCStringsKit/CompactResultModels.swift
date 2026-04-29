import Foundation

// MARK: - Shared Compact Models

package struct CompactPlaceholderValidationSummary: Codable, Sendable {
    package let checked: Int
    package let failed: Int

    package init(validations: [PlaceholderValidationResult]) {
        let checkedValidations = validations.filter(\.checked)
        self.checked = checkedValidations.count
        self.failed = checkedValidations.filter { !$0.isValid }.count
    }
}

// MARK: - Preflight Compact Models

package struct PreflightCompactReport: Codable, Sendable {
    package let sourceLanguage: String
    package let targetLanguage: String
    package let summary: PreflightCompactSummary
    package let safeKeys: [String]
    package let formatSensitiveKeys: [String]
    package let richOrUnsafeKeys: [String]
    package let skipKeys: [String]

    package init(report: PreflightLocaleReport) {
        self.sourceLanguage = report.sourceLanguage
        self.targetLanguage = report.targetLanguage
        self.summary = PreflightCompactSummary(report: report)
        self.safeKeys = report.summary.safeToBatchAddKeys
        self.formatSensitiveKeys = report.summary.formatStringKeysRequiringValidation
        self.richOrUnsafeKeys = Self.uniqueSorted(
            report.summary.richKeysRequiringSpecialHandling + report.unsafeToWriteKeys.map(\.key)
        )
        self.skipKeys = report.summary.skipKeys
    }

    private static func uniqueSorted(_ keys: [String]) -> [String] {
        Array(Set(keys)).sorted()
    }
}

package struct PreflightCompactSummary: Codable, Sendable {
    package let totalKeys: Int
    package let translatableKeys: Int
    package let alreadyTranslatedKeys: Int
    package let untranslatedKeys: Int
    package let missingSimpleKeys: Int
    package let missingFormatKeys: Int
    package let missingRichKeys: Int
    package let missingVariationKeys: Int
    package let missingSubstitutionKeys: Int
    package let nonTranslatableKeys: Int
    package let staleKeys: Int
    package let unsafeKeys: Int

    package init(report: PreflightLocaleReport) {
        self.totalKeys = report.summary.totalKeys
        self.translatableKeys = report.summary.translatableKeys
        self.alreadyTranslatedKeys = report.summary.translatedKeys
        self.untranslatedKeys = report.summary.untranslatedKeys
        self.missingSimpleKeys = report.summary.missingSimpleStringUnitKeys
        self.missingFormatKeys = report.summary.missingFormatStringKeys
        self.missingVariationKeys = report.summary.missingVariationKeys
        self.missingSubstitutionKeys = report.summary.missingSubstitutionKeys
        self.missingRichKeys = report.summary.missingVariationKeys + report.summary.missingSubstitutionKeys
        self.nonTranslatableKeys = report.summary.nonTranslatableKeys
        self.staleKeys = report.summary.staleKeys
        self.unsafeKeys = report.summary.unsafeToWriteKeys
    }
}

package extension PreflightLocaleReport {
    var compact: PreflightCompactReport {
        PreflightCompactReport(report: self)
    }
}

// MARK: - Locale Supplement Compact Models

package struct LocaleSupplementCompactResult: Codable, Sendable {
    package let status: LocaleSupplementStatus
    package let success: Bool
    package let fileChanged: Bool
    package let wouldWrite: Bool
    package let compileValidationRanOnProjectedCatalog: Bool
    package let targetLanguage: String
    package let counts: LocaleSupplementCounts
    package let placeholderValidation: CompactPlaceholderValidationSummary
    package let compileValidationStatus: LocaleSupplementCompileStatus
    package let remainingUntranslatedCount: Int?
    package let remainingUntranslatedKeys: [String]?
    package let diagnostics: [String]

    package init(result: LocaleSupplementResult, remainingUntranslatedKeys: [String]? = nil) {
        self.status = result.status
        self.success = result.success
        self.fileChanged = result.fileChanged
        self.wouldWrite = result.wouldWrite
        self.compileValidationRanOnProjectedCatalog = result.compileValidationRanOnProjectedCatalog
        self.targetLanguage = result.plan.targetLanguage
        self.counts = result.counts
        self.placeholderValidation = CompactPlaceholderValidationSummary(validations: result.placeholderValidations)
        self.compileValidationStatus = result.compileValidation.status
        self.remainingUntranslatedCount = remainingUntranslatedKeys?.count
        self.remainingUntranslatedKeys = remainingUntranslatedKeys
        self.diagnostics = result.diagnostics
    }
}

package extension LocaleSupplementResult {
    func compact(remainingUntranslatedKeys: [String]? = nil) -> LocaleSupplementCompactResult {
        LocaleSupplementCompactResult(result: self, remainingUntranslatedKeys: remainingUntranslatedKeys)
    }

    func projectedRemainingUntranslatedKeys(currentUntranslatedKeys: [String]) -> [String] {
        guard status == .dryRun else {
            return currentUntranslatedKeys
        }

        guard !plan.hasBlockingDiagnostics || plan.allowPartial else {
            return currentUntranslatedKeys
        }

        let projectedWrites = Set(
            plan.entries
                .filter { $0.action == .insert || $0.action == .update }
                .map(\.key)
        )
        return currentUntranslatedKeys.filter { !projectedWrites.contains($0) }
    }
}

// MARK: - Catalog Validation Compact Models

package struct CatalogValidationCompactReport: Codable, Sendable {
    package let file: String
    package let success: Bool
    package let jsonParseable: Bool
    package let modelDecodable: Bool
    package let compileValidationStatus: CatalogCompileStatus
    package let summary: CatalogValidationSummary
    package let issues: [CatalogValidationCompactIssue]
    package let truncatedIssueCount: Int

    package init(report: CatalogValidationReport, issueLimit: Int = 20) {
        self.file = report.file
        self.success = report.success
        self.jsonParseable = report.jsonParseable
        self.modelDecodable = report.modelDecodable
        self.compileValidationStatus = report.compileValidation.status
        self.summary = report.summary
        self.issues = report.issues.prefix(max(issueLimit, 0)).map(CatalogValidationCompactIssue.init(issue:))
        self.truncatedIssueCount = max(report.issues.count - issueLimit, 0)
    }
}

package struct CatalogValidationCompactIssue: Codable, Sendable {
    package let code: String
    package let severity: CatalogValidationSeverity
    package let message: String
    package let key: String?
    package let language: String?

    package init(issue: CatalogValidationIssue) {
        self.code = issue.code
        self.severity = issue.severity
        self.message = issue.message
        self.key = issue.key
        self.language = issue.language
    }
}

package extension CatalogValidationReport {
    func compact(issueLimit: Int = 20) -> CatalogValidationCompactReport {
        CatalogValidationCompactReport(report: self, issueLimit: issueLimit)
    }
}
