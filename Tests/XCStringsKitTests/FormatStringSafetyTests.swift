import Foundation
import Testing
@testable import XCStringsKit

@Suite("Format-string placeholder safety")
struct FormatStringSafetyTests {
    @Test("detects positional printf placeholders")
    func detectsPositionalPrintfPlaceholders() {
        let placeholders = FormatStringSafety.placeholders(in: "Item, %1$@, %2$lld by %3$lld pixels")

        #expect(placeholders.map(\.raw) == ["%1$@", "%2$lld", "%3$lld"])
        #expect(placeholders.map(\.position) == [1, 2, 3])
        #expect(placeholders.map(\.specifier) == ["@", "lld", "lld"])
    }

    @Test("detects non-positional printf placeholders and ignores escaped percents")
    func detectsNonPositionalPrintfPlaceholders() {
        let placeholders = FormatStringSafety.placeholders(in: "Progress: %lld%% complete, %@")

        #expect(placeholders.map(\.raw) == ["%lld", "%@"])
        #expect(placeholders.map(\.specifier) == ["lld", "@"])
    }

    @Test("detects named positional placeholders from string catalogs")
    func detectsNamedPositionalPlaceholders() {
        let placeholders = FormatStringSafety.placeholders(
            in: "%arg of %2$(totalCount)lld selected photos"
        )

        #expect(placeholders.map(\.kind) == [.stringsdictArgument, .printf])
        #expect(placeholders[1].raw == "%2$(totalCount)lld")
        #expect(placeholders[1].position == 2)
        #expect(placeholders[1].name == "totalCount")
        #expect(placeholders[1].specifier == "lld")
    }

    @Test("detects stringsdict substitution placeholders")
    func detectsStringsdictSubstitutionPlaceholders() {
        let placeholders = FormatStringSafety.placeholders(in: "%#@itemCount@")

        #expect(placeholders.count == 1)
        #expect(placeholders[0].kind == .stringsdictSubstitution)
        #expect(placeholders[0].name == "itemCount")
    }

    @Test("allows positional target reordering when every source position and type is preserved")
    func validatesPositionalReordering() {
        let result = FormatStringSafety.validate(
            key: "sample.library.itemAccessibilityLabel",
            language: "es",
            sourceValue: "Item, %1$@, %2$lld by %3$lld pixels",
            targetValue: "Píxeles: %2$lld por %3$lld, elemento %1$@"
        )

        #expect(result.isValid)
        #expect(result.checked)
    }

    @Test("allows positional target reordering for implicit source placeholders")
    func validatesImplicitSourceWithPositionalTarget() {
        let result = FormatStringSafety.validate(
            key: "About %@ (%lld)",
            language: "es",
            sourceValue: "About %@ (%lld)",
            targetValue: "%2$lld elementos para %1$@"
        )

        #expect(result.isValid)
    }

    @Test("rejects non-positional placeholder reordering")
    func rejectsNonPositionalReordering() {
        let result = FormatStringSafety.validate(
            key: "About %@ (%lld)",
            language: "es",
            sourceValue: "About %@ (%lld)",
            targetValue: "%lld elementos para %@"
        )

        #expect(!result.isValid)
        #expect(result.diagnostics.joined().contains("source order"))
    }

    @Test("rejects missing positional placeholders")
    func rejectsMissingPositionalPlaceholders() {
        let result = FormatStringSafety.validate(
            key: "sample.library.itemAccessibilityLabel",
            language: "es",
            sourceValue: "Item, %1$@, %2$lld by %3$lld pixels",
            targetValue: "Elemento, %1$@, %2$lld píxeles"
        )

        #expect(!result.isValid)
        #expect(result.diagnostics.joined().contains("Missing positional placeholders"))
    }

    @Test("rejects type-changed positional placeholders")
    func rejectsTypeChangedPositionalPlaceholders() {
        let result = FormatStringSafety.validate(
            key: "sample.library.itemAccessibilityLabel",
            language: "es",
            sourceValue: "Item, %1$@, %2$lld by %3$lld pixels",
            targetValue: "Elemento, %1$@, %2$d por %3$lld píxeles"
        )

        #expect(!result.isValid)
        #expect(result.diagnostics.joined().contains("changed"))
    }

    @Test("rejects stringsdict-style substitution writes")
    func rejectsStringsdictSubstitutionWrites() {
        let result = FormatStringSafety.validate(
            key: "sample.export.incompleteWarning",
            language: "es",
            sourceValue: "%#@incompleteCount@",
            targetValue: "%#@incompleteCount@"
        )

        #expect(!result.isValid)
        #expect(result.diagnostics.joined().contains("substitution-aware writes"))
    }
}
