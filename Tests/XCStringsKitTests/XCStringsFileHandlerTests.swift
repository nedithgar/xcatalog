import Foundation
import Testing
@testable import XCStringsKit

@Suite("File I/O operations for xcstrings files")
struct XCStringsFileHandlerTests {
    @Test("load returns XCStringsFile for valid file")
    func loadValidFile() throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.singleKeySingleLang)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = XCStringsFileHandler(path: path)
        let file = try handler.load()

        #expect(file.sourceLanguage == "en")
        #expect(file.strings.count == 1)
    }

    @Test("load decodes substitution-backed keys")
    func loadDecodesSubstitutionKeys() throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.withSubstitutions)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = XCStringsFileHandler(path: path)
        let file = try handler.load()

        let localization = try #require(file.strings["items.count"]?.localizations?["en"])
        let substitution = try #require(localization.substitutions?["itemCount"])

        #expect(localization.stringUnit?.value == "%#@itemCount@")
        #expect(substitution.argNum == 1)
        #expect(substitution.formatSpecifier == "lld")
        #expect(substitution.variations?.plural?.one?.stringUnit?.value == "%arg item")
        #expect(substitution.variations?.plural?.other?.stringUnit?.value == "%arg items")
    }

    @Test("save preserves substitutions and unknown fields")
    func savePreservesSubstitutionsAndUnknownFields() throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.withSubstitutions)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = XCStringsFileHandler(path: path)
        let file = try handler.load()

        try handler.save(file)

        let reloaded = try handler.load()
        let entry = try #require(reloaded.strings["items.count"])
        let localization = try #require(entry.localizations?["en"])
        let substitution = try #require(localization.substitutions?["itemCount"])

        #expect(entry.unknownFields["developerMetadata"] != nil)
        #expect(localization.unknownFields["localizationNote"] != nil)
        #expect(substitution.unknownFields["substitutionNote"] != nil)
        #expect(substitution.variations?.plural?.one?.stringUnit?.value == "%arg item")
    }

    @Test("load throws fileNotFound for non-existent path")
    func loadNonExistentFile() {
        let handler = XCStringsFileHandler(path: "/nonexistent/path/file.xcstrings")

        #expect(throws: XCStringsError.self) {
            _ = try handler.load()
        }
    }

    @Test("load throws invalidFileFormat for invalid JSON")
    func loadInvalidJSON() throws {
        let path = try TestHelper.createTempFile(content: "{ invalid json }")
        defer { TestHelper.removeTempFile(at: path) }

        let handler = XCStringsFileHandler(path: path)

        #expect(throws: XCStringsError.self) {
            _ = try handler.load()
        }
    }

    @Test("load throws invalidFileFormat when path points to a directory")
    func loadDirectoryPath() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("xcatalog_dir_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let handler = XCStringsFileHandler(path: directory.path)

        #expect(throws: XCStringsError.self) {
            _ = try handler.load()
        }
    }

    @Test("save writes file to disk")
    func saveFile() throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.empty)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = XCStringsFileHandler(path: path)
        var file = try handler.load()

        file.strings["NewKey"] = StringEntry(localizations: [
            "en": Localization(stringUnit: StringUnit(state: "translated", value: "New Value")),
        ])

        try handler.save(file)

        // Verify by loading again
        let reloaded = try handler.load()
        #expect(reloaded.strings["NewKey"] != nil)
        #expect(reloaded.strings["NewKey"]?.localizations?["en"]?.stringUnit?.value == "New Value")
    }

    @Test("save preserves file structure")
    func savePreservesStructure() throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.singleKeyMultipleLangs)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = XCStringsFileHandler(path: path)
        let original = try handler.load()

        try handler.save(original)

        let reloaded = try handler.load()
        #expect(reloaded.sourceLanguage == original.sourceLanguage)
        #expect(reloaded.version == original.version)
        #expect(reloaded.strings.count == original.strings.count)
    }

    @Test("save preserves an existing file without trailing newline")
    func savePreservesMissingTrailingNewline() throws {
        let content = #"{"sourceLanguage":"en","strings":{},"version":"1.0"}"#
        let path = try TestHelper.createTempFile(content: content)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = XCStringsFileHandler(path: path)
        let file = try handler.load()

        try handler.save(file)

        let savedContent = try String(contentsOfFile: path, encoding: .utf8)
        #expect(!savedContent.hasSuffix("\n"))
    }

    @Test("save preserves trailing newline according to the existing file's final byte", arguments: TrailingNewlineSaveCase.cases)
    func savePreservesTrailingNewlineFinalByte(testCase: TrailingNewlineSaveCase) throws {
        let path = try TestHelper.createTempFile(content: testCase.content)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = XCStringsFileHandler(path: path)
        let file = try handler.load()

        try handler.save(file)

        let savedData = try Data(contentsOf: URL(fileURLWithPath: path))
        #expect((savedData.last == UInt8(0x0A)) == testCase.expectedHasTrailingNewline)
    }

    @Test("save writes trailing newline when target file does not exist yet")
    func saveMissingFileDefaultsToTrailingNewline() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("saved_\(UUID().uuidString).xcstrings")
        defer { try? FileManager.default.removeItem(at: url) }

        let handler = XCStringsFileHandler(path: url.path)
        try handler.save(XCStringsFile(sourceLanguage: "en"))

        let savedData = try Data(contentsOf: url)
        #expect(savedData.last == UInt8(0x0A))
    }

    @Test("trailing newline detector reports final byte semantics", arguments: TrailingNewlineDetectionCase.cases)
    func trailingNewlineDetectorReportsFinalByte(testCase: TrailingNewlineDetectionCase) throws {
        let url = try createTempDataFile(bytes: testCase.bytes)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(XCStringsFileTrailingNewlineDetector.hasTrailingNewline(at: url) == testCase.expected)
    }

    @Test("trailing newline detector returns nil for a missing path")
    func trailingNewlineDetectorMissingPath() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing_\(UUID().uuidString).xcstrings")

        #expect(XCStringsFileTrailingNewlineDetector.hasTrailingNewline(at: url) == nil)
    }

    @Test("trailing newline detector returns nil for a directory path")
    func trailingNewlineDetectorDirectoryPath() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("xcatalog_dir_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(XCStringsFileTrailingNewlineDetector.hasTrailingNewline(at: url) == nil)
    }

    @Test("trailing newline detector handles large files from the final byte")
    func trailingNewlineDetectorHandlesLargeFiles() throws {
        let bytes = [UInt8](repeating: 0x20, count: 1_048_576) + [0x0A]
        let url = try createTempDataFile(bytes: bytes)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(XCStringsFileTrailingNewlineDetector.hasTrailingNewline(at: url) == true)
    }

    @Test("save preserves non-translation metadata")
    func savePreservesNonTranslationMetadata() throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.withNonTranslatableKey)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = XCStringsFileHandler(path: path)
        let original = try handler.load()

        try handler.save(original)

        let reloaded = try handler.load()
        #expect(reloaded.strings["BrandName"]?.comment == "Proper noun shown as-is in every locale")
        #expect(reloaded.strings["BrandName"]?.isCommentAutoGenerated == true)
        #expect(reloaded.strings["BrandName"]?.shouldTranslate == false)
    }

    @Test("save preserves derived real-world sample structure")
    func savePreservesRealWorldSampleStructure() throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.realWorldSample)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = XCStringsFileHandler(path: path)
        let original = try handler.load()

        try handler.save(original)

        let reloaded = try handler.load()
        #expect(reloaded.version == "1.2")
        #expect(reloaded.strings["Hello, world!"]?.isCommentAutoGenerated == true)
        #expect(reloaded.strings["Hello, world!"]?.shouldTranslate == false)
        #expect(reloaded.strings["This view now has a bit more to say."]?.comment == "A description of the additional content in the `ContentView`.")
        #expect(reloaded.strings["This view now has a bit more to say."]?.localizations?["ja"]?.stringUnit?.state == "needs_review")
    }

    @Test("save throws writeError when parent directory is missing")
    func saveWriteError() {
        let missingParent = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("Missing.xcstrings")
        let handler = XCStringsFileHandler(path: missingParent.path)

        #expect(throws: XCStringsError.self) {
            try handler.save(XCStringsFile())
        }
    }

    @Test("create throws fileAlreadyExists when overwrite is false")
    func createFileAlreadyExists() throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.empty)
        defer { TestHelper.removeTempFile(at: path) }

        let handler = XCStringsFileHandler(path: path)

        #expect(throws: XCStringsError.self) {
            try handler.create(sourceLanguage: "en", overwrite: false)
        }
    }

    @Test("create writes a trailing newline")
    func createWritesTrailingNewline() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("created_\(UUID().uuidString).xcstrings")
            .path
        defer { TestHelper.removeTempFile(at: path) }

        let handler = XCStringsFileHandler(path: path)
        try handler.create(sourceLanguage: "en")

        let content = try String(contentsOfFile: path, encoding: .utf8)
        #expect(content.hasSuffix("\n"))
    }

    @Test("create throws writeError when parent directory is missing")
    func createWriteError() {
        let missingParent = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("Create.xcstrings")
        let handler = XCStringsFileHandler(path: missingParent.path)

        #expect(throws: XCStringsError.self) {
            try handler.create(sourceLanguage: "en")
        }
    }

    private func createTempDataFile(bytes: [UInt8]) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).xcstrings")
        try Data(bytes).write(to: url, options: .atomic)
        return url
    }
}

struct TrailingNewlineSaveCase: CustomTestStringConvertible, Sendable {
    let name: String
    let suffix: String
    let expectedHasTrailingNewline: Bool

    var content: String {
        #"{"sourceLanguage":"en","strings":{},"version":"1.0"}"# + suffix
    }

    var testDescription: String { name }

    static let cases: [Self] = [
        Self(name: "line feed", suffix: "\n", expectedHasTrailingNewline: true),
        Self(name: "carriage return plus line feed", suffix: "\r\n", expectedHasTrailingNewline: true),
        Self(name: "no trailing newline", suffix: "", expectedHasTrailingNewline: false),
        Self(name: "carriage return only", suffix: "\r", expectedHasTrailingNewline: false),
        Self(name: "space after line feed", suffix: "\n ", expectedHasTrailingNewline: false),
        Self(name: "tab after line feed", suffix: "\n\t", expectedHasTrailingNewline: false),
    ]
}

struct TrailingNewlineDetectionCase: CustomTestStringConvertible, Sendable {
    let name: String
    let bytes: [UInt8]
    let expected: Bool?

    var testDescription: String { name }

    static let cases: [Self] = [
        Self(name: "empty file", bytes: [], expected: nil),
        Self(name: "single line feed byte", bytes: [0x0A], expected: true),
        Self(name: "single non-newline byte", bytes: [0x20], expected: false),
        Self(name: "carriage return plus line feed", bytes: [0x0D, 0x0A], expected: true),
        Self(name: "carriage return only", bytes: [0x0D], expected: false),
        Self(name: "null byte after line feed", bytes: [0x7B, 0x7D, 0x0A, 0x00], expected: false),
        Self(name: "space after line feed", bytes: [0x7B, 0x7D, 0x0A, 0x20], expected: false),
    ]
}
