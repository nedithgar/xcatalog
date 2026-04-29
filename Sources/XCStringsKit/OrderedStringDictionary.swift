import Foundation

/// A small string-keyed ordered dictionary for JSON objects whose source order
/// matters in version control, such as `.xcstrings` `strings` and `localizations`.
package struct OrderedStringDictionary<Value: Codable & Sendable>: Codable, Sendable, ExpressibleByDictionaryLiteral, Sequence {
    package typealias Element = (key: String, value: Value)

    private var elements: [Element]

    package init() {
        self.elements = []
    }

    package init(_ elements: [Element]) {
        self.elements = []
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
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        for (key, value) in elements {
            try container.encode(value, forKey: DynamicCodingKey(key))
        }
    }

    package subscript(key: String) -> Value? {
        get {
            elements.first { $0.key == key }?.value
        }
        set {
            guard let newValue else {
                _ = removeValue(forKey: key)
                return
            }

            if let index = elements.firstIndex(where: { $0.key == key }) {
                elements[index].value = newValue
            } else {
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
        guard let index = elements.firstIndex(where: { $0.key == key }) else {
            return nil
        }

        return elements.remove(at: index).value
    }

    @discardableResult
    package mutating func renameKey(from oldKey: String, to newKey: String) -> Bool {
        guard let index = elements.firstIndex(where: { $0.key == oldKey }),
              !elements.contains(where: { $0.key == newKey }) else {
            return false
        }

        elements[index].key = newKey
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
