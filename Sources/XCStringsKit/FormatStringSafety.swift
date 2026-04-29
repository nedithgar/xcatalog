import Foundation

package enum FormatPlaceholderKind: String, Codable, Sendable {
    case printf
    case stringsdictSubstitution
    case stringsdictArgument
}

package struct FormatPlaceholder: Codable, Hashable, Sendable {
    package let kind: FormatPlaceholderKind
    package let raw: String
    package let position: Int?
    package let name: String?
    package let specifier: String

    package init(
        kind: FormatPlaceholderKind,
        raw: String,
        position: Int? = nil,
        name: String? = nil,
        specifier: String
    ) {
        self.kind = kind
        self.raw = raw
        self.position = position
        self.name = name
        self.specifier = specifier
    }

    var isPositionalPrintf: Bool {
        kind == .printf && position != nil
    }

    var identity: PlaceholderIdentity {
        PlaceholderIdentity(kind: kind, position: position, name: name, specifier: specifier)
    }
}

package struct PlaceholderValidationResult: Codable, Sendable {
    package let key: String
    package let language: String
    package let sourceValue: String
    package let targetValue: String
    package let sourcePlaceholders: [FormatPlaceholder]
    package let targetPlaceholders: [FormatPlaceholder]
    package let diagnostics: [String]

    package var isValid: Bool {
        diagnostics.isEmpty
    }

    package var checked: Bool {
        !sourcePlaceholders.isEmpty || !targetPlaceholders.isEmpty
    }

    package init(
        key: String,
        language: String,
        sourceValue: String,
        targetValue: String,
        sourcePlaceholders: [FormatPlaceholder],
        targetPlaceholders: [FormatPlaceholder],
        diagnostics: [String]
    ) {
        self.key = key
        self.language = language
        self.sourceValue = sourceValue
        self.targetValue = targetValue
        self.sourcePlaceholders = sourcePlaceholders
        self.targetPlaceholders = targetPlaceholders
        self.diagnostics = diagnostics
    }
}

struct PlaceholderIdentity: Hashable {
    let kind: FormatPlaceholderKind
    let position: Int?
    let name: String?
    let specifier: String
}

package enum FormatStringSafety {
    package static func placeholders(in value: String) -> [FormatPlaceholder] {
        FormatPlaceholderScanner(value).scan()
    }

    package static func validate(
        key: String,
        language: String,
        sourceValue: String,
        targetValue: String
    ) -> PlaceholderValidationResult {
        let sourcePlaceholders = placeholders(in: sourceValue)
        let targetPlaceholders = placeholders(in: targetValue)
        let diagnostics = validate(
            sourcePlaceholders: sourcePlaceholders,
            targetPlaceholders: targetPlaceholders
        )

        return PlaceholderValidationResult(
            key: key,
            language: language,
            sourceValue: sourceValue,
            targetValue: targetValue,
            sourcePlaceholders: sourcePlaceholders,
            targetPlaceholders: targetPlaceholders,
            diagnostics: diagnostics
        )
    }

    package static func validatePrintfPlaceholders(
        sourcePlaceholders: [FormatPlaceholder],
        targetPlaceholders: [FormatPlaceholder]
    ) -> [String] {
        validate(
            sourcePlaceholders: sourcePlaceholders.filter { $0.kind == .printf },
            targetPlaceholders: targetPlaceholders.filter { $0.kind == .printf }
        )
    }

    private static func validate(
        sourcePlaceholders: [FormatPlaceholder],
        targetPlaceholders: [FormatPlaceholder]
    ) -> [String] {
        let sourceRich = sourcePlaceholders.filter { $0.kind != .printf }
        let targetRich = targetPlaceholders.filter { $0.kind != .printf }
        if !sourceRich.isEmpty || !targetRich.isEmpty {
            return [
                "Stringsdict-style substitution placeholders require substitution-aware writes; plain stringUnit writes are refused. Source: \(describe(sourceRich)); target: \(describe(targetRich))."
            ]
        }

        let sourcePrintf = sourcePlaceholders.filter { $0.kind == .printf }
        let targetPrintf = targetPlaceholders.filter { $0.kind == .printf }

        guard !sourcePrintf.isEmpty || !targetPrintf.isEmpty else {
            return []
        }

        if sourcePrintf.isEmpty {
            return ["Target contains extra format placeholders: \(describe(targetPrintf))."]
        }

        if targetPrintf.isEmpty {
            return ["Target is missing required format placeholders: \(describe(sourcePrintf))."]
        }

        let sourceHasPositional = sourcePrintf.contains { $0.position != nil }
        let sourceHasNonPositional = sourcePrintf.contains { $0.position == nil }
        let targetHasPositional = targetPrintf.contains { $0.position != nil }
        let targetHasNonPositional = targetPrintf.contains { $0.position == nil }

        if sourceHasPositional && sourceHasNonPositional {
            return [mixedPositionalDiagnostic(label: "Source", placeholders: sourcePrintf)]
        }

        if targetHasPositional && targetHasNonPositional {
            return [mixedPositionalDiagnostic(label: "Target", placeholders: targetPrintf)]
        }

        if sourceHasPositional {
            guard targetHasPositional else {
                return ["Target must preserve positional placeholders from the source: expected \(describe(sourcePrintf)), found \(describe(targetPrintf))."]
            }
            return comparePositional(source: sourcePrintf, target: targetPrintf)
        }

        if targetHasPositional {
            return compareImplicitSourceToPositionalTarget(source: sourcePrintf, target: targetPrintf)
        }

        return compareNonPositionalSequence(source: sourcePrintf, target: targetPrintf)
    }

    private static func compareNonPositionalSequence(
        source: [FormatPlaceholder],
        target: [FormatPlaceholder]
    ) -> [String] {
        let sourceTypes = source.map(\.specifier)
        let targetTypes = target.map(\.specifier)

        guard sourceTypes != targetTypes else {
            return []
        }

        return [
            "Target must keep non-positional placeholders in source order. Expected \(sourceTypes.joined(separator: ", ")); found \(targetTypes.joined(separator: ", "))."
        ]
    }

    private static func compareImplicitSourceToPositionalTarget(
        source: [FormatPlaceholder],
        target: [FormatPlaceholder]
    ) -> [String] {
        let expected = Dictionary(uniqueKeysWithValues: source.enumerated().map { index, placeholder in
            let position = index + 1
            return (
                position,
                [PlaceholderIdentity(kind: .printf, position: position, name: nil, specifier: placeholder.specifier)]
            )
        })
        let actual = Dictionary(grouping: target, by: { $0.position ?? -1 })
        return compare(expected: expected, actual: actual)
    }

    private static func comparePositional(
        source: [FormatPlaceholder],
        target: [FormatPlaceholder]
    ) -> [String] {
        let expected = Dictionary(grouping: source, by: { $0.position ?? -1 })
            .mapValues { placeholders in
                placeholders.map(\.identity)
            }
        let actual = Dictionary(grouping: target, by: { $0.position ?? -1 })
        return compare(expected: expected, actual: actual)
    }

    private static func compare(
        expected: [Int: [PlaceholderIdentity]],
        actual: [Int: [FormatPlaceholder]]
    ) -> [String] {
        var diagnostics: [String] = []
        let actualIdentities = actual.mapValues { placeholders in
            placeholders.map(\.identity)
        }

        let missingPositions = expected.keys.filter { actualIdentities[$0]?.isEmpty != false }.sorted()
        if !missingPositions.isEmpty {
            diagnostics.append("Missing positional placeholders: \(missingPositions.map { "%\($0)$" }.joined(separator: ", ")).")
        }

        let extraPositions = actualIdentities.keys.filter { expected[$0]?.isEmpty != false }.sorted()
        if !extraPositions.isEmpty {
            diagnostics.append("Extra positional placeholders: \(extraPositions.map { "%\($0)$" }.joined(separator: ", ")).")
        }

        for position in expected.keys.sorted() {
            guard let expectedIdentities = expected[position],
                  let actualIdentitiesForPosition = actualIdentities[position],
                  !actualIdentitiesForPosition.isEmpty else {
                continue
            }

            if expectedIdentities.count == 1,
               actualIdentitiesForPosition.count == 1,
               let expectedIdentity = expectedIdentities.first,
               let actualIdentity = actualIdentitiesForPosition.first,
               expectedIdentity != actualIdentity {
                diagnostics.append(
                    "Placeholder %\(position)$ changed from \(describe(expectedIdentity)) to \(describe(actualIdentity))."
                )
                continue
            }

            let expectedCounts = countsByIdentity(expectedIdentities)
            let actualCounts = countsByIdentity(actualIdentitiesForPosition)

            let missingIdentities = expectedCounts.keys.filter { expectedIdentity in
                (actualCounts[expectedIdentity] ?? 0) < (expectedCounts[expectedIdentity] ?? 0)
            }.sorted(by: compareIdentities)
            if !missingIdentities.isEmpty {
                diagnostics.append(
                    "Placeholder %\(position)$ is missing expected occurrences: \(describeOccurrences(missingIdentities, expected: expectedCounts, actual: actualCounts))."
                )
            }

            let extraIdentities = actualCounts.keys.filter { actualIdentity in
                (actualCounts[actualIdentity] ?? 0) > (expectedCounts[actualIdentity] ?? 0)
            }.sorted(by: compareIdentities)
            if !extraIdentities.isEmpty {
                diagnostics.append(
                    "Placeholder %\(position)$ has extra occurrences: \(describeOccurrences(extraIdentities, expected: expectedCounts, actual: actualCounts))."
                )
            }
        }

        return diagnostics
    }

    private static func describe(_ placeholders: [FormatPlaceholder]) -> String {
        guard !placeholders.isEmpty else {
            return "none"
        }

        return placeholders.map(\.raw).joined(separator: ", ")
    }

    private static func countsByIdentity(_ identities: [PlaceholderIdentity]) -> [PlaceholderIdentity: Int] {
        identities.reduce(into: [:]) { result, identity in
            result[identity, default: 0] += 1
        }
    }

    private static func describeOccurrences(
        _ identities: [PlaceholderIdentity],
        expected: [PlaceholderIdentity: Int],
        actual: [PlaceholderIdentity: Int]
    ) -> String {
        identities.map { identity in
            let expectedCount = expected[identity] ?? 0
            let actualCount = actual[identity] ?? 0
            let delta = abs(expectedCount - actualCount)
            let description = describe(identity)
            return delta == 1 ? description : "\(description) x\(delta)"
        }.joined(separator: ", ")
    }

    private static func describe(_ identity: PlaceholderIdentity) -> String {
        let name = identity.name.map { "(\($0))" } ?? ""
        return "\(name)\(identity.specifier)"
    }

    private static func compareIdentities(_ lhs: PlaceholderIdentity, _ rhs: PlaceholderIdentity) -> Bool {
        identitySortKey(lhs) < identitySortKey(rhs)
    }

    private static func identitySortKey(_ identity: PlaceholderIdentity) -> String {
        [
            identity.kind.rawValue,
            identity.position.map(String.init) ?? "",
            identity.name ?? "",
            identity.specifier,
        ].joined(separator: "\u{0}")
    }

    private static func mixedPositionalDiagnostic(
        label: String,
        placeholders: [FormatPlaceholder]
    ) -> String {
        "\(label) mixes positional and non-positional printf placeholders, which is undefined for printf format strings. Use fully positional placeholders; dynamic width or precision with positional conversions must use explicit *m$ forms, such as %2$*1$f or %3$*1$.*2$f. Found: \(describe(placeholders))."
    }
}

private struct FormatPlaceholderScanner {
    private let characters: [Character]

    init(_ value: String) {
        self.characters = Array(value)
    }

    func scan() -> [FormatPlaceholder] {
        var result: [FormatPlaceholder] = []
        var index = 0

        while index < characters.count {
            guard characters[index] == "%" else {
                index += 1
                continue
            }

            if character(at: index + 1) == "%" {
                index += 2
                continue
            }

            if let placeholder = scanStringsdictSubstitution(at: index) {
                result.append(placeholder.placeholder)
                index = placeholder.endIndex
                continue
            }

            if let placeholder = scanStringsdictArgument(at: index) {
                result.append(placeholder.placeholder)
                index = placeholder.endIndex
                continue
            }

            if let placeholder = scanPrintf(at: index) {
                result.append(contentsOf: placeholder.placeholders)
                index = placeholder.endIndex
                continue
            }

            index += 1
        }

        return result
    }

    private func scanStringsdictSubstitution(at start: Int) -> (placeholder: FormatPlaceholder, endIndex: Int)? {
        guard character(at: start + 1) == "#",
              character(at: start + 2) == "@" else {
            return nil
        }

        var index = start + 3
        var name = ""
        while let character = character(at: index), character != "@" {
            name.append(character)
            index += 1
        }

        guard !name.isEmpty, character(at: index) == "@" else {
            return nil
        }

        let raw = String(characters[start ... index])
        return (
            FormatPlaceholder(
                kind: .stringsdictSubstitution,
                raw: raw,
                name: name,
                specifier: name
            ),
            index + 1
        )
    }

    private func scanStringsdictArgument(at start: Int) -> (placeholder: FormatPlaceholder, endIndex: Int)? {
        let token = "%arg"
        guard starts(with: token, at: start) else {
            return nil
        }

        return (
            FormatPlaceholder(
                kind: .stringsdictArgument,
                raw: token,
                name: "arg",
                specifier: "arg"
            ),
            start + token.count
        )
    }

    private func scanPrintf(at start: Int) -> (placeholders: [FormatPlaceholder], endIndex: Int)? {
        var index = start + 1
        let position = scanPosition(&index)
        let name = scanName(&index)

        var placeholders = scanFlagsWidthAndPrecision(&index)

        let length = scanLength(&index)
        guard let conversion = character(at: index), Self.conversionSpecifiers.contains(conversion) else {
            return nil
        }

        if isLikelyLiteralPercentWord(
            start: start,
            conversionIndex: index,
            position: position,
            name: name,
            dynamicPlaceholders: placeholders
        ) {
            return nil
        }

        let raw = String(characters[start ... index])
        let specifier = length + String(conversion)
        placeholders.append(
            FormatPlaceholder(
                kind: .printf,
                raw: raw,
                position: position,
                name: name,
                specifier: specifier
            )
        )

        return (
            placeholders,
            index + 1
        )
    }

    private func scanPosition(_ index: inout Int) -> Int? {
        let start = index
        while let character = character(at: index), character.isNumber {
            index += 1
        }

        guard index > start, character(at: index) == "$" else {
            index = start
            return nil
        }

        let digits = String(characters[start ..< index])
        index += 1
        return Int(digits)
    }

    private func scanName(_ index: inout Int) -> String? {
        guard character(at: index) == "(" else {
            return nil
        }

        let start = index + 1
        var end = start
        while let character = character(at: end), character != ")" {
            end += 1
        }

        guard end > start, character(at: end) == ")" else {
            return nil
        }

        index = end + 1
        return String(characters[start ..< end])
    }

    private func scanFlagsWidthAndPrecision(_ index: inout Int) -> [FormatPlaceholder] {
        while let character = character(at: index), Self.flagCharacters.contains(character) {
            index += 1
        }

        var placeholders: [FormatPlaceholder] = []
        if let width = scanWidthOrPrecisionValue(&index, role: .width) {
            placeholders.append(width)
        }

        if character(at: index) == "." {
            index += 1
            if let precision = scanWidthOrPrecisionValue(&index, role: .precision) {
                placeholders.append(precision)
            }
        }

        return placeholders
    }

    private func scanWidthOrPrecisionValue(_ index: inout Int, role: WidthOrPrecisionRole) -> FormatPlaceholder? {
        if character(at: index) == "*" {
            let tokenStart = index
            index += 1
            let position = scanPosition(&index)
            let token = String(characters[tokenStart ..< index])
            return FormatPlaceholder(
                kind: .printf,
                raw: "%\(role.rawPrefix)\(token)",
                position: position,
                specifier: "*\(role.rawValue)"
            )
        }

        while let character = character(at: index), character.isNumber {
            index += 1
        }

        return nil
    }

    private func scanLength(_ index: inout Int) -> String {
        for length in Self.lengthModifiers {
            if starts(with: length, at: index) {
                index += length.count
                return length
            }
        }

        return ""
    }

    private func isLikelyLiteralPercentWord(
        start: Int,
        conversionIndex: Int,
        position: Int?,
        name: String?,
        dynamicPlaceholders: [FormatPlaceholder]
    ) -> Bool {
        guard position == nil,
              name == nil,
              dynamicPlaceholders.isEmpty else {
            return false
        }

        let body = characters[(start + 1) ..< conversionIndex]
        guard body.contains(" ") else {
            return false
        }

        guard !body.contains(where: { Self.strongFormatEvidenceCharacters.contains($0) }) else {
            return false
        }

        return Self.isASCIIDigit(character(at: start - 1))
    }

    private func character(at index: Int) -> Character? {
        guard characters.indices.contains(index) else {
            return nil
        }
        return characters[index]
    }

    private func starts(with string: String, at index: Int) -> Bool {
        let value = Array(string)
        guard index + value.count <= characters.count else {
            return false
        }
        return Array(characters[index ..< index + value.count]) == value
    }

    private static let flagCharacters = Set<Character>(["-", "+", " ", "#", "0", "'"])
    private static let lengthModifiers = ["hh", "ll", "l", "h", "q", "L", "z", "t", "j"]
    private static let conversionSpecifiers = Set<Character>(["@","d","i","D","u","U","x","X","o","O","f","F","e","E","g","G","a","A","c","C","s","S","p"])
    private static let strongFormatEvidenceCharacters = Set<Character>([".", "*", "$", "1", "2", "3", "4", "5", "6", "7", "8", "9"])

    private static func isASCIIDigit(_ character: Character?) -> Bool {
        guard let character,
              character.unicodeScalars.count == 1,
              let scalar = character.unicodeScalars.first else {
            return false
        }

        return ("0" ... "9").contains(scalar)
    }

    private enum WidthOrPrecisionRole: String {
        case width
        case precision

        var rawPrefix: String {
            switch self {
            case .width:
                return ""
            case .precision:
                return "."
            }
        }
    }
}
