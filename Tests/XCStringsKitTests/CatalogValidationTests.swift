import Foundation
import Testing
@testable import XCStringsKit

@Suite("Catalog validation tools")
struct CatalogValidationTests {
    @Test("validateCatalog accepts valid rich catalog and reports rich preservation")
    func validateCatalogAcceptsValidRichCatalog() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.withSubstitutions)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = await parser.validateCatalog()

        #expect(report.success)
        #expect(report.jsonParseable)
        #expect(report.modelDecodable)
        #expect(report.compileValidation.status == .notRequested)
        #expect(report.richRecordReport?.richLocalizationCount == 1)
        #expect(report.richRecordReport?.roundTripPreserved == true)
        #expect(report.summary.errorCount == 0)
    }

    @Test("validateCatalog reports invalid JSON without throwing")
    func validateCatalogReportsInvalidJSON() async throws {
        let path = try TestHelper.createTempFile(content: "{ invalid json }")
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = await parser.validateCatalog()

        #expect(!report.success)
        #expect(!report.jsonParseable)
        #expect(!report.modelDecodable)
        #expect(report.issues.map(\.code).contains("json_parse_failed"))
    }

    @Test("validatePlaceholders reports mismatched translated placeholders")
    func validatePlaceholdersReportsMismatch() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithBrokenFormatTranslation)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = try await parser.validatePlaceholders()

        #expect(!report.success)
        #expect(report.summary.checkedTranslations == 1)
        #expect(report.summary.invalidTranslations == 1)
        #expect(report.issues.map(\.code) == ["placeholder_mismatch"])
        #expect(report.issues.first?.key == "format.bad")
        #expect(report.issues.first?.language == "es")
    }

    @Test("validatePlaceholders uses key text when source localization is absent")
    func validatePlaceholdersUsesKeyTextWhenSourceLocalizationIsAbsent() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithMissingSourceFormatTranslation)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = try await parser.validatePlaceholders()

        #expect(!report.success)
        #expect(report.summary.checkedTranslations == 1)
        #expect(report.summary.invalidTranslations == 1)
        #expect(report.issues.map(\.code) == ["placeholder_mismatch"])
        #expect(report.issues.first?.key == "Items: %lld")
        #expect(report.validations.first?.sourceValue == "Items: %lld")
    }

    @Test("validateCatalog uses key text when source localization is absent")
    func validateCatalogUsesKeyTextWhenSourceLocalizationIsAbsent() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithMissingSourceFormatTranslation)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = await parser.validateCatalog()
        let placeholderReport = try #require(report.placeholderReport)

        #expect(!report.success)
        #expect(placeholderReport.summary.checkedTranslations == 1)
        #expect(placeholderReport.summary.invalidTranslations == 1)
        #expect(report.issues.contains { $0.code == "placeholder_mismatch" && $0.key == "Items: %lld" })
    }

    @Test("validatePlaceholders uses key text when source localization is an empty shell")
    func validatePlaceholdersUsesKeyTextWhenSourceLocalizationIsEmptyShell() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithEmptySourceShellFormatTranslation)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = try await parser.validatePlaceholders()

        #expect(!report.success)
        #expect(report.summary.checkedTranslations == 1)
        #expect(report.summary.invalidTranslations == 1)
        #expect(report.issues.map(\.code) == ["placeholder_mismatch"])
        #expect(report.issues.first?.key == "Items: %lld")
        #expect(report.validations.first?.sourceValue == "Items: %lld")
    }

    @Test("validatePlaceholders accepts key-derived rich placeholders when source localization is absent")
    func validatePlaceholdersAcceptsKeyDerivedRichPlaceholderWhenSourceLocalizationIsAbsent() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithMissingSourceRichSubstitution)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = try await parser.validatePlaceholders()

        #expect(report.success)
        #expect(report.summary.checkedTranslations == 1)
        #expect(report.summary.invalidTranslations == 0)
        #expect(report.issues.isEmpty)
    }

    @Test("validatePlaceholders accepts key-derived rich placeholders when source localization is an empty shell")
    func validatePlaceholdersAcceptsKeyDerivedRichPlaceholderWhenSourceLocalizationIsEmptyShell() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithEmptySourceShellRichSubstitution)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = try await parser.validatePlaceholders()

        #expect(report.success)
        #expect(report.summary.checkedTranslations == 1)
        #expect(report.summary.invalidTranslations == 0)
        #expect(report.issues.isEmpty)
    }

    @Test("validateCatalog uses key text when source localization is an empty shell")
    func validateCatalogUsesKeyTextWhenSourceLocalizationIsEmptyShell() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithEmptySourceShellFormatTranslation)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = await parser.validateCatalog()
        let placeholderReport = try #require(report.placeholderReport)

        #expect(!report.success)
        #expect(placeholderReport.summary.checkedTranslations == 1)
        #expect(placeholderReport.summary.invalidTranslations == 1)
        #expect(report.issues.contains { $0.code == "placeholder_mismatch" && $0.key == "Items: %lld" })
    }

    @Test("validatePlaceholders uses key text for target-only variations")
    func validatePlaceholdersUsesKeyTextForTargetOnlyVariations() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithMissingSourceTargetOnlyVariation)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = try await parser.validatePlaceholders()

        #expect(!report.success)
        #expect(report.summary.checkedTranslations == 2)
        #expect(report.summary.invalidTranslations == 2)
        #expect(report.issues.map(\.code) == ["placeholder_mismatch", "placeholder_mismatch"])
        #expect(report.issues.map(\.path).contains("strings[\"%lld items\"].localizations.es.variations.plural.one"))
        #expect(report.issues.map(\.path).contains("strings[\"%lld items\"].localizations.es.variations.plural.other"))
        #expect(report.validations.allSatisfy { $0.sourceValue == "%lld items" })
    }

    @Test("validateCatalog uses key text for target-only variations")
    func validateCatalogUsesKeyTextForTargetOnlyVariations() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithMissingSourceTargetOnlyVariation)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = await parser.validateCatalog()
        let placeholderReport = try #require(report.placeholderReport)

        #expect(!report.success)
        #expect(placeholderReport.summary.checkedTranslations == 2)
        #expect(placeholderReport.summary.invalidTranslations == 2)
        #expect(report.issues.count == 2)
        #expect(report.issues.allSatisfy { $0.code == "placeholder_mismatch" && $0.key == "%lld items" })
    }

    @Test("validatePlaceholders accepts target-only variations that preserve key placeholders")
    func validatePlaceholdersAcceptsTargetOnlyVariationsThatPreserveKeyPlaceholders() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithValidMissingSourceTargetOnlyVariation)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = try await parser.validatePlaceholders()

        #expect(report.success)
        #expect(report.summary.checkedTranslations == 2)
        #expect(report.summary.invalidTranslations == 0)
        #expect(report.issues.isEmpty)
    }

    @Test("validatePlaceholders checks target-only variations against concrete source string unit")
    func validatePlaceholdersChecksTargetOnlyVariationsAgainstConcreteSourceStringUnit() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithConcreteSourceTargetOnlyVariation)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = try await parser.validatePlaceholders()

        #expect(!report.success)
        #expect(report.summary.checkedTranslations == 2)
        #expect(report.summary.invalidTranslations == 2)
        #expect(report.issues.map(\.code) == ["placeholder_mismatch", "placeholder_mismatch"])
        #expect(report.issues.map(\.path).contains("strings[\"item.count\"].localizations.es.variations.plural.one"))
        #expect(report.issues.map(\.path).contains("strings[\"item.count\"].localizations.es.variations.plural.other"))
        #expect(report.validations.allSatisfy { $0.sourceValue == "%lld items" })
    }

    @Test("validatePlaceholders accepts target-only variations that preserve concrete source string unit placeholders")
    func validatePlaceholdersAcceptsTargetOnlyVariationsThatPreserveConcreteSourceStringUnitPlaceholders() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithValidConcreteSourceTargetOnlyVariation)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = try await parser.validatePlaceholders()

        #expect(report.success)
        #expect(report.summary.checkedTranslations == 2)
        #expect(report.summary.invalidTranslations == 0)
        #expect(report.issues.isEmpty)
        #expect(report.validations.allSatisfy { $0.sourceValue == "%lld items" })
    }

    @Test("validatePlaceholders treats empty source variations as target-only variations")
    func validatePlaceholdersTreatsEmptySourceVariationsAsTargetOnlyVariations() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithEmptySourceVariationTargetOnlyVariation)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = try await parser.validatePlaceholders()

        #expect(!report.success)
        #expect(report.summary.checkedTranslations == 2)
        #expect(report.summary.invalidTranslations == 2)
        #expect(report.issues.map(\.code) == ["placeholder_mismatch", "placeholder_mismatch"])
        #expect(report.issues.map(\.path).contains("strings[\"item.count\"].localizations.es.variations.plural.one"))
        #expect(report.issues.map(\.path).contains("strings[\"item.count\"].localizations.es.variations.plural.other"))
        #expect(report.validations.allSatisfy { $0.sourceValue == "%lld items" })
    }

    @Test("validatePlaceholders prefers explicit source localization over key text")
    func validatePlaceholdersPrefersExplicitSourceLocalizationOverKeyText() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithExplicitSourceValueDifferentFromKey)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = try await parser.validatePlaceholders()

        #expect(report.success)
        #expect(report.summary.checkedTranslations == 0)
        #expect(report.summary.invalidTranslations == 0)
    }

    @Test("validatePlaceholders checks substitution variation placeholders")
    func validatePlaceholdersChecksSubstitutionVariationValues() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithBrokenSubstitutionTranslation)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = try await parser.validatePlaceholders()

        #expect(!report.success)
        #expect(report.issues.contains { $0.code == "placeholder_mismatch" && $0.key == "items.count" })
        #expect(report.validations.contains { !$0.isValid && $0.sourcePlaceholders.map(\.raw) == ["%arg"] })
    }

    @Test("validatePlaceholders rejects rich strings with reordered non-positional printf placeholders")
    func validatePlaceholdersRejectsRichNonPositionalPrintfReorder() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithRichNonPositionalPrintfReorder)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = try await parser.validatePlaceholders()
        let invalidValidation = try #require(report.validations.first { !$0.isValid })

        #expect(!report.success)
        #expect(report.summary.checkedTranslations == 3)
        #expect(report.summary.invalidTranslations == 1)
        #expect(report.issues.map(\.code) == ["placeholder_mismatch"])
        #expect(invalidValidation.sourcePlaceholders.map(\.raw) == ["%#@itemCount@", "%@", "%lld"])
        #expect(invalidValidation.targetPlaceholders.map(\.raw) == ["%#@itemCount@", "%lld", "%@"])
        #expect(invalidValidation.diagnostics.contains {
            $0.contains("Target must keep non-positional rich and printf placeholders in source argument order")
        })
    }

    @Test("validatePlaceholders accepts rich strings that reorder positional printf placeholders")
    func validatePlaceholdersAcceptsRichPositionalPrintfReorder() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithRichPositionalPrintfReorder)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = try await parser.validatePlaceholders()

        #expect(report.success)
        #expect(report.summary.checkedTranslations == 3)
        #expect(report.summary.invalidTranslations == 0)
        #expect(report.issues.isEmpty)
    }

    @Test("validatePlaceholders respects argNum for rich-only substitution reorders")
    func validatePlaceholdersRespectsArgNumForRichOnlySubstitutionReorders() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithRichOnlySubstitutionReorder)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = try await parser.validatePlaceholders()

        #expect(report.success)
        #expect(report.summary.checkedTranslations == 5)
        #expect(report.summary.invalidTranslations == 0)
        #expect(report.issues.isEmpty)
    }

    @Test("validatePlaceholders rejects positional printf indexes that collide with rich substitutions")
    func validatePlaceholdersRejectsRichImplicitSourceToCollidingPositionalTargetPrintfReorder() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithRichImplicitSourceToCollidingPositionalTargetPrintfReorder)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = try await parser.validatePlaceholders()
        let invalidValidation = try #require(report.validations.first { !$0.isValid })

        #expect(!report.success)
        #expect(report.summary.checkedTranslations == 3)
        #expect(report.summary.invalidTranslations == 1)
        #expect(report.issues.allSatisfy { $0.code == "placeholder_mismatch" })
        #expect(invalidValidation.diagnostics.contains {
            $0.contains("Rich argument %1$ has extra placeholders")
        })
    }

    @Test("validatePlaceholders accepts rich implicit source reordered with noncolliding positional target")
    func validatePlaceholdersAcceptsRichImplicitSourceToNoncollidingPositionalTargetPrintfReorder() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithRichImplicitSourceToNoncollidingPositionalTargetPrintfReorder)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = try await parser.validatePlaceholders()

        #expect(report.success)
        #expect(report.summary.checkedTranslations == 3)
        #expect(report.summary.invalidTranslations == 0)
        #expect(report.issues.isEmpty)
    }

    @Test("validatePlaceholders rejects reordered non-positional rich and printf placeholders")
    func validatePlaceholdersRejectsReorderedNonPositionalRichAndPrintfPlaceholders() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithReorderedNonPositionalRichAndPrintfPlaceholders)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = try await parser.validatePlaceholders()
        let invalidValidation = try #require(report.validations.first { !$0.isValid })

        #expect(!report.success)
        #expect(report.summary.checkedTranslations == 3)
        #expect(report.summary.invalidTranslations == 1)
        #expect(report.issues.map(\.code) == ["placeholder_mismatch"])
        #expect(invalidValidation.diagnostics.contains {
            $0.contains("Target must keep non-positional rich and printf placeholders in source argument order")
        })
    }

    @Test("validatePlaceholders rejects substitution variation printf indexes that collide with percent arg")
    func validatePlaceholdersRejectsSubstitutionVariationPrintfIndexCollidingWithPercentArg() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithSubstitutionVariationPrintfCollision)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = try await parser.validatePlaceholders()
        let invalidValidation = try #require(report.validations.first { !$0.isValid })

        #expect(!report.success)
        #expect(report.summary.checkedTranslations == 3)
        #expect(report.summary.invalidTranslations == 1)
        #expect(report.issues.allSatisfy { $0.code == "placeholder_mismatch" })
        #expect(invalidValidation.diagnostics.contains {
            $0.contains("Rich argument %1$ has extra placeholders")
        })
    }

    @Test("validatePlaceholders accepts substitution variation positional printf after percent arg")
    func validatePlaceholdersAcceptsSubstitutionVariationPositionalPrintfAfterPercentArg() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithValidSubstitutionVariationPositionalPrintf)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = try await parser.validatePlaceholders()

        #expect(report.success)
        #expect(report.summary.checkedTranslations == 3)
        #expect(report.summary.invalidTranslations == 0)
        #expect(report.issues.isEmpty)
    }

    @Test("validatePlaceholders reports missing rich printf placeholders once")
    func validatePlaceholdersReportsMissingRichPrintfPlaceholderOnce() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithDroppedRichPrintfPlaceholder)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = try await parser.validatePlaceholders()
        let invalidValidation = try #require(report.validations.first { !$0.isValid })

        #expect(!report.success)
        #expect(report.summary.checkedTranslations == 3)
        #expect(report.summary.invalidTranslations == 1)
        #expect(report.issues.count == 1)
        #expect(report.issues.map(\.code) == ["placeholder_mismatch"])
        #expect(invalidValidation.diagnostics.count == 1)
        #expect(invalidValidation.diagnostics.first?.contains("Target must keep non-positional rich and printf placeholders") == true)
    }

    @Test("validatePlaceholders accepts repeated positional dynamic width arguments")
    func validatePlaceholdersAcceptsRepeatedPositionalDynamicWidthArguments() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithRepeatedPositionalDynamicWidth)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = try await parser.validatePlaceholders()

        #expect(report.success)
        #expect(report.summary.checkedTranslations == 1)
        #expect(report.summary.invalidTranslations == 0)
    }

    @Test("validatePlaceholders ignores literal percent copy before ordinary words")
    func validatePlaceholdersIgnoresLiteralPercentCopyBeforeOrdinaryWords() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithLiteralPercentCopy)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = try await parser.validatePlaceholders()

        #expect(report.success)
        #expect(report.summary.checkedTranslations == 0)
        #expect(report.summary.invalidTranslations == 0)
    }

    @Test("validatePlaceholders reports dropped space-flagged suffix placeholder")
    func validatePlaceholdersReportsDroppedSpaceFlaggedSuffixPlaceholder() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithDroppedSpaceFlaggedSuffixPlaceholder)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = try await parser.validatePlaceholders()

        #expect(!report.success)
        #expect(report.summary.checkedTranslations == 1)
        #expect(report.summary.invalidTranslations == 1)
        #expect(report.issues.map(\.code) == ["placeholder_mismatch"])
        #expect(report.issues.first?.key == "sample")
    }

    @Test("validateCatalog reports malformed rich substitution records")
    func validateCatalogReportsMalformedRichSubstitution() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithMissingSubstitutionDeclaration)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = await parser.validateCatalog()

        #expect(!report.success)
        #expect(report.richRecordReport?.success == false)
        #expect(report.issues.contains { $0.code == "referenced_substitution_missing" })
        #expect(report.issues.contains { $0.code == "substitution_not_referenced" })
    }

    @Test("validateCatalog reports omitted rich substitution declarations")
    func validateCatalogReportsOmittedRichSubstitutionDeclarations() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithOmittedSubstitutionDeclaration)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = await parser.validateCatalog()
        let issue = try #require(report.issues.first { $0.code == "referenced_substitution_missing" })

        #expect(!report.success)
        #expect(report.richRecordReport?.success == false)
        #expect(report.richRecordReport?.richLocalizationCount == 1)
        #expect(issue.key == "items.count")
        #expect(issue.language == "en")
        #expect(issue.path == "strings[\"items.count\"].localizations.en.substitutions")
        #expect(!report.issues.contains { $0.code == "substitution_not_referenced" })
    }

    @Test("compact validation report keeps summary and short issue list")
    func compactValidationReportKeepsSummaryAndShortIssueList() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithMissingSubstitutionDeclaration)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = await parser.validateCatalog()
        let compact = report.compact(issueLimit: 1)

        #expect(compact.success == false)
        #expect(compact.file == path)
        #expect(compact.compileValidationStatus == .notRequested)
        #expect(compact.summary.issueCount == 2)
        #expect(compact.summary.errorCount == 1)
        #expect(compact.summary.richLocalizationCount == 1)
        #expect(compact.issues.count == 1)
        #expect(compact.issues.first?.code == "referenced_substitution_missing")
        #expect(compact.truncatedIssueCount == 1)
    }

    @Test("findSuspiciousKeys reports empty punctuation-only and format-only keys")
    func findSuspiciousKeysReportsAccidentalKeys() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithSuspiciousKeys)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = try await parser.findSuspiciousKeys()

        #expect(!report.success)
        #expect(report.findings.map(\.key) == ["", "(%@)", "/"])
        #expect(report.findings.map(\.code).contains("empty_key"))
        #expect(report.findings.map(\.code).contains("format_only_key"))
        #expect(report.findings.map(\.code).contains("punctuation_only_key"))
    }

    @Test("findSuspiciousKeys reports dynamic printf-only keys")
    func findSuspiciousKeysReportsDynamicPrintfOnlyKeys() async throws {
        let path = try TestHelper.createTempFile(content: Self.catalogWithDynamicPrintfOnlyKeys)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let report = try await parser.findSuspiciousKeys()

        #expect(report.success)
        #expect(report.findings.map(\.key) == ["%*.*f", "(%*.*f)"])
        #expect(report.findings.allSatisfy { $0.code == "format_only_key" })
    }

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

    private static let catalogWithMissingSourceFormatTranslation = """
    {
      "sourceLanguage": "en",
      "strings": {
        "Items: %lld": {
          "localizations": {
            "es": {
              "stringUnit": {
                "state": "translated",
                "value": "Elementos"
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private static let catalogWithEmptySourceShellFormatTranslation = """
    {
      "sourceLanguage": "en",
      "strings": {
        "Items: %lld": {
          "localizations": {
            "en": {},
            "es": {
              "stringUnit": {
                "state": "translated",
                "value": "Elementos"
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private static let catalogWithMissingSourceRichSubstitution = """
    {
      "sourceLanguage": "en",
      "strings": {
        "%#@itemCount@": {
          "localizations": {
            "es": {
              "stringUnit": {
                "state": "translated",
                "value": "%#@itemCount@"
              },
              "substitutions": {
                "itemCount": {
                  "argNum": 1,
                  "formatSpecifier": "lld",
                  "variations": {
                    "plural": {
                      "one": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "elemento compartido"
                        }
                      },
                      "other": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg elementos compartidos"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private static let catalogWithEmptySourceShellRichSubstitution = """
    {
      "sourceLanguage": "en",
      "strings": {
        "%#@itemCount@": {
          "localizations": {
            "en": {},
            "es": {
              "stringUnit": {
                "state": "translated",
                "value": "%#@itemCount@"
              },
              "substitutions": {
                "itemCount": {
                  "argNum": 1,
                  "formatSpecifier": "lld",
                  "variations": {
                    "plural": {
                      "one": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "elemento compartido"
                        }
                      },
                      "other": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg elementos compartidos"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private static let catalogWithMissingSourceTargetOnlyVariation = """
    {
      "sourceLanguage": "en",
      "strings": {
        "%lld items": {
          "localizations": {
            "es": {
              "variations": {
                "plural": {
                  "one": {
                    "stringUnit": {
                      "state": "translated",
                      "value": "elemento"
                    }
                  },
                  "other": {
                    "stringUnit": {
                      "state": "translated",
                      "value": "elementos"
                    }
                  }
                }
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private static let catalogWithValidMissingSourceTargetOnlyVariation = """
    {
      "sourceLanguage": "en",
      "strings": {
        "%lld items": {
          "localizations": {
            "es": {
              "variations": {
                "plural": {
                  "one": {
                    "stringUnit": {
                      "state": "translated",
                      "value": "%lld elemento"
                    }
                  },
                  "other": {
                    "stringUnit": {
                      "state": "translated",
                      "value": "%lld elementos"
                    }
                  }
                }
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private static let catalogWithConcreteSourceTargetOnlyVariation = """
    {
      "sourceLanguage": "en",
      "strings": {
        "item.count": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "%lld items"
              }
            },
            "es": {
              "variations": {
                "plural": {
                  "one": {
                    "stringUnit": {
                      "state": "translated",
                      "value": "elemento"
                    }
                  },
                  "other": {
                    "stringUnit": {
                      "state": "translated",
                      "value": "elementos"
                    }
                  }
                }
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private static let catalogWithValidConcreteSourceTargetOnlyVariation = """
    {
      "sourceLanguage": "en",
      "strings": {
        "item.count": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "%lld items"
              }
            },
            "es": {
              "variations": {
                "plural": {
                  "one": {
                    "stringUnit": {
                      "state": "translated",
                      "value": "%lld elemento"
                    }
                  },
                  "other": {
                    "stringUnit": {
                      "state": "translated",
                      "value": "%lld elementos"
                    }
                  }
                }
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private static let catalogWithEmptySourceVariationTargetOnlyVariation = """
    {
      "sourceLanguage": "en",
      "strings": {
        "item.count": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "%lld items"
              },
              "variations": {}
            },
            "es": {
              "variations": {
                "plural": {
                  "one": {
                    "stringUnit": {
                      "state": "translated",
                      "value": "elemento"
                    }
                  },
                  "other": {
                    "stringUnit": {
                      "state": "translated",
                      "value": "elementos"
                    }
                  }
                }
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private static let catalogWithExplicitSourceValueDifferentFromKey = """
    {
      "sourceLanguage": "en",
      "strings": {
        "Items: %lld": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "Items"
              }
            },
            "es": {
              "stringUnit": {
                "state": "translated",
                "value": "Elementos"
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private static let catalogWithBrokenSubstitutionTranslation = """
    {
      "sourceLanguage": "en",
      "strings": {
        "items.count": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "%#@itemCount@"
              },
              "substitutions": {
                "itemCount": {
                  "argNum": 1,
                  "formatSpecifier": "lld",
                  "variations": {
                    "plural": {
                      "one": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg item"
                        }
                      },
                      "other": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg items"
                        }
                      }
                    }
                  }
                }
              }
            },
            "es": {
              "stringUnit": {
                "state": "translated",
                "value": "%#@itemCount@"
              },
              "substitutions": {
                "itemCount": {
                  "argNum": 1,
                  "formatSpecifier": "lld",
                  "variations": {
                    "plural": {
                      "one": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "elemento"
                        }
                      },
                      "other": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg elementos"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private static let catalogWithRichNonPositionalPrintfReorder = """
    {
      "sourceLanguage": "en",
      "strings": {
        "items.summary": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "%#@itemCount@ %@ %lld"
              },
              "substitutions": {
                "itemCount": {
                  "argNum": 1,
                  "formatSpecifier": "lld",
                  "variations": {
                    "plural": {
                      "one": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg item"
                        }
                      },
                      "other": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg items"
                        }
                      }
                    }
                  }
                }
              }
            },
            "es": {
              "stringUnit": {
                "state": "translated",
                "value": "%#@itemCount@ %lld %@"
              },
              "substitutions": {
                "itemCount": {
                  "argNum": 1,
                  "formatSpecifier": "lld",
                  "variations": {
                    "plural": {
                      "one": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg elemento"
                        }
                      },
                      "other": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg elementos"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private static let catalogWithRichPositionalPrintfReorder = """
    {
      "sourceLanguage": "en",
      "strings": {
        "items.summary": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "%#@itemCount@ %2$@ %3$lld"
              },
              "substitutions": {
                "itemCount": {
                  "argNum": 1,
                  "formatSpecifier": "lld",
                  "variations": {
                    "plural": {
                      "one": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg item"
                        }
                      },
                      "other": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg items"
                        }
                      }
                    }
                  }
                }
              }
            },
            "es": {
              "stringUnit": {
                "state": "translated",
                "value": "%#@itemCount@ %3$lld %2$@"
              },
              "substitutions": {
                "itemCount": {
                  "argNum": 1,
                  "formatSpecifier": "lld",
                  "variations": {
                    "plural": {
                      "one": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg elemento"
                        }
                      },
                      "other": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg elementos"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private static let catalogWithRichImplicitSourceToCollidingPositionalTargetPrintfReorder = """
    {
      "sourceLanguage": "en",
      "strings": {
        "items.summary": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "%#@itemCount@ %@ %lld"
              },
              "substitutions": {
                "itemCount": {
                  "argNum": 1,
                  "formatSpecifier": "lld",
                  "variations": {
                    "plural": {
                      "one": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg item"
                        }
                      },
                      "other": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg items"
                        }
                      }
                    }
                  }
                }
              }
            },
            "es": {
              "stringUnit": {
                "state": "translated",
                "value": "%#@itemCount@ %2$lld %1$@"
              },
              "substitutions": {
                "itemCount": {
                  "argNum": 1,
                  "formatSpecifier": "lld",
                  "variations": {
                    "plural": {
                      "one": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg elemento"
                        }
                      },
                      "other": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg elementos"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private static let catalogWithRichOnlySubstitutionReorder = """
    {
      "sourceLanguage": "en",
      "strings": {
        "fruit.summary": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "%#@apples@ %#@oranges@"
              },
              "substitutions": {
                "apples": {
                  "argNum": 1,
                  "formatSpecifier": "lld",
                  "variations": {
                    "plural": {
                      "one": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg apple"
                        }
                      },
                      "other": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg apples"
                        }
                      }
                    }
                  }
                },
                "oranges": {
                  "argNum": 2,
                  "formatSpecifier": "lld",
                  "variations": {
                    "plural": {
                      "one": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg orange"
                        }
                      },
                      "other": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg oranges"
                        }
                      }
                    }
                  }
                }
              }
            },
            "es": {
              "stringUnit": {
                "state": "translated",
                "value": "%#@oranges@ %#@apples@"
              },
              "substitutions": {
                "apples": {
                  "argNum": 1,
                  "formatSpecifier": "lld",
                  "variations": {
                    "plural": {
                      "one": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg manzana"
                        }
                      },
                      "other": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg manzanas"
                        }
                      }
                    }
                  }
                },
                "oranges": {
                  "argNum": 2,
                  "formatSpecifier": "lld",
                  "variations": {
                    "plural": {
                      "one": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg naranja"
                        }
                      },
                      "other": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg naranjas"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private static let catalogWithRichImplicitSourceToNoncollidingPositionalTargetPrintfReorder = """
    {
      "sourceLanguage": "en",
      "strings": {
        "items.summary": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "%#@itemCount@ %@ %lld"
              },
              "substitutions": {
                "itemCount": {
                  "argNum": 1,
                  "formatSpecifier": "lld",
                  "variations": {
                    "plural": {
                      "one": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg item"
                        }
                      },
                      "other": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg items"
                        }
                      }
                    }
                  }
                }
              }
            },
            "es": {
              "stringUnit": {
                "state": "translated",
                "value": "%#@itemCount@ %3$lld %2$@"
              },
              "substitutions": {
                "itemCount": {
                  "argNum": 1,
                  "formatSpecifier": "lld",
                  "variations": {
                    "plural": {
                      "one": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg elemento"
                        }
                      },
                      "other": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg elementos"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private static let catalogWithReorderedNonPositionalRichAndPrintfPlaceholders = """
    {
      "sourceLanguage": "en",
      "strings": {
        "items.summary": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "%@ %#@itemCount@"
              },
              "substitutions": {
                "itemCount": {
                  "argNum": 2,
                  "formatSpecifier": "lld",
                  "variations": {
                    "plural": {
                      "one": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg item"
                        }
                      },
                      "other": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg items"
                        }
                      }
                    }
                  }
                }
              }
            },
            "es": {
              "stringUnit": {
                "state": "translated",
                "value": "%#@itemCount@ %@"
              },
              "substitutions": {
                "itemCount": {
                  "argNum": 2,
                  "formatSpecifier": "lld",
                  "variations": {
                    "plural": {
                      "one": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg elemento"
                        }
                      },
                      "other": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg elementos"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private static let catalogWithSubstitutionVariationPrintfCollision = """
    {
      "sourceLanguage": "en",
      "strings": {
        "items.summary": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "%#@itemCount@"
              },
              "substitutions": {
                "itemCount": {
                  "argNum": 1,
                  "formatSpecifier": "lld",
                  "variations": {
                    "plural": {
                      "one": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg %@"
                        }
                      },
                      "other": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg %@"
                        }
                      }
                    }
                  }
                }
              }
            },
            "es": {
              "stringUnit": {
                "state": "translated",
                "value": "%#@itemCount@"
              },
              "substitutions": {
                "itemCount": {
                  "argNum": 1,
                  "formatSpecifier": "lld",
                  "variations": {
                    "plural": {
                      "one": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg %1$@"
                        }
                      },
                      "other": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg %@"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private static let catalogWithValidSubstitutionVariationPositionalPrintf = """
    {
      "sourceLanguage": "en",
      "strings": {
        "items.summary": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "%#@itemCount@"
              },
              "substitutions": {
                "itemCount": {
                  "argNum": 1,
                  "formatSpecifier": "lld",
                  "variations": {
                    "plural": {
                      "one": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg %@"
                        }
                      },
                      "other": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg %@"
                        }
                      }
                    }
                  }
                }
              }
            },
            "es": {
              "stringUnit": {
                "state": "translated",
                "value": "%#@itemCount@"
              },
              "substitutions": {
                "itemCount": {
                  "argNum": 1,
                  "formatSpecifier": "lld",
                  "variations": {
                    "plural": {
                      "one": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%2$@ %arg"
                        }
                      },
                      "other": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%2$@ %arg"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private static let catalogWithDroppedRichPrintfPlaceholder = """
    {
      "sourceLanguage": "en",
      "strings": {
        "items.summary": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "%#@itemCount@ %@"
              },
              "substitutions": {
                "itemCount": {
                  "argNum": 1,
                  "formatSpecifier": "lld",
                  "variations": {
                    "plural": {
                      "one": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg item"
                        }
                      },
                      "other": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg items"
                        }
                      }
                    }
                  }
                }
              }
            },
            "es": {
              "stringUnit": {
                "state": "translated",
                "value": "%#@itemCount@"
              },
              "substitutions": {
                "itemCount": {
                  "argNum": 1,
                  "formatSpecifier": "lld",
                  "variations": {
                    "plural": {
                      "one": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg elemento"
                        }
                      },
                      "other": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%arg elementos"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private static let catalogWithRepeatedPositionalDynamicWidth = """
    {
      "sourceLanguage": "en",
      "strings": {
        "sample": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "%2$*1$.1f %3$*1$.1f"
              }
            },
            "es": {
              "stringUnit": {
                "state": "translated",
                "value": "%2$*1$.1f %3$*1$.1f"
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private static let catalogWithLiteralPercentCopy = """
    {
      "sourceLanguage": "en",
      "strings": {
        "sample": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "100% increase, 0% interest, and save 20% a year"
              }
            },
            "es": {
              "stringUnit": {
                "state": "translated",
                "value": "100 por ciento de aumento, 0 por ciento de interés y ahorra un 20 por ciento al año"
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private static let catalogWithDroppedSpaceFlaggedSuffixPlaceholder = """
    {
      "sourceLanguage": "en",
      "strings": {
        "sample": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "Level: % dB"
              }
            },
            "es": {
              "stringUnit": {
                "state": "translated",
                "value": "Nivel: dB"
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private static let catalogWithMissingSubstitutionDeclaration = """
    {
      "sourceLanguage": "en",
      "strings": {
        "items.count": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "%#@itemCount@"
              },
              "substitutions": {
                "otherCount": {
                  "argNum": 1,
                  "formatSpecifier": "lld"
                }
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private static let catalogWithOmittedSubstitutionDeclaration = """
    {
      "sourceLanguage": "en",
      "strings": {
        "items.count": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "%#@itemCount@"
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

    private static let catalogWithDynamicPrintfOnlyKeys = """
    {
      "sourceLanguage": "en",
      "strings": {
        "%*.*f": {},
        "(%*.*f)": {},
        "Progress %*.*f": {}
      },
      "version": "1.0"
    }
    """
}
