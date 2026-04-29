import Foundation

struct XCStringsJSONKeyOrder: Sendable {
    let strings: [String]
    let localizationsByStringKey: [String: [String]]
    let substitutionsByStringKeyAndLanguage: [String: [String]]
}

enum XCStringsJSONKeyOrderScanner {
    static func scan(_ data: Data) throws -> XCStringsJSONKeyOrder {
        guard let text = String(data: data, encoding: .utf8) else {
            throw XCStringsError.invalidFileFormat(path: "", reason: "File is not valid UTF-8")
        }

        var scanner = Scanner(text: text)
        let objectOrders = try scanner.scan()
        let stringsPath = Scanner.pathKey(["strings"])
        let strings = objectOrders[stringsPath] ?? []

        var localizationsByStringKey: [String: [String]] = [:]
        var substitutionsByStringKeyAndLanguage: [String: [String]] = [:]
        for key in strings {
            let localizationsPath = Scanner.pathKey(["strings", key, "localizations"])
            if let localizations = objectOrders[localizationsPath] {
                localizationsByStringKey[key] = localizations

                for language in localizations {
                    let substitutionsPath = Scanner.pathKey(["strings", key, "localizations", language, "substitutions"])
                    if let substitutions = objectOrders[substitutionsPath] {
                        substitutionsByStringKeyAndLanguage[Scanner.pathKey([key, language])] = substitutions
                    }
                }
            }
        }

        return XCStringsJSONKeyOrder(
            strings: strings,
            localizationsByStringKey: localizationsByStringKey,
            substitutionsByStringKeyAndLanguage: substitutionsByStringKeyAndLanguage
        )
    }

    private struct Scanner {
        private let text: String
        private var index: String.Index
        private var objectOrders: [String: [String]] = [:]

        init(text: String) {
            self.text = text
            self.index = text.startIndex
        }

        static func pathKey(_ path: [String]) -> String {
            path.joined(separator: "\u{1F}")
        }

        mutating func scan() throws -> [String: [String]] {
            try parseValue(path: [])
            skipWhitespace()
            guard index == text.endIndex else {
                throw XCStringsError.invalidJSON(reason: "Unexpected content after JSON root")
            }
            return objectOrders
        }

        private mutating func parseValue(path: [String]) throws {
            skipWhitespace()
            guard let character = currentCharacter else {
                throw XCStringsError.invalidJSON(reason: "Unexpected end of JSON")
            }

            switch character {
            case "{":
                try parseObject(path: path)
            case "[":
                try parseArray(path: path)
            case "\"":
                _ = try parseString()
            default:
                try parseScalar()
            }
        }

        private mutating func parseObject(path: [String]) throws {
            try consume("{")
            skipWhitespace()

            var keys: [String] = []

            if currentCharacter == "}" {
                advance()
                objectOrders[Self.pathKey(path)] = keys
                return
            }

            while true {
                skipWhitespace()
                let key = try parseString()
                keys.append(key)

                skipWhitespace()
                try consume(":")
                try parseValue(path: path + [key])

                skipWhitespace()
                guard let character = currentCharacter else {
                    throw XCStringsError.invalidJSON(reason: "Unterminated object")
                }

                if character == "}" {
                    advance()
                    objectOrders[Self.pathKey(path)] = keys
                    return
                }

                try consume(",")
            }
        }

        private mutating func parseArray(path: [String]) throws {
            try consume("[")
            skipWhitespace()

            if currentCharacter == "]" {
                advance()
                return
            }

            while true {
                try parseValue(path: path)
                skipWhitespace()

                guard let character = currentCharacter else {
                    throw XCStringsError.invalidJSON(reason: "Unterminated array")
                }

                if character == "]" {
                    advance()
                    return
                }

                try consume(",")
            }
        }

        private mutating func parseString() throws -> String {
            guard currentCharacter == "\"" else {
                throw XCStringsError.invalidJSON(reason: "Expected string")
            }

            let start = index
            advance()

            while let character = currentCharacter {
                if character == "\\" {
                    advance()
                    guard currentCharacter != nil else {
                        throw XCStringsError.invalidJSON(reason: "Unterminated escape sequence")
                    }
                    advance()
                    continue
                }

                if character == "\"" {
                    advance()
                    let literal = String(text[start..<index])
                    let data = Data(literal.utf8)
                    return try JSONDecoder().decode(String.self, from: data)
                }

                advance()
            }

            throw XCStringsError.invalidJSON(reason: "Unterminated string")
        }

        private mutating func parseScalar() throws {
            let start = index
            while let character = currentCharacter,
                  !character.isWhitespace,
                  character != ",",
                  character != "]",
                  character != "}" {
                advance()
            }

            guard start != index else {
                throw XCStringsError.invalidJSON(reason: "Expected scalar value")
            }
        }

        private mutating func consume(_ expected: Character) throws {
            skipWhitespace()
            guard currentCharacter == expected else {
                throw XCStringsError.invalidJSON(reason: "Expected '\(expected)'")
            }
            advance()
        }

        private mutating func skipWhitespace() {
            while currentCharacter?.isWhitespace == true {
                advance()
            }
        }

        private var currentCharacter: Character? {
            index == text.endIndex ? nil : text[index]
        }

        private mutating func advance() {
            index = text.index(after: index)
        }
    }
}
