import Foundation
import Testing
@testable import XCStringsKit

@Suite("Ordered string dictionary")
struct OrderedStringDictionaryTests {
    @Test("subscript update and removal keep lookups and order in sync")
    func subscriptUpdateAndRemovalKeepLookupsAndOrderInSync() {
        var dictionary = OrderedStringDictionary<Int>()
        dictionary["a"] = 1
        dictionary["b"] = 2
        dictionary["c"] = 3

        dictionary["b"] = 20
        #expect(dictionary.keys == ["a", "b", "c"])
        #expect(dictionary["b"] == 20)

        #expect(dictionary.removeValue(forKey: "b") == 20)
        #expect(dictionary.keys == ["a", "c"])
        #expect(dictionary["b"] == nil)
        #expect(dictionary["c"] == 3)

        dictionary["d"] = 4
        #expect(dictionary.keys == ["a", "c", "d"])
        #expect(dictionary["d"] == 4)
    }

    @Test("rename updates lookup index without changing order")
    func renameUpdatesLookupIndexWithoutChangingOrder() {
        var dictionary = OrderedStringDictionary<Int>()
        dictionary["first"] = 1
        dictionary["second"] = 2
        dictionary["third"] = 3

        let didRename = dictionary.renameKey(from: "second", to: "middle")
        #expect(didRename)
        #expect(dictionary.keys == ["first", "middle", "third"])
        #expect(dictionary["second"] == nil)
        #expect(dictionary["middle"] == 2)

        let didRenameToExistingKey = dictionary.renameKey(from: "middle", to: "third")
        #expect(!didRenameToExistingKey)
        #expect(dictionary.keys == ["first", "middle", "third"])
        #expect(dictionary["middle"] == 2)
        #expect(dictionary["third"] == 3)
    }

    @Test("decoded dictionaries rebuild lookup index")
    func decodedDictionariesRebuildLookupIndex() throws {
        let data = Data(#"{"z":26,"a":1,"m":13}"#.utf8)
        var dictionary = try JSONDecoder().decode(OrderedStringDictionary<Int>.self, from: data)

        #expect(dictionary["a"] == 1)
        #expect(dictionary.removeValue(forKey: "z") == 26)
        #expect(dictionary["m"] == 13)

        dictionary["a"] = 10
        #expect(dictionary["a"] == 10)
    }

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

    @Test("sortedByKey returns key value pairs without mutating order")
    func sortedByKeyReturnsPairsWithoutMutatingOrder() throws {
        var dictionary = OrderedStringDictionary<Int>()
        dictionary["z"] = 26
        dictionary["a"] = 1
        dictionary["m"] = 13

        let sorted = dictionary.sortedByKey()

        #expect(sorted.map(\.key) == ["a", "m", "z"])
        #expect(sorted.map(\.value) == [1, 13, 26])
        #expect(dictionary.keys == ["z", "a", "m"])
    }
}
