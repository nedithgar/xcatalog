import Foundation

package enum CatalogValidationSeverity: String, Codable, Sendable {
    case warning
    case error
}

package struct CatalogValidationIssue: Codable, Sendable {
    package let code: String
    package let severity: CatalogValidationSeverity
    package let message: String
    package let key: String?
    package let language: String?
    package let path: String?

    package init(
        code: String,
        severity: CatalogValidationSeverity,
        message: String,
        key: String? = nil,
        language: String? = nil,
        path: String? = nil
    ) {
        self.code = code
        self.severity = severity
        self.message = message
        self.key = key
        self.language = language
        self.path = path
    }
}

package enum CatalogCompileStatus: String, Codable, Sendable {
    case notRequested
    case passed
    case failed
    case unavailable
}

package struct CatalogCompileValidation: Codable, Sendable {
    package let status: CatalogCompileStatus
    package let command: [String]
    package let diagnostics: String?

    package init(
        status: CatalogCompileStatus,
        command: [String] = [],
        diagnostics: String? = nil
    ) {
        self.status = status
        self.command = command
        self.diagnostics = diagnostics
    }

    package static var notRequested: CatalogCompileValidation {
        CatalogCompileValidation(status: .notRequested)
    }
}

package struct CatalogValidationSummary: Codable, Sendable {
    package let issueCount: Int
    package let errorCount: Int
    package let warningCount: Int
    package let placeholderValidationCount: Int
    package let invalidPlaceholderValidationCount: Int
    package let richLocalizationCount: Int
    package let suspiciousKeyCount: Int

    package init(
        issues: [CatalogValidationIssue],
        placeholderReport: PlaceholderValidationReport?,
        richRecordReport: RichRecordValidationReport?,
        suspiciousKeyReport: SuspiciousKeysReport?
    ) {
        self.issueCount = issues.count
        self.errorCount = issues.filter { $0.severity == .error }.count
        self.warningCount = issues.filter { $0.severity == .warning }.count
        self.placeholderValidationCount = placeholderReport?.summary.checkedTranslations ?? 0
        self.invalidPlaceholderValidationCount = placeholderReport?.summary.invalidTranslations ?? 0
        self.richLocalizationCount = richRecordReport?.richLocalizationCount ?? 0
        self.suspiciousKeyCount = suspiciousKeyReport?.findings.count ?? 0
    }
}

package struct CatalogValidationReport: Codable, Sendable {
    package let file: String
    package let success: Bool
    package let jsonParseable: Bool
    package let modelDecodable: Bool
    package let compileValidation: CatalogCompileValidation
    package let placeholderReport: PlaceholderValidationReport?
    package let richRecordReport: RichRecordValidationReport?
    package let suspiciousKeyReport: SuspiciousKeysReport?
    package let issues: [CatalogValidationIssue]
    package let summary: CatalogValidationSummary

    package init(
        file: String,
        jsonParseable: Bool,
        modelDecodable: Bool,
        compileValidation: CatalogCompileValidation = .notRequested,
        placeholderReport: PlaceholderValidationReport? = nil,
        richRecordReport: RichRecordValidationReport? = nil,
        suspiciousKeyReport: SuspiciousKeysReport? = nil,
        issues: [CatalogValidationIssue]
    ) {
        self.file = file
        self.jsonParseable = jsonParseable
        self.modelDecodable = modelDecodable
        self.compileValidation = compileValidation
        self.placeholderReport = placeholderReport
        self.richRecordReport = richRecordReport
        self.suspiciousKeyReport = suspiciousKeyReport
        self.issues = issues
        self.summary = CatalogValidationSummary(
            issues: issues,
            placeholderReport: placeholderReport,
            richRecordReport: richRecordReport,
            suspiciousKeyReport: suspiciousKeyReport
        )
        self.success = jsonParseable && modelDecodable && summary.errorCount == 0
    }
}

package struct PlaceholderValidationSummary: Codable, Sendable {
    package let checkedTranslations: Int
    package let invalidTranslations: Int
    package let issueCount: Int

    package init(validations: [PlaceholderValidationResult], issues: [CatalogValidationIssue]) {
        self.checkedTranslations = validations.count
        self.invalidTranslations = validations.filter { !$0.isValid }.count
        self.issueCount = issues.count
    }
}

package struct PlaceholderValidationReport: Codable, Sendable {
    package let sourceLanguage: String
    package let languages: [String]
    package let success: Bool
    package let validations: [PlaceholderValidationResult]
    package let issues: [CatalogValidationIssue]
    package let summary: PlaceholderValidationSummary

    package init(
        sourceLanguage: String,
        languages: [String],
        validations: [PlaceholderValidationResult],
        issues: [CatalogValidationIssue]
    ) {
        self.sourceLanguage = sourceLanguage
        self.languages = languages
        self.validations = validations
        self.issues = issues
        self.summary = PlaceholderValidationSummary(validations: validations, issues: issues)
        self.success = issues.allSatisfy { $0.severity != .error }
    }
}

package struct RichRecordValidationReport: Codable, Sendable {
    package let success: Bool
    package let richLocalizationCount: Int
    package let roundTripPreserved: Bool
    package let issues: [CatalogValidationIssue]

    package init(
        richLocalizationCount: Int,
        roundTripPreserved: Bool,
        issues: [CatalogValidationIssue]
    ) {
        self.richLocalizationCount = richLocalizationCount
        self.roundTripPreserved = roundTripPreserved
        self.issues = issues
        self.success = roundTripPreserved && issues.allSatisfy { $0.severity != .error }
    }
}

package struct SuspiciousKeyFinding: Codable, Sendable {
    package let key: String
    package let code: String
    package let severity: CatalogValidationSeverity
    package let reason: String

    package init(key: String, code: String, severity: CatalogValidationSeverity, reason: String) {
        self.key = key
        self.code = code
        self.severity = severity
        self.reason = reason
    }
}

package struct SuspiciousKeysReport: Codable, Sendable {
    package let success: Bool
    package let findings: [SuspiciousKeyFinding]
    package let issues: [CatalogValidationIssue]

    package init(findings: [SuspiciousKeyFinding]) {
        self.findings = findings
        self.issues = findings.map { finding in
            CatalogValidationIssue(
                code: finding.code,
                severity: finding.severity,
                message: finding.reason,
                key: finding.key,
                path: "strings[\(Self.displayKey(finding.key))]"
            )
        }
        self.success = issues.allSatisfy { $0.severity != .error }
    }

    private static func displayKey(_ key: String) -> String {
        key.isEmpty ? "\"\"" : "\"\(key)\""
    }
}

package enum XCStringsCatalogValidator {
    package static func validateCatalog(
        path: String,
        validateCompile: Bool = false,
        compileLanguages: [String] = []
    ) -> CatalogValidationReport {
        var issues: [CatalogValidationIssue] = []
        var jsonParseable = false
        var modelDecodable = false
        var loadedFile: XCStringsFile?

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            do {
                _ = try JSONSerialization.jsonObject(with: data)
                jsonParseable = true
            } catch {
                issues.append(CatalogValidationIssue(
                    code: "json_parse_failed",
                    severity: .error,
                    message: error.localizedDescription,
                    path: path
                ))
            }
        } catch {
            issues.append(CatalogValidationIssue(
                code: "file_read_failed",
                severity: .error,
                message: error.localizedDescription,
                path: path
            ))
        }

        if jsonParseable {
            do {
                loadedFile = try XCStringsFileHandler(path: path).load()
                modelDecodable = true
            } catch {
                issues.append(CatalogValidationIssue(
                    code: "model_decode_failed",
                    severity: .error,
                    message: error.localizedDescription,
                    path: path
                ))
            }
        }

        let compileValidation = validateCompile
            ? XCStringsCatalogCompiler.validateCompile(path: path, languages: compileLanguages)
            : .notRequested
        if compileValidation.status == .failed {
            issues.append(CatalogValidationIssue(
                code: "xcstringstool_compile_failed",
                severity: .error,
                message: compileValidation.diagnostics ?? "xcstringstool compile --dry-run failed.",
                path: path
            ))
        } else if compileValidation.status == .unavailable {
            issues.append(CatalogValidationIssue(
                code: "xcstringstool_unavailable",
                severity: .warning,
                message: compileValidation.diagnostics ?? "xcrun could not locate xcstringstool.",
                path: path
            ))
        }

        guard let file = loadedFile else {
            return CatalogValidationReport(
                file: path,
                jsonParseable: jsonParseable,
                modelDecodable: modelDecodable,
                compileValidation: compileValidation,
                issues: issues
            )
        }

        let placeholderReport = validatePlaceholders(in: file)
        let richRecordReport = validateRichRecords(in: file)
        let suspiciousKeyReport = findSuspiciousKeys(in: file)
        issues.append(contentsOf: placeholderReport.issues)
        issues.append(contentsOf: richRecordReport.issues)
        issues.append(contentsOf: suspiciousKeyReport.issues)

        return CatalogValidationReport(
            file: path,
            jsonParseable: jsonParseable,
            modelDecodable: modelDecodable,
            compileValidation: compileValidation,
            placeholderReport: placeholderReport,
            richRecordReport: richRecordReport,
            suspiciousKeyReport: suspiciousKeyReport,
            issues: issues
        )
    }

    package static func validatePlaceholders(in file: XCStringsFile) -> PlaceholderValidationReport {
        var validations: [PlaceholderValidationResult] = []
        var issues: [CatalogValidationIssue] = []
        let languages = validationLanguages(in: file)

        for key in file.strings.keys.sorted() {
            guard let entry = file.strings[key],
                  entry.requiresTranslation,
                  let sourceLocalization = entry.localizations?[file.sourceLanguage] else {
                continue
            }

            for language in languages where language != file.sourceLanguage {
                guard let targetLocalization = entry.localizations?[language],
                      entry.hasConcreteLocalization(for: language) else {
                    continue
                }

                let result = validateLocalizationPlaceholders(
                    key: key,
                    language: language,
                    sourceLocalization: sourceLocalization,
                    targetLocalization: targetLocalization
                )
                validations.append(contentsOf: result.validations)
                issues.append(contentsOf: result.issues)
            }
        }

        return PlaceholderValidationReport(
            sourceLanguage: file.sourceLanguage,
            languages: languages,
            validations: validations,
            issues: issues
        )
    }

    package static func validateRichRecords(in file: XCStringsFile) -> RichRecordValidationReport {
        var issues = validateRichRecordStructure(in: file)
        let signatures = richRecordSignatures(in: file)
        var roundTripPreserved = true

        do {
            let data = try XCStringsJSONSerializer.data(for: file, appendTrailingNewline: true)
            let decoded = try JSONDecoder().decode(XCStringsFile.self, from: data)
            let decodedSignatures = richRecordSignatures(in: decoded)
            if signatures != decodedSignatures {
                roundTripPreserved = false
                issues.append(CatalogValidationIssue(
                    code: "rich_record_roundtrip_changed",
                    severity: .error,
                    message: "Substitution or variation records changed after model encode/decode round trip."
                ))
            }
        } catch {
            roundTripPreserved = false
            issues.append(CatalogValidationIssue(
                code: "rich_record_roundtrip_failed",
                severity: .error,
                message: error.localizedDescription
            ))
        }

        return RichRecordValidationReport(
            richLocalizationCount: signatures.count,
            roundTripPreserved: roundTripPreserved,
            issues: issues
        )
    }

    package static func findSuspiciousKeys(in file: XCStringsFile) -> SuspiciousKeysReport {
        let findings = file.strings.keys.sorted().flatMap(suspiciousFindings(for:))
        return SuspiciousKeysReport(findings: findings)
    }

    private static func validateLocalizationPlaceholders(
        key: String,
        language: String,
        sourceLocalization: Localization,
        targetLocalization: Localization
    ) -> (validations: [PlaceholderValidationResult], issues: [CatalogValidationIssue]) {
        var validations: [PlaceholderValidationResult] = []
        var issues: [CatalogValidationIssue] = []

        if let sourceValue = sourceLocalization.stringUnit?.value,
           let targetValue = targetLocalization.stringUnit?.value {
            let validation = validatePlaceholderSet(
                key: key,
                language: language,
                sourceValue: sourceValue,
                targetValue: targetValue
            )
            if validation.checked {
                validations.append(validation)
            }
            issues.append(contentsOf: issuesForInvalidValidation(validation, path: "strings[\(quotedKey(key))].localizations.\(language).stringUnit.value"))
        }

        let variationResult = validateVariationPlaceholders(
            key: key,
            language: language,
            sourceVariations: sourceLocalization.variations,
            targetVariations: targetLocalization.variations,
            basePath: "strings[\(quotedKey(key))].localizations.\(language).variations"
        )
        validations.append(contentsOf: variationResult.validations)
        issues.append(contentsOf: variationResult.issues)

        let substitutionResult = validateSubstitutionPlaceholders(
            key: key,
            language: language,
            sourceSubstitutions: sourceLocalization.substitutions,
            targetSubstitutions: targetLocalization.substitutions
        )
        validations.append(contentsOf: substitutionResult.validations)
        issues.append(contentsOf: substitutionResult.issues)

        return (validations, issues)
    }

    private static func validatePlaceholderSet(
        key: String,
        language: String,
        sourceValue: String,
        targetValue: String
    ) -> PlaceholderValidationResult {
        let sourcePlaceholders = FormatStringSafety.placeholders(in: sourceValue)
        let targetPlaceholders = FormatStringSafety.placeholders(in: targetValue)
        let sourceIsPlainPrintf = sourcePlaceholders.allSatisfy { $0.kind == .printf }
        let targetIsPlainPrintf = targetPlaceholders.allSatisfy { $0.kind == .printf }

        if sourceIsPlainPrintf && targetIsPlainPrintf {
            return FormatStringSafety.validate(
                key: key,
                language: language,
                sourceValue: sourceValue,
                targetValue: targetValue
            )
        }

        return PlaceholderValidationResult(
            key: key,
            language: language,
            sourceValue: sourceValue,
            targetValue: targetValue,
            sourcePlaceholders: sourcePlaceholders,
            targetPlaceholders: targetPlaceholders,
            diagnostics: compareRichPlaceholders(source: sourcePlaceholders, target: targetPlaceholders)
        )
    }

    private static func compareRichPlaceholders(
        source: [FormatPlaceholder],
        target: [FormatPlaceholder]
    ) -> [String] {
        let sourceCounts = placeholderCounts(source)
        let targetCounts = placeholderCounts(target)
        var diagnostics: [String] = []

        for identity in sourceCounts.keys.sorted() where targetCounts[identity] == nil {
            diagnostics.append("Target is missing required placeholder \(identity).")
        }
        for identity in targetCounts.keys.sorted() where sourceCounts[identity] == nil {
            diagnostics.append("Target contains extra placeholder \(identity).")
        }
        for identity in sourceCounts.keys.sorted() {
            guard let sourceCount = sourceCounts[identity],
                  let targetCount = targetCounts[identity],
                  sourceCount != targetCount else {
                continue
            }
            diagnostics.append("Placeholder \(identity) count changed from \(sourceCount) to \(targetCount).")
        }

        return diagnostics
    }

    private static func placeholderCounts(_ placeholders: [FormatPlaceholder]) -> [String: Int] {
        placeholders.reduce(into: [:]) { result, placeholder in
            result[placeholder.validationIdentity, default: 0] += 1
        }
    }

    private static func issuesForInvalidValidation(
        _ validation: PlaceholderValidationResult,
        path: String
    ) -> [CatalogValidationIssue] {
        guard validation.checked, !validation.isValid else {
            return []
        }

        return validation.diagnostics.map { diagnostic in
            CatalogValidationIssue(
                code: "placeholder_mismatch",
                severity: .error,
                message: diagnostic,
                key: validation.key,
                language: validation.language,
                path: path
            )
        }
    }

    private static func validateVariationPlaceholders(
        key: String,
        language: String,
        sourceVariations: Variations?,
        targetVariations: Variations?,
        basePath: String
    ) -> (validations: [PlaceholderValidationResult], issues: [CatalogValidationIssue]) {
        var validations: [PlaceholderValidationResult] = []
        var issues = compareVariationShape(
            key: key,
            language: language,
            sourceVariations: sourceVariations,
            targetVariations: targetVariations,
            basePath: basePath
        )

        let sourceValues = variationValues(in: sourceVariations)
        let targetValues = variationValues(in: targetVariations)
        for identity in sourceValues.keys.sorted() {
            guard let sourceValue = sourceValues[identity],
                  let targetValue = targetValues[identity] else {
                continue
            }
            let validation = validatePlaceholderSet(
                key: key,
                language: language,
                sourceValue: sourceValue,
                targetValue: targetValue
            )
            if validation.checked {
                validations.append(validation)
            }
            issues.append(contentsOf: issuesForInvalidValidation(validation, path: "\(basePath).\(identity)"))
        }

        return (validations, issues)
    }

    private static func validateSubstitutionPlaceholders(
        key: String,
        language: String,
        sourceSubstitutions: OrderedStringDictionary<Substitution>?,
        targetSubstitutions: OrderedStringDictionary<Substitution>?
    ) -> (validations: [PlaceholderValidationResult], issues: [CatalogValidationIssue]) {
        let sourceNames = Set(sourceSubstitutions?.keys ?? [])
        let targetNames = Set(targetSubstitutions?.keys ?? [])
        var validations: [PlaceholderValidationResult] = []
        var issues: [CatalogValidationIssue] = []

        for missingName in sourceNames.subtracting(targetNames).sorted() {
            issues.append(CatalogValidationIssue(
                code: "substitution_missing",
                severity: .error,
                message: "Target localization is missing substitution '\(missingName)'.",
                key: key,
                language: language,
                path: "strings[\(quotedKey(key))].localizations.\(language).substitutions"
            ))
        }

        for extraName in targetNames.subtracting(sourceNames).sorted() {
            issues.append(CatalogValidationIssue(
                code: "substitution_extra",
                severity: .error,
                message: "Target localization contains extra substitution '\(extraName)'.",
                key: key,
                language: language,
                path: "strings[\(quotedKey(key))].localizations.\(language).substitutions"
            ))
        }

        for name in sourceNames.intersection(targetNames).sorted() {
            guard let source = sourceSubstitutions?[name],
                  let target = targetSubstitutions?[name] else {
                continue
            }

            if source.argNum != target.argNum {
                issues.append(CatalogValidationIssue(
                    code: "substitution_argnum_changed",
                    severity: .error,
                    message: "Substitution '\(name)' argNum changed from \(String(describing: source.argNum)) to \(String(describing: target.argNum)).",
                    key: key,
                    language: language,
                    path: "strings[\(quotedKey(key))].localizations.\(language).substitutions.\(name).argNum"
                ))
            }

            if source.formatSpecifier != target.formatSpecifier {
                issues.append(CatalogValidationIssue(
                    code: "substitution_format_specifier_changed",
                    severity: .error,
                    message: "Substitution '\(name)' formatSpecifier changed from \(String(describing: source.formatSpecifier)) to \(String(describing: target.formatSpecifier)).",
                    key: key,
                    language: language,
                    path: "strings[\(quotedKey(key))].localizations.\(language).substitutions.\(name).formatSpecifier"
                ))
            }

            let variationResult = validateVariationPlaceholders(
                key: key,
                language: language,
                sourceVariations: source.variations,
                targetVariations: target.variations,
                basePath: "strings[\(quotedKey(key))].localizations.\(language).substitutions.\(name).variations"
            )
            validations.append(contentsOf: variationResult.validations)
            issues.append(contentsOf: variationResult.issues)
        }

        return (validations, issues)
    }

    private static func compareVariationShape(
        key: String,
        language: String,
        sourceVariations: Variations?,
        targetVariations: Variations?,
        basePath: String
    ) -> [CatalogValidationIssue] {
        let sourceValues = variationValues(in: sourceVariations)
        let targetValues = variationValues(in: targetVariations)
        var issues: [CatalogValidationIssue] = []

        if sourceVariations != nil && targetVariations == nil {
            issues.append(CatalogValidationIssue(
                code: "variation_missing",
                severity: .error,
                message: "Source localization uses variations but target localization does not.",
                key: key,
                language: language,
                path: basePath
            ))
            return issues
        }

        for missing in Set(sourceValues.keys).subtracting(targetValues.keys).sorted() {
            issues.append(CatalogValidationIssue(
                code: "variation_category_missing",
                severity: .warning,
                message: "Target localization is missing variation category '\(missing)'.",
                key: key,
                language: language,
                path: basePath
            ))
        }

        for extra in Set(targetValues.keys).subtracting(sourceValues.keys).sorted() {
            issues.append(CatalogValidationIssue(
                code: "variation_category_extra",
                severity: .warning,
                message: "Target localization contains extra variation category '\(extra)'.",
                key: key,
                language: language,
                path: basePath
            ))
        }

        return issues
    }

    private static func validateRichRecordStructure(in file: XCStringsFile) -> [CatalogValidationIssue] {
        var issues: [CatalogValidationIssue] = []

        for key in file.strings.keys.sorted() {
            guard let entry = file.strings[key],
                  let localizations = entry.localizations else {
                continue
            }

            for language in localizations.keys.sorted() {
                guard let localization = localizations[language] else {
                    continue
                }

                if let substitutions = localization.substitutions {
                    let referencedNames = Set(FormatStringSafety.placeholders(in: localization.stringUnit?.value ?? "")
                        .filter { $0.kind == .stringsdictSubstitution }
                        .compactMap(\.name))
                    let declaredNames = Set(substitutions.keys)

                    for missingName in referencedNames.subtracting(declaredNames).sorted() {
                        issues.append(CatalogValidationIssue(
                            code: "referenced_substitution_missing",
                            severity: .error,
                            message: "String unit references substitution '\(missingName)' but the localization does not declare it.",
                            key: key,
                            language: language,
                            path: "strings[\(quotedKey(key))].localizations.\(language).substitutions"
                        ))
                    }

                    for unusedName in declaredNames.subtracting(referencedNames).sorted() {
                        issues.append(CatalogValidationIssue(
                            code: "substitution_not_referenced",
                            severity: .warning,
                            message: "Localization declares substitution '\(unusedName)' but the string unit does not reference it.",
                            key: key,
                            language: language,
                            path: "strings[\(quotedKey(key))].localizations.\(language).substitutions.\(unusedName)"
                        ))
                    }
                }

                if localization.variations != nil && variationValues(in: localization.variations).isEmpty {
                    issues.append(CatalogValidationIssue(
                        code: "variation_empty",
                        severity: .error,
                        message: "Localization declares variations but no variation values with string units.",
                        key: key,
                        language: language,
                        path: "strings[\(quotedKey(key))].localizations.\(language).variations"
                    ))
                }
            }
        }

        return issues
    }

    private static func richRecordSignatures(in file: XCStringsFile) -> [RichRecordSignature] {
        var signatures: [RichRecordSignature] = []

        for key in file.strings.keys.sorted() {
            guard let localizations = file.strings[key]?.localizations else {
                continue
            }

            for language in localizations.keys.sorted() {
                guard let localization = localizations[language],
                      localization.hasRichContent else {
                    continue
                }

                signatures.append(RichRecordSignature(
                    key: key,
                    language: language,
                    variationCategories: variationValues(in: localization.variations).keys.sorted(),
                    substitutionNames: localization.substitutions?.keys.sorted() ?? [],
                    substitutionSignatures: substitutionSignatures(in: localization.substitutions)
                ))
            }
        }

        return signatures
    }

    private static func substitutionSignatures(
        in substitutions: OrderedStringDictionary<Substitution>?
    ) -> [SubstitutionSignature] {
        guard let substitutions else {
            return []
        }

        return substitutions.keys.sorted().compactMap { name in
            guard let substitution = substitutions[name] else {
                return nil
            }
            return SubstitutionSignature(
                name: name,
                argNum: substitution.argNum,
                formatSpecifier: substitution.formatSpecifier,
                variationCategories: variationValues(in: substitution.variations).keys.sorted()
            )
        }
    }

    private static func validationLanguages(in file: XCStringsFile) -> [String] {
        var languages = Set([file.sourceLanguage])
        for (_, entry) in file.strings {
            guard let localizations = entry.localizations else {
                continue
            }
            languages.formUnion(localizations.keys)
        }
        return languages.sorted()
    }

    private static func variationValues(in variations: Variations?) -> [String: String] {
        guard let variations else {
            return [:]
        }

        var result: [String: String] = [:]
        if let plural = variations.plural {
            result.merge(variationValues(in: plural).reduce(into: [:]) { partial, element in
                partial["plural.\(element.category)"] = element.value
            }, uniquingKeysWith: { current, _ in current })
        }
        if let device = variations.device {
            result.merge(variationValues(in: device).reduce(into: [:]) { partial, element in
                partial["device.\(element.category)"] = element.value
            }, uniquingKeysWith: { current, _ in current })
        }
        return result
    }

    private static func variationValues(in plural: PluralVariation) -> [(category: String, value: String)] {
        [
            ("zero", plural.zero),
            ("one", plural.one),
            ("two", plural.two),
            ("few", plural.few),
            ("many", plural.many),
            ("other", plural.other),
        ].compactMap { category, variationValue in
            guard let value = variationValue?.stringUnit?.value else {
                return nil
            }
            return (category, value)
        }
    }

    private static func variationValues(in device: DeviceVariation) -> [(category: String, value: String)] {
        [
            ("iphone", device.iphone),
            ("ipad", device.ipad),
            ("mac", device.mac),
            ("applewatch", device.applewatch),
            ("appletv", device.appletv),
        ].compactMap { category, variationValue in
            guard let value = variationValue?.stringUnit?.value else {
                return nil
            }
            return (category, value)
        }
    }

    private static func suspiciousFindings(for key: String) -> [SuspiciousKeyFinding] {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return [
                SuspiciousKeyFinding(
                    key: key,
                    code: "empty_key",
                    severity: .error,
                    reason: "Empty or whitespace-only string catalog keys are usually accidental SwiftUI labels."
                )
            ]
        }

        var findings: [SuspiciousKeyFinding] = []
        let placeholders = FormatStringSafety.placeholders(in: trimmed)
        if !placeholders.isEmpty && isOnlyPunctuationOrSymbols(afterRemoving: placeholders, from: trimmed) {
            findings.append(SuspiciousKeyFinding(
                key: key,
                code: "format_only_key",
                severity: .warning,
                reason: "Key is only format placeholders plus punctuation; use verbatim runtime formatting or a descriptive localized key."
            ))
            return findings
        }

        if !trimmed.unicodeScalars.contains(where: { CharacterSet.alphanumerics.contains($0) }) {
            findings.append(SuspiciousKeyFinding(
                key: key,
                code: "punctuation_only_key",
                severity: .warning,
                reason: "Key contains no letters or numbers and is likely punctuation that should be rendered verbatim."
            ))
        }

        return findings
    }

    private static func isOnlyPunctuationOrSymbols(
        afterRemoving placeholders: [FormatPlaceholder],
        from value: String
    ) -> Bool {
        var remainder = value
        for placeholder in placeholders {
            remainder = remainder.replacingOccurrences(of: placeholder.raw, with: "")
        }

        let allowed = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)
            .union(.symbols)
        return remainder.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static func quotedKey(_ key: String) -> String {
        key.isEmpty ? "\"\"" : "\"\(key)\""
    }
}

private struct RichRecordSignature: Equatable {
    let key: String
    let language: String
    let variationCategories: [String]
    let substitutionNames: [String]
    let substitutionSignatures: [SubstitutionSignature]
}

private struct SubstitutionSignature: Equatable {
    let name: String
    let argNum: Int?
    let formatSpecifier: String?
    let variationCategories: [String]
}

private extension FormatPlaceholder {
    var validationIdentity: String {
        [
            kind.rawValue,
            position.map(String.init) ?? "",
            name ?? "",
            specifier,
        ].joined(separator: ":")
    }
}
