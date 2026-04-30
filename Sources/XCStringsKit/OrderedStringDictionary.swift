import Foundation

/// A small string-keyed ordered dictionary for JSON objects whose source order
/// matters in version control, such as `.xcstrings` `strings` and `localizations`.
package struct OrderedStringDictionary<Value: Codable & Sendable>: Codable, Sendable, ExpressibleByDictionaryLiteral, Sequence {
    package typealias Element = (key: String, value: Value)

    private var elements: [Element]
    private var indicesByKey: [String: Int]

    package init() {
        self.elements = []
        self.indicesByKey = [:]
    }

    package init(_ elements: [Element]) {
        self.elements = []
        self.indicesByKey = [:]
        for element in elements {
            self[element.key] = element.value
        }
    }

    package init(_ dictionary: [String: Value]) {
        self.init(dictionary.keys.sorted().map { key in
            (key, dictionary[key]!)
        })
    }

    package init(dictionaryLiteral elements: (String, Value)...) {
        self.init(elements)
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        self.elements = try container.allKeys.map { key in
            (key.stringValue, try container.decode(Value.self, forKey: key))
        }
        self.indicesByKey = Self.indicesByKey(for: elements)
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        for (key, value) in elements {
            try container.encode(value, forKey: DynamicCodingKey(key))
        }
    }

    package subscript(key: String) -> Value? {
        get {
            guard let index = indicesByKey[key] else {
                return nil
            }

            return elements[index].value
        }
        set {
            guard let newValue else {
                _ = removeValue(forKey: key)
                return
            }

            if let index = indicesByKey[key] {
                elements[index].value = newValue
            } else {
                indicesByKey[key] = elements.count
                elements.append((key, newValue))
            }
        }
    }

    package var count: Int {
        elements.count
    }

    package var isEmpty: Bool {
        elements.isEmpty
    }

    package var keys: [String] {
        elements.map(\.key)
    }

    package var values: [Value] {
        elements.map(\.value)
    }

    package func sortedByKey() -> [Element] {
        elements.sorted { $0.key < $1.key }
    }

    @discardableResult
    package mutating func removeValue(forKey key: String) -> Value? {
        guard let index = indicesByKey.removeValue(forKey: key) else {
            return nil
        }

        let removedValue = elements.remove(at: index).value
        refreshIndices(startingAt: index)
        return removedValue
    }

    @discardableResult
    package mutating func renameKey(from oldKey: String, to newKey: String) -> Bool {
        guard let index = indicesByKey[oldKey],
              indicesByKey[newKey] == nil else {
            return false
        }

        elements[index].key = newKey
        indicesByKey.removeValue(forKey: oldKey)
        indicesByKey[newKey] = index
        return true
    }

    package mutating func reorder(existingKeys preferredKeys: [String]) {
        let elementsByKey = Dictionary(uniqueKeysWithValues: elements.map { ($0.key, $0) })
        var reordered: [Element] = []
        var consumed = Set<String>()

        for key in preferredKeys {
            guard let element = elementsByKey[key], !consumed.contains(key) else {
                continue
            }

            reordered.append(element)
            consumed.insert(key)
        }

        reordered.append(contentsOf: elements.filter { !consumed.contains($0.key) })
        elements = reordered
        indicesByKey = Self.indicesByKey(for: elements)
    }

    package mutating func mutateValues(_ body: (String, inout Value) throws -> Void) rethrows {
        for index in elements.indices {
            let key = elements[index].key
            try body(key, &elements[index].value)
        }
    }

    package func makeIterator() -> IndexingIterator<[Element]> {
        elements.makeIterator()
    }

    private mutating func refreshIndices(startingAt startIndex: Int) {
        guard startIndex < elements.count else {
            return
        }

        for index in startIndex..<elements.count {
            indicesByKey[elements[index].key] = index
        }
    }

    private static func indicesByKey(for elements: [Element]) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: elements.enumerated().map { index, element in
            (element.key, index)
        })
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}
