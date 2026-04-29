import Foundation
import Testing
@testable import XCStringsKit

@Suite("Ordered string dictionary")
struct OrderedStringDictionaryTests {
    @Test("reorder follows preferred keys and appends new keys once")
    func reorderFollowsPreferredKeysAndAppendsNewKeysOnce() {
        var dictionary = OrderedStringDictionary<Int>()
        for key in ["a", "b", "c", "d", "e"] {
            dictionary[key] = key.count
        }

        dictionary.reorder(existingKeys: ["d", "b", "missing", "d"])

        #expect(dictionary.keys == ["d", "b", "a", "c", "e"])
        #expect(dictionary.count == 5)
    }

    @Test("reorder preserves values for large catalog key orders")
    func reorderPreservesValuesForLargeCatalogKeyOrders() throws {
        let keyCount = 5_000
        var dictionary = OrderedStringDictionary<Int>()
        for index in 0..<keyCount {
            dictionary["key.\(index)"] = index
        }

        let preferredKeys = (0..<keyCount).reversed().map { "key.\($0)" }
        dictionary.reorder(existingKeys: preferredKeys)

        #expect(dictionary.keys.first == "key.\(keyCount - 1)")
        #expect(dictionary.keys.last == "key.0")
        #expect(dictionary.count == keyCount)
        #expect(dictionary["key.4321"] == 4321)
    }

    @Test("mutateValues updates entries without changing order")
    func mutateValuesUpdatesEntriesWithoutChangingOrder() throws {
        var dictionary: OrderedStringDictionary<Int> = [
            "first": 1,
            "second": 2,
            "third": 3,
        ]

        dictionary.mutateValues { key, value in
            value += key.count
        }

        #expect(dictionary.keys == ["first", "second", "third"])
        #expect(dictionary["first"] == 6)
        #expect(dictionary["second"] == 8)
        #expect(dictionary["third"] == 8)
    }
}
