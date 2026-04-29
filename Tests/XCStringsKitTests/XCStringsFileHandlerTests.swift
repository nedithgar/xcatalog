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
}
