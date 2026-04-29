import Foundation
import Testing
@testable import XCStringsKit

@Suite("XCStringsKit error and model coverage")
struct XCStringsKitCoverageTests {
    @Test("XCStringsError descriptions cover every public case")
    func xcstringsErrorDescriptions() {
        let cases: [(XCStringsError, String)] = [
            (.fileNotFound(path: "/tmp/Missing.xcstrings"), "File not found: /tmp/Missing.xcstrings"),
            (.fileAlreadyExists(path: "/tmp/Existing.xcstrings"), "File already exists: /tmp/Existing.xcstrings"),
            (.invalidFileFormat(path: "/tmp/File.xcstrings", reason: "bad json"), "Invalid file format at '/tmp/File.xcstrings': bad json"),
            (.keyNotFound(key: "Hello"), "Key not found: 'Hello'"),
            (.keyAlreadyExists(key: "Hello:ja"), "Key already exists: 'Hello:ja'"),
            (.languageNotFound(language: "ja", key: "Hello"), "Language 'ja' not found for key 'Hello'"),
            (.nonTranslatableKey(key: "BrandName"), "Cannot add or update translations for non-translatable key 'BrandName'. Change shouldTranslate before writing localizations."),
            (.unsafeFormatString(key: "Photo", language: "es", diagnostics: ["Missing %1$@."]), "Unsafe format string for key 'Photo' language 'es': Missing %1$@."),
            (.richLocalizationUnsupported(key: "Items", language: "es"), "Cannot add or update plain stringUnit translation for key 'Items' language 'es' because the source or target localization uses variations or substitutions. Use a variation-aware operation instead."),
            (.concurrentWriteConflict(path: "/tmp/File.xcstrings"), "Concurrent write conflict for '/tmp/File.xcstrings'. Another write is already modifying this catalog; retry the operation or use a batch write."),
            (.writeError(path: "/tmp/File.xcstrings", reason: "disk full"), "Failed to write file at '/tmp/File.xcstrings': disk full"),
            (.invalidJSON(reason: "Unexpected token"), "Invalid JSON: Unexpected token"),
        ]

        for (error, expected) in cases {
            #expect(error.localizedDescription == expected)
        }
    }

    @Test("CLIResult helpers produce stable payloads")
    func cliResultHelpers() {
        let manual = CLIResult(success: true, message: "created", error: nil)
        let success = CLIResult.success(message: "saved")
        let failure = CLIResult.failure(error: "boom")

        #expect(manual.success == true)
        #expect(manual.message == "created")
        #expect(manual.error == nil)

        #expect(success.success == true)
        #expect(success.message == "saved")
        #expect(success.error == nil)

        #expect(failure.success == false)
        #expect(failure.message == nil)
        #expect(failure.error == "boom")
    }

    @Test("variation model initializers preserve provided values")
    func variationInitializers() {
        let zero = VariationValue(stringUnit: StringUnit(value: "zero"))
        let other = VariationValue(stringUnit: StringUnit(value: "other"))
        let iphone = VariationValue(stringUnit: StringUnit(value: "Tap"))
        let mac = VariationValue(stringUnit: StringUnit(value: "Click"))
        let plural = PluralVariation(zero: zero, one: nil, two: nil, few: nil, many: nil, other: other)
        let device = DeviceVariation(iphone: iphone, ipad: nil, mac: mac, applewatch: nil, appletv: nil)
        let variations = Variations(plural: plural, device: device)
        let localization = Localization(variations: variations)

        #expect(localization.variations?.plural?.zero?.stringUnit?.value == "zero")
        #expect(localization.variations?.plural?.other?.stringUnit?.value == "other")
        #expect(localization.variations?.device?.iphone?.stringUnit?.value == "Tap")
        #expect(localization.variations?.device?.mac?.stringUnit?.value == "Click")
    }

    @Test("CoverageMeasurement covers direct init, fallback parsing, and completion helpers")
    func coverageMeasurementHelpers() throws {
        let direct = CoverageMeasurement(state: .measured, percent: 42.5)
        let tinyScientific = CoverageMeasurement.measured(1e-129)
        let infinite = CoverageMeasurement.measured(Double.infinity)
        let complete = CoverageMeasurement.measured(100.0)
        let decoded = try CoverageMeasurement(from: DoubleOnlyCoverageDecoder(percent: 12.5))

        #expect(direct.state == .measured)
        #expect(direct.percent == 42.5)

        #expect(tinyScientific.rawPercent != nil)
        #expect(tinyScientific.isIncomplete)

        #expect(infinite.state == .measured)
        #expect(infinite.rawPercent == nil)
        #expect(infinite.percent == nil)
        #expect(infinite.isIncomplete)

        #expect(complete.isComplete)
        #expect(!complete.isIncomplete)
        #expect(!complete.isNotApplicable)
        #expect(CoverageMeasurement.notApplicable.isNotApplicable)

        #expect(decoded.state == .measured)
        #expect(decoded.percent == 12.5)

        #expect(CompactCompletionState.from(totalLanguages: 1, incompleteCount: 0, notApplicableCount: 0) == .complete)
    }

    @Test("CompactAggregatedCoverage omits not-applicable languages when none exist")
    func compactAggregatedCoverageCompleteState() {
        let aggregate = AggregatedCoverage(
            totalFiles: 1,
            totalKeys: 1,
            averageCoverageByLanguage: ["en": .measured(100.0)]
        )
        let compact = CompactAggregatedCoverage(from: aggregate)

        #expect(compact.completionState == .complete)
        #expect(compact.incompleteLanguages == nil)
        #expect(compact.notApplicableLanguages == nil)
    }

    @Test("CompactAggregatedCoverage preserves not-applicable languages when present")
    func compactAggregatedCoverageNotApplicableState() {
        let aggregate = AggregatedCoverage(
            totalFiles: 1,
            totalKeys: 0,
            averageCoverageByLanguage: ["ja": .notApplicable]
        )
        let compact = CompactAggregatedCoverage(from: aggregate)

        #expect(compact.completionState == .notApplicable)
        #expect(compact.notApplicableLanguages == ["ja"])
    }

    @Test("BatchWriteResult encodes failed entries only when present")
    func batchWriteResultEncoding() throws {
        let failed = BatchWriteResult(
            succeeded: [],
            failed: [BatchWriteError(key: "Hello", error: "write failed")]
        )
        let encoded = try encodeJSON(failed)

        #expect(encoded.contains("\"failed\""))
        #expect(encoded.contains("\"write failed\""))
        #expect(!encoded.contains("\"succeeded\""))
    }

    @Test("StringEntry translation semantics treat non-translatable entries as already covered")
    func stringEntryTranslationSemantics() {
        let entry = StringEntry(shouldTranslate: false)

        #expect(entry.requiresTranslation == false)
        #expect(entry.countsAsTranslated(for: "fr") == true)
    }

    private func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONEncoder().encode(value)
        return try #require(String(data: data, encoding: .utf8))
    }
}

@Suite("XCStringsParser coverage")
struct XCStringsParserCoverageTests {
    @Test("instance createFile creates a new catalog on disk")
    func instanceCreateFile() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("create_\(UUID().uuidString).xcstrings")
            .path
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        try await parser.createFile(sourceLanguage: "fr")

        #expect(FileManager.default.fileExists(atPath: path))
        #expect(try await parser.getSourceLanguage() == "fr")
    }

    @Test("getBatchCoverage loads multiple files through the parser facade")
    func getBatchCoverage() throws {
        let first = try TestHelper.createTempFile(content: TestFixtures.singleKeySingleLang)
        let second = try TestHelper.createTempFile(content: TestFixtures.empty)
        defer {
            TestHelper.removeTempFile(at: first)
            TestHelper.removeTempFile(at: second)
        }

        let summary = try XCStringsParser.getBatchCoverage(paths: [first, second])

        #expect(summary.files.count == 2)
        #expect(summary.aggregated.totalFiles == 2)
        #expect(summary.aggregated.averageCoverageByLanguage["en"]?.state == .measured)
        #expect(summary.aggregated.averageCoverageByLanguage["en"]?.percent == 100.0)
    }

    @Test("getCompactBatchCoverage loads multiple files through the parser facade")
    func getCompactBatchCoverage() throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.singleKeySingleLang)
        defer { TestHelper.removeTempFile(at: path) }

        let summary = try XCStringsParser.getCompactBatchCoverage(paths: [path])
        let fileSummary = try #require(summary.files.first)

        #expect(summary.files.count == 1)
        #expect(summary.aggregated.totalFiles == 1)
        #expect(fileSummary.completionState == .complete)
        #expect(fileSummary.incompleteLanguages == nil)
        #expect(fileSummary.notApplicableLanguages == nil)
        #expect(summary.aggregated.completionState == .complete)
        #expect(summary.aggregated.incompleteLanguages == nil)
        #expect(summary.aggregated.notApplicableLanguages == nil)
    }

    @Test("addTranslations populates keys that previously had no localizations")
    func addTranslations() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.emptyLocalizations)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        try await parser.addTranslations(
            key: "NoTranslation",
            translations: ["en": "Hello", "fr": "Bonjour"]
        )

        let translations = try await parser.getTranslation(key: "NoTranslation", language: nil)
        #expect(translations.count == 2)
        #expect(translations["fr"]?.value == "Bonjour")
    }

    @Test("updateTranslations updates multiple existing localizations")
    func updateTranslations() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.singleKeyMultipleLangs)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        try await parser.updateTranslations(
            key: "Hello",
            translations: ["en": "Hi", "ja": "やあ"]
        )

        let translations = try await parser.getTranslation(key: "Hello", language: nil)
        #expect(translations["en"]?.value == "Hi")
        #expect(translations["ja"]?.value == "やあ")
    }

    @Test("deleteTranslations removes multiple localizations while preserving the key")
    func deleteTranslations() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.singleKeyMultipleLangs)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        try await parser.deleteTranslations(key: "Hello", languages: ["de", "ja"])

        #expect(try await parser.checkKey("Hello", language: nil) == true)
        #expect(try await parser.checkKey("Hello", language: "de") == false)
        #expect(try await parser.checkKey("Hello", language: "ja") == false)
        #expect(try await parser.checkKey("Hello", language: "en") == true)
    }
}

private struct DoubleOnlyCoverageDecoder: Decoder {
    let percent: Double
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        KeyedDecodingContainer(Container(percent: percent))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch([Any].self, .init(codingPath: codingPath, debugDescription: "Not supported"))
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        throw DecodingError.typeMismatch(Double.self, .init(codingPath: codingPath, debugDescription: "Not supported"))
    }

    private struct Container<Key: CodingKey>: KeyedDecodingContainerProtocol {
        let percent: Double
        var codingPath: [CodingKey] = []
        var allKeys: [Key] {
            [Key(stringValue: "state"), Key(stringValue: "percent")].compactMap { $0 }
        }

        func contains(_ key: Key) -> Bool {
            allKeys.contains { $0.stringValue == key.stringValue }
        }

        func decodeNil(forKey key: Key) throws -> Bool {
            false
        }

        func decode(_ type: CoverageState.Type, forKey key: Key) throws -> CoverageState {
            .measured
        }

        func decode(_ type: String.Type, forKey key: Key) throws -> String {
            if key.stringValue == "state" {
                return CoverageState.measured.rawValue
            }
            throw mismatch(type, for: key)
        }

        func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
            guard key.stringValue == "percent" else {
                throw mismatch(type, for: key)
            }
            return percent
        }

        func decode(_ type: Float.Type, forKey key: Key) throws -> Float { Float(try decode(Double.self, forKey: key)) }
        func decode(_ type: Int.Type, forKey key: Key) throws -> Int { throw mismatch(type, for: key) }
        func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { throw mismatch(type, for: key) }
        func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { throw mismatch(type, for: key) }
        func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { throw mismatch(type, for: key) }
        func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { throw mismatch(type, for: key) }
        func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { throw mismatch(type, for: key) }
        func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { throw mismatch(type, for: key) }
        func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { throw mismatch(type, for: key) }
        func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { throw mismatch(type, for: key) }
        func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { throw mismatch(type, for: key) }
        func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool { throw mismatch(type, for: key) }

        func decodeIfPresent(_ type: CoverageState.Type, forKey key: Key) throws -> CoverageState? {
            contains(key) ? .measured : nil
        }

        func decodeIfPresent(_ type: String.Type, forKey key: Key) throws -> String? {
            contains(key) ? try decode(type, forKey: key) : nil
        }

        func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? {
            key.stringValue == "percent" ? percent : nil
        }

        func decodeIfPresent(_ type: Decimal.Type, forKey key: Key) throws -> Decimal? {
            nil
        }

        func decodeIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? {
            try decodeIfPresent(Double.self, forKey: key).map(Float.init)
        }

        func decodeIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? { throw mismatch(type, for: key) }
        func decodeIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8? { throw mismatch(type, for: key) }
        func decodeIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16? { throw mismatch(type, for: key) }
        func decodeIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32? { throw mismatch(type, for: key) }
        func decodeIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? { throw mismatch(type, for: key) }
        func decodeIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt? { throw mismatch(type, for: key) }
        func decodeIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8? { throw mismatch(type, for: key) }
        func decodeIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? { throw mismatch(type, for: key) }
        func decodeIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? { throw mismatch(type, for: key) }
        func decodeIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? { throw mismatch(type, for: key) }
        func decodeIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool? { throw mismatch(type, for: key) }

        func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
            if type == CoverageState.self {
                return CoverageState.measured as! T
            }
            if type == String.self, key.stringValue == "state" {
                return CoverageState.measured.rawValue as! T
            }
            if type == Double.self, key.stringValue == "percent" {
                return percent as! T
            }
            throw mismatch(type, for: key)
        }

        func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
            if type == Decimal.self {
                return nil
            }
            if type == CoverageState.self, contains(key) {
                return CoverageState.measured as? T
            }
            if type == String.self, key.stringValue == "state" {
                return CoverageState.measured.rawValue as? T
            }
            if type == Double.self, key.stringValue == "percent" {
                return percent as? T
            }
            throw mismatch(type, for: key)
        }

        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
            throw mismatch(type, for: key)
        }

        func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
            throw mismatch([Any].self, for: key)
        }

        func superDecoder() throws -> Decoder {
            DoubleOnlyCoverageDecoder(percent: percent)
        }

        func superDecoder(forKey key: Key) throws -> Decoder {
            DoubleOnlyCoverageDecoder(percent: percent)
        }

        private func mismatch(_ type: Any.Type, for key: Key) -> DecodingError {
            DecodingError.typeMismatch(
                type,
                .init(codingPath: codingPath + [key], debugDescription: "Unsupported test decode for \(key.stringValue)")
            )
        }
    }
}
