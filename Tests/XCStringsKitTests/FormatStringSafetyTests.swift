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

    @Test("detects dynamic width and precision arguments")
    func detectsDynamicWidthAndPrecisionArguments() {
        let placeholders = FormatStringSafety.placeholders(in: "Progress: %*.*f%%")

        #expect(placeholders.map(\.raw) == ["%*", "%.*", "%*.*f"])
        #expect(placeholders.map(\.position) == [nil, nil, nil])
        #expect(placeholders.map(\.specifier) == ["*width", "*precision", "f"])
    }

    @Test("detects positional dynamic width and precision arguments")
    func detectsPositionalDynamicWidthAndPrecisionArguments() {
        let placeholders = FormatStringSafety.placeholders(in: "Value: %3$*1$.*2$f")

        #expect(placeholders.map(\.raw) == ["%*1$", "%.*2$", "%3$*1$.*2$f"])
        #expect(placeholders.map(\.position) == [1, 2, 3])
        #expect(placeholders.map(\.specifier) == ["*width", "*precision", "f"])
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

    @Test("allows implicit dynamic width and precision when argument order is preserved")
    func validatesImplicitDynamicWidthAndPrecision() {
        let result = FormatStringSafety.validate(
            key: "sample.progress",
            language: "es",
            sourceValue: "Progress: %*.*f%%",
            targetValue: "Progreso: %*.*f%%"
        )

        #expect(result.isValid)
        #expect(result.sourcePlaceholders.map(\.specifier) == ["*width", "*precision", "f"])
    }

    @Test("allows positional target for implicit dynamic width and precision")
    func validatesImplicitDynamicWidthAndPrecisionWithPositionalTarget() {
        let result = FormatStringSafety.validate(
            key: "sample.progress",
            language: "es",
            sourceValue: "Progress: %*.*f%%",
            targetValue: "Progreso: %3$*1$.*2$f%%"
        )

        #expect(result.isValid)
        #expect(result.targetPlaceholders.map(\.position) == [1, 2, 3])
    }

    @Test("allows explicit positional dynamic width")
    func validatesExplicitPositionalDynamicWidth() {
        let result = FormatStringSafety.validate(
            key: "sample.value",
            language: "es",
            sourceValue: "Value: %2$*1$f",
            targetValue: "Valor: %2$*1$f"
        )

        #expect(result.isValid)
        #expect(result.sourcePlaceholders.map(\.position) == [1, 2])
        #expect(result.sourcePlaceholders.map(\.specifier) == ["*width", "f"])
    }

    @Test("allows repeated positional conversions when source and target match")
    func validatesRepeatedPositionalConversions() {
        let result = FormatStringSafety.validate(
            key: "sample.value",
            language: "es",
            sourceValue: "Value: %1$d %1$d",
            targetValue: "Valor: %1$d %1$d"
        )

        #expect(result.isValid)
    }

    @Test("allows repeated positional dynamic width arguments")
    func validatesRepeatedPositionalDynamicWidthArguments() {
        let result = FormatStringSafety.validate(
            key: "sample.value",
            language: "es",
            sourceValue: "Values: %2$*1$f %3$*1$f",
            targetValue: "Valores: %2$*1$f %3$*1$f"
        )

        #expect(result.isValid)
        #expect(result.sourcePlaceholders.map(\.position) == [1, 2, 1, 3])
    }

    @Test("allows repeated positional dynamic width and precision arguments")
    func validatesRepeatedPositionalDynamicWidthAndPrecisionArguments() {
        let result = FormatStringSafety.validate(
            key: "sample.value",
            language: "es",
            sourceValue: "Values: %2$*1$.*4$f %3$*1$.*4$f",
            targetValue: "Valores: %2$*1$.*4$f %3$*1$.*4$f"
        )

        #expect(result.isValid)
        #expect(result.sourcePlaceholders.map(\.position) == [1, 4, 2, 1, 4, 3])
    }

    @Test("rejects dropped implicit dynamic width and precision arguments")
    func rejectsDroppedImplicitDynamicWidthAndPrecision() {
        let result = FormatStringSafety.validate(
            key: "sample.progress",
            language: "es",
            sourceValue: "Progress: %*.*f%%",
            targetValue: "Progreso: %f%%"
        )

        #expect(!result.isValid)
        #expect(result.diagnostics.joined().contains("*width, *precision, f"))
    }

    @Test("rejects added repeated positional placeholder")
    func rejectsAddedRepeatedPositionalPlaceholder() {
        let result = FormatStringSafety.validate(
            key: "sample.value",
            language: "es",
            sourceValue: "Value: %1$d",
            targetValue: "Valor: %1$d %1$d"
        )

        #expect(!result.isValid)
        #expect(result.diagnostics.joined().contains("extra occurrences"))
    }

    @Test("rejects repeated positional placeholder with changed specifier")
    func rejectsRepeatedPositionalPlaceholderWithChangedSpecifier() {
        let result = FormatStringSafety.validate(
            key: "sample.value",
            language: "es",
            sourceValue: "Value: %1$d %1$d",
            targetValue: "Valor: %1$d %1$x"
        )

        let diagnostics = result.diagnostics.joined(separator: "\n")
        #expect(!result.isValid)
        #expect(diagnostics.contains("missing expected occurrences"))
        #expect(diagnostics.contains("extra occurrences"))
    }

    @Test("rejects positional conversion with implicit dynamic width")
    func rejectsPositionalConversionWithImplicitDynamicWidth() {
        let result = FormatStringSafety.validate(
            key: "sample.value",
            language: "es",
            sourceValue: "Value: %2$*f",
            targetValue: "Valor: %2$*f"
        )

        let diagnostics = result.diagnostics.joined(separator: "\n")
        #expect(!result.isValid)
        #expect(diagnostics.contains("undefined for printf format strings"))
        #expect(diagnostics.contains("explicit *m$ forms"))
    }

    @Test("rejects positional conversion with implicit dynamic width and precision")
    func rejectsPositionalConversionWithImplicitDynamicWidthAndPrecision() {
        let result = FormatStringSafety.validate(
            key: "sample.value",
            language: "es",
            sourceValue: "Value: %3$*.*f",
            targetValue: "Valor: %3$*.*f"
        )

        let diagnostics = result.diagnostics.joined(separator: "\n")
        #expect(!result.isValid)
        #expect(diagnostics.contains("undefined for printf format strings"))
        #expect(diagnostics.contains("%3$*1$.*2$f"))
    }

    @Test("allows positional dynamic width and precision when argument identities are preserved")
    func validatesPositionalDynamicWidthAndPrecision() {
        let result = FormatStringSafety.validate(
            key: "sample.value",
            language: "es",
            sourceValue: "Value: %3$*1$.*2$f",
            targetValue: "Valor: %3$*1$.*2$f"
        )

        #expect(result.isValid)
        #expect(result.sourcePlaceholders.map(\.position) == [1, 2, 3])
    }

    @Test("rejects removed positional dynamic width argument")
    func rejectsRemovedPositionalDynamicWidthArgument() {
        let result = FormatStringSafety.validate(
            key: "sample.value",
            language: "es",
            sourceValue: "Value: %2$*1$f",
            targetValue: "Valor: %1$f"
        )

        #expect(!result.isValid)
        #expect(result.diagnostics.joined().contains("Placeholder %1$ changed"))
        #expect(result.diagnostics.joined().contains("Missing positional placeholders"))
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
