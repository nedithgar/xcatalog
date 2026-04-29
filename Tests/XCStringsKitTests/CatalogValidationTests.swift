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
