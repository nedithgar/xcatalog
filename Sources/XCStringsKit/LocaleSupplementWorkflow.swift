import Foundation

package struct LocaleSupplementTranslation: Codable, Sendable {
    package let key: String
    package let value: String

    package init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

package struct LocaleSupplementOptions: Codable, Sendable {
    package let language: String
    package let dryRun: Bool
    package let allowPartial: Bool
    package let overwrite: Bool
    package let validateCompile: Bool

    package init(
        language: String,
        dryRun: Bool = false,
        allowPartial: Bool = false,
        overwrite: Bool = false,
        validateCompile: Bool = false
    ) {
        self.language = language
        self.dryRun = dryRun
        self.allowPartial = allowPartial
        self.overwrite = overwrite
        self.validateCompile = validateCompile
    }
}

package typealias LocaleSupplementCompileValidator = @Sendable (XCStringsFile, String) -> LocaleSupplementCompileValidation

package enum LocaleSupplementAction: String, Codable, Sendable {
    case insert
    case update
    case skip
    case unchanged
    case unsafe
    case failed
}

package struct LocaleSupplementCounts: Codable, Sendable {
    package let total: Int
    package let inserted: Int
    package let updated: Int
    package let skipped: Int
    package let unchanged: Int
    package let unsafe: Int
    package let failed: Int

    package init(entries: [LocaleSupplementPlanEntry]) {
        self.total = entries.count
        self.inserted = entries.filter { $0.action == .insert }.count
        self.updated = entries.filter { $0.action == .update }.count
        self.skipped = entries.filter { $0.action == .skip }.count
        self.unchanged = entries.filter { $0.action == .unchanged }.count
        self.unsafe = entries.filter { $0.action == .unsafe }.count
        self.failed = entries.filter { $0.action == .failed }.count
    }
}

package struct LocaleSupplementPlanEntry: Codable, Sendable {
    package let key: String
    package let action: LocaleSupplementAction
    package let sourceValue: String?
    package let currentValue: String?
    package let proposedValue: String
    package let diagnostics: [String]
    package let placeholderValidation: PlaceholderValidationResult?

    package init(
        key: String,
        action: LocaleSupplementAction,
        sourceValue: String?,
        currentValue: String?,
        proposedValue: String,
        diagnostics: [String],
        placeholderValidation: PlaceholderValidationResult?
    ) {
        self.key = key
        self.action = action
        self.sourceValue = sourceValue
        self.currentValue = currentValue
        self.proposedValue = proposedValue
        self.diagnostics = diagnostics
        self.placeholderValidation = placeholderValidation
    }
}

package struct LocaleSupplementPlan: Codable, Sendable {
    package let sourceLanguage: String
    package let targetLanguage: String
    package let dryRun: Bool
    package let allowPartial: Bool
    package let overwrite: Bool
    package let validateCompile: Bool
    package let entries: [LocaleSupplementPlanEntry]
    package let counts: LocaleSupplementCounts
    package let placeholderValidations: [PlaceholderValidationResult]

    package init(
        sourceLanguage: String,
        targetLanguage: String,
        dryRun: Bool,
        allowPartial: Bool,
        overwrite: Bool,
        validateCompile: Bool,
        entries: [LocaleSupplementPlanEntry]
    ) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.dryRun = dryRun
        self.allowPartial = allowPartial
        self.overwrite = overwrite
        self.validateCompile = validateCompile
        self.entries = entries
        self.counts = LocaleSupplementCounts(entries: entries)
        self.placeholderValidations = entries.compactMap(\.placeholderValidation).filter(\.checked)
    }

    package var hasBlockingDiagnostics: Bool {
        counts.unsafe > 0 || counts.failed > 0
    }

    package var hasWritableChanges: Bool {
        counts.inserted > 0 || counts.updated > 0
    }

    package var canWrite: Bool {
        hasWritableChanges && !dryRun && (!hasBlockingDiagnostics || allowPartial)
    }

    package var wouldWriteIfNotDryRun: Bool {
        hasWritableChanges && (!hasBlockingDiagnostics || allowPartial)
    }
}

package enum LocaleSupplementStatus: String, Codable, Sendable {
    case dryRun
    case written
    case partialWritten
    case unchanged
    case refused
    case compileFailed
}

package enum LocaleSupplementCompileStatus: String, Codable, Sendable {
    case notRequested
    case notRunDueToBlockingDiagnostics
    case passed
    case failed
    case unavailable
}

package struct LocaleSupplementCompileValidation: Codable, Sendable {
    package let status: LocaleSupplementCompileStatus
    package let command: [String]
    package let diagnostics: String?

    package init(
        status: LocaleSupplementCompileStatus,
        command: [String] = [],
        diagnostics: String? = nil
    ) {
        self.status = status
        self.command = command
        self.diagnostics = diagnostics
    }

    package static var notRequested: LocaleSupplementCompileValidation {
        LocaleSupplementCompileValidation(status: .notRequested)
    }
}

package struct LocaleSupplementPreservation: Codable, Sendable {
    package let formattingAndOrderPreserved: Bool
    package let existingStringOrderPreserved: Bool
    package let existingLocalizationOrderPreserved: Bool
    package let trailingNewlinePreservedOnSave: Bool

    package init(
        formattingAndOrderPreserved: Bool = true,
        existingStringOrderPreserved: Bool = true,
        existingLocalizationOrderPreserved: Bool = true,
        trailingNewlinePreservedOnSave: Bool = true
    ) {
        self.formattingAndOrderPreserved = formattingAndOrderPreserved
        self.existingStringOrderPreserved = existingStringOrderPreserved
        self.existingLocalizationOrderPreserved = existingLocalizationOrderPreserved
        self.trailingNewlinePreservedOnSave = trailingNewlinePreservedOnSave
    }
}

package struct LocaleSupplementResult: Codable, Sendable {
    package let status: LocaleSupplementStatus
    package let success: Bool
    package let fileChanged: Bool
    package let wouldWrite: Bool
    package let compileValidationRanOnProjectedCatalog: Bool
    package let plan: LocaleSupplementPlan
    package let counts: LocaleSupplementCounts
    package let placeholderValidations: [PlaceholderValidationResult]
    package let compileValidation: LocaleSupplementCompileValidation
    package let preservation: LocaleSupplementPreservation
    package let diagnostics: [String]

    package init(
        status: LocaleSupplementStatus,
        fileChanged: Bool,
        plan: LocaleSupplementPlan,
        compileValidation: LocaleSupplementCompileValidation = .notRequested,
        compileValidationRanOnProjectedCatalog: Bool = false,
        preservation: LocaleSupplementPreservation = LocaleSupplementPreservation(),
        diagnostics: [String] = []
    ) {
        self.status = status
        self.success = Self.isSuccessful(
            status: status,
            plan: plan,
            compileValidation: compileValidation
        )
        self.fileChanged = fileChanged
        self.wouldWrite = plan.wouldWriteIfNotDryRun
        self.compileValidationRanOnProjectedCatalog = compileValidationRanOnProjectedCatalog
        self.plan = plan
        self.counts = plan.counts
        self.placeholderValidations = plan.placeholderValidations
        self.compileValidation = compileValidation
        self.preservation = preservation
        self.diagnostics = diagnostics
    }

    private static func isSuccessful(
        status: LocaleSupplementStatus,
        plan: LocaleSupplementPlan,
        compileValidation: LocaleSupplementCompileValidation
    ) -> Bool {
        guard status != .refused && status != .compileFailed else {
            return false
        }

        guard compileValidation.status != .failed,
              compileValidation.status != .unavailable,
              compileValidation.status != .notRunDueToBlockingDiagnostics else {
            return false
        }

        guard !(status == .dryRun && plan.hasBlockingDiagnostics && !plan.allowPartial) else {
            return false
        }

        guard !(status == .dryRun && plan.hasBlockingDiagnostics && !plan.hasWritableChanges) else {
            return false
        }

        return true
    }
}

enum XCStringsLocaleSupplementer {
    static func plan(
        file: XCStringsFile,
        translations: [LocaleSupplementTranslation],
        options: LocaleSupplementOptions
    ) -> LocaleSupplementPlan {
        let entries = translations
            .sorted { $0.key < $1.key }
            .map { planEntry(file: file, translation: $0, options: options) }

        return LocaleSupplementPlan(
            sourceLanguage: file.sourceLanguage,
            targetLanguage: options.language,
            dryRun: options.dryRun,
            allowPartial: options.allowPartial,
            overwrite: options.overwrite,
            validateCompile: options.validateCompile,
            entries: entries
        )
    }

    static func apply(plan: LocaleSupplementPlan, to file: XCStringsFile) -> XCStringsFile {
        var result = file

        for entry in plan.entries where entry.action == .insert || entry.action == .update {
            guard var stringEntry = result.strings[entry.key] else {
                continue
            }

            if stringEntry.localizations == nil {
                stringEntry.localizations = [:]
            }

            switch entry.action {
            case .insert, .update:
                var localization = stringEntry.localizations?[plan.targetLanguage] ?? Localization()
                localization.stringUnit = StringUnit(
                    state: localization.stringUnit?.state ?? "translated",
                    value: entry.proposedValue,
                    unknownFields: localization.stringUnit?.unknownFields ?? [:]
                )
                stringEntry.localizations?[plan.targetLanguage] = localization
            case .skip, .unchanged, .unsafe, .failed:
                break
            }
            result.strings[entry.key] = stringEntry
        }

        return result
    }

    private static func planEntry(
        file: XCStringsFile,
        translation: LocaleSupplementTranslation,
        options: LocaleSupplementOptions
    ) -> LocaleSupplementPlanEntry {
        guard let entry = file.strings[translation.key] else {
            return LocaleSupplementPlanEntry(
                key: translation.key,
                action: .failed,
                sourceValue: nil,
                currentValue: nil,
                proposedValue: translation.value,
                diagnostics: ["Key not found in catalog."],
                placeholderValidation: nil
            )
        }

        let sourceLocalization = entry.localizations?[file.sourceLanguage]
        let targetLocalization = entry.localizations?[options.language]
        let sourceValue = sourceLocalization?.stringUnit?.value ?? translation.key
        let currentValue = targetLocalization?.stringUnit?.value

        guard entry.requiresTranslation else {
            return LocaleSupplementPlanEntry(
                key: translation.key,
                action: .unsafe,
                sourceValue: sourceValue,
                currentValue: currentValue,
                proposedValue: translation.value,
                diagnostics: ["Key is marked shouldTranslate=false."],
                placeholderValidation: nil
            )
        }

        guard sourceLocalization?.hasRichContent != true,
              targetLocalization?.hasRichContent != true else {
            return LocaleSupplementPlanEntry(
                key: translation.key,
                action: .unsafe,
                sourceValue: sourceValue,
                currentValue: currentValue,
                proposedValue: translation.value,
                diagnostics: ["Source or target localization uses variations or substitutions; plain stringUnit supplement is unsafe."],
                placeholderValidation: nil
            )
        }

        let validation = FormatStringSafety.validate(
            key: translation.key,
            language: options.language,
            sourceValue: sourceValue,
            targetValue: translation.value
        )

        guard validation.isValid else {
            return LocaleSupplementPlanEntry(
                key: translation.key,
                action: .unsafe,
                sourceValue: sourceValue,
                currentValue: currentValue,
                proposedValue: translation.value,
                diagnostics: validation.diagnostics,
                placeholderValidation: validation
            )
        }

        if currentValue == translation.value {
            return LocaleSupplementPlanEntry(
                key: translation.key,
                action: .unchanged,
                sourceValue: sourceValue,
                currentValue: currentValue,
                proposedValue: translation.value,
                diagnostics: ["Existing target value already matches proposed value."],
                placeholderValidation: validation
            )
        }

        if currentValue != nil && !options.overwrite {
            return LocaleSupplementPlanEntry(
                key: translation.key,
                action: .skip,
                sourceValue: sourceValue,
                currentValue: currentValue,
                proposedValue: translation.value,
                diagnostics: ["Target localization already exists; pass overwrite=true to update it."],
                placeholderValidation: validation
            )
        }

        return LocaleSupplementPlanEntry(
            key: translation.key,
            action: currentValue == nil ? .insert : .update,
            sourceValue: sourceValue,
            currentValue: currentValue,
            proposedValue: translation.value,
            diagnostics: [],
            placeholderValidation: validation
        )
    }
}
