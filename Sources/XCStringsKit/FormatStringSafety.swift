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
            return ["Source mixes positional and non-positional placeholders, which is ambiguous for validation: \(describe(sourcePrintf))."]
        }

        if targetHasPositional && targetHasNonPositional {
            return ["Target mixes positional and non-positional placeholders, which is unsafe: \(describe(targetPrintf))."]
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
            (index + 1, PlaceholderIdentity(kind: .printf, position: index + 1, name: nil, specifier: placeholder.specifier))
        })
        let actual = Dictionary(grouping: target, by: { $0.position ?? -1 })
        return compare(expected: expected, actual: actual)
    }

    private static func comparePositional(
        source: [FormatPlaceholder],
        target: [FormatPlaceholder]
    ) -> [String] {
        let expected = Dictionary(grouping: source, by: { $0.position ?? -1 }).compactMapValues(\.first?.identity)
        let actual = Dictionary(grouping: target, by: { $0.position ?? -1 })
        return compare(expected: expected, actual: actual)
    }

    private static func compare(
        expected: [Int: PlaceholderIdentity],
        actual: [Int: [FormatPlaceholder]]
    ) -> [String] {
        var diagnostics: [String] = []
        let actualIdentities = actual.compactMapValues(\.first?.identity)

        let missingPositions = expected.keys.filter { actualIdentities[$0] == nil }.sorted()
        if !missingPositions.isEmpty {
            diagnostics.append("Missing positional placeholders: \(missingPositions.map { "%\($0)$" }.joined(separator: ", ")).")
        }

        let extraPositions = actualIdentities.keys.filter { expected[$0] == nil }.sorted()
        if !extraPositions.isEmpty {
            diagnostics.append("Extra positional placeholders: \(extraPositions.map { "%\($0)$" }.joined(separator: ", ")).")
        }

        for position in expected.keys.sorted() {
            guard let expectedIdentity = expected[position],
                  let actualIdentity = actualIdentities[position],
                  expectedIdentity != actualIdentity else {
                continue
            }

            let expectedName = expectedIdentity.name.map { "(\($0))" } ?? ""
            let actualName = actualIdentity.name.map { "(\($0))" } ?? ""
            diagnostics.append(
                "Placeholder %\(position)$ changed from \(expectedName)\(expectedIdentity.specifier) to \(actualName)\(actualIdentity.specifier)."
            )
        }

        let duplicatePositions = actual
            .filter { _, placeholders in placeholders.count > 1 }
            .keys
            .sorted()
        if !duplicatePositions.isEmpty {
            diagnostics.append("Target repeats positional placeholders: \(duplicatePositions.map { "%\($0)$" }.joined(separator: ", ")).")
        }

        return diagnostics
    }

    private static func describe(_ placeholders: [FormatPlaceholder]) -> String {
        guard !placeholders.isEmpty else {
            return "none"
        }

        return placeholders.map(\.raw).joined(separator: ", ")
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
                result.append(placeholder.placeholder)
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

    private func scanPrintf(at start: Int) -> (placeholder: FormatPlaceholder, endIndex: Int)? {
        var index = start + 1
        let position = scanPosition(&index)
        let name = scanName(&index)

        skipFlagsWidthAndPrecision(&index)

        let length = scanLength(&index)
        guard let conversion = character(at: index), Self.conversionSpecifiers.contains(conversion) else {
            return nil
        }

        let raw = String(characters[start ... index])
        let specifier = length + String(conversion)
        return (
            FormatPlaceholder(
                kind: .printf,
                raw: raw,
                position: position,
                name: name,
                specifier: specifier
            ),
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

    private func skipFlagsWidthAndPrecision(_ index: inout Int) {
        while let character = character(at: index), Self.flagCharacters.contains(character) {
            index += 1
        }

        skipWidthOrPrecisionValue(&index)

        if character(at: index) == "." {
            index += 1
            skipWidthOrPrecisionValue(&index)
        }
    }

    private func skipWidthOrPrecisionValue(_ index: inout Int) {
        if character(at: index) == "*" {
            index += 1
            _ = scanPosition(&index)
            return
        }

        while let character = character(at: index), character.isNumber {
            index += 1
        }
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
    private static let conversionSpecifiers = Set<Character>(["@","d","D","u","U","x","X","o","O","f","F","e","E","g","G","a","A","c","C","s","S","p"])
}
