import Foundation
import Testing
@testable import XCStringsKit

@Suite("Catalog persistence regression coverage")
struct CatalogPersistenceRegressionTests {
    private let spanishTranslations: [String: String] = [
        "sample.action.import": "Importar",
        "sample.action.preview": "Vista previa",
        "sample.export.saved": "Exportación guardada",
        "sample.export.saveCopyDetail": "Guardar como un archivo nuevo sin detalles adicionales.",
        "sample.library.itemAccessibilityLabel": "Elemento, %1$@, %2$lld por %3$lld píxeles",
        "sample.library.people": "Personas",
    ]

    @Test("Batch add touches only intended Spanish localizations")
    func batchAddTouchesOnlySpanishLocalizations() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.catalogPersistenceRegression)
        defer { TestHelper.removeTempFile(at: path) }

        let originalFile = try decodeFixture(TestFixtures.catalogPersistenceRegression)
        let parser = XCStringsParser(path: path)
        let entries = spanishTranslations.map { key, value in
            BatchTranslationEntry(key: key, translations: ["es": value])
        }

        let result = try await parser.addTranslationsBatch(entries: entries)

        #expect(result.successCount == spanishTranslations.count)
        #expect(result.failedCount == 0)
        #expect(Set(result.succeeded) == Set(spanishTranslations.keys))

        let updatedFile = try await parser.load()
        #expect(updatedFile.sourceLanguage == originalFile.sourceLanguage)
        #expect(updatedFile.version == originalFile.version)
        #expect(Set(updatedFile.strings.keys) == Set(originalFile.strings.keys))

        for (key, originalEntry) in originalFile.strings {
            let updatedEntry = try #require(updatedFile.strings[key])
            #expect(updatedEntry.comment == originalEntry.comment)
            #expect(updatedEntry.extractionState == originalEntry.extractionState)

            let originalLanguages = localizationLanguages(in: originalEntry)
            let updatedLanguages = localizationLanguages(in: updatedEntry)
            #expect(updatedLanguages == originalLanguages.union(["es"]))

            for language in originalLanguages {
                #expect(
                    updatedEntry.localizations?[language]?.stringUnit?.value ==
                        originalEntry.localizations?[language]?.stringUnit?.value
                )
                #expect(
                    updatedEntry.localizations?[language]?.stringUnit?.state ==
                        originalEntry.localizations?[language]?.stringUnit?.state
                )
            }

            #expect(updatedEntry.localizations?["es"]?.stringUnit?.state == "translated")
            #expect(updatedEntry.localizations?["es"]?.stringUnit?.value == spanishTranslations[key])
        }
    }

    @Test("Batch add preserves catalog key order and trailing newline")
    func batchAddPreservesOrderAndTrailingNewline() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.catalogPersistenceRegression)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let entries = spanishTranslations.map { key, value in
            BatchTranslationEntry(key: key, translations: ["es": value])
        }

        _ = try await parser.addTranslationsBatch(entries: entries)

        let updatedContent = try String(contentsOfFile: path, encoding: .utf8)
        let originalKeyOrder = rootStringKeys(in: TestFixtures.catalogPersistenceRegression)
        let updatedKeyOrder = rootStringKeys(in: updatedContent)

        #expect(updatedKeyOrder == originalKeyOrder)
        #expect(updatedContent.hasSuffix("\n"))

        let reloadedFile = try await parser.load()
        let importLocalizations = try #require(reloadedFile.strings["sample.action.import"]?.localizations)
        #expect(importLocalizations.keys == ["en", "es"])
    }

    @Test("Update preserves catalog key order and trailing newline")
    func updatePreservesOrderAndTrailingNewline() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.catalogPersistenceRegression)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let originalKeyOrder = rootStringKeys(in: TestFixtures.catalogPersistenceRegression)

        try await parser.updateTranslation(
            key: "sample.action.preview",
            language: "en",
            value: "Preview Export"
        )

        let updatedContent = try String(contentsOfFile: path, encoding: .utf8)
        #expect(rootStringKeys(in: updatedContent) == originalKeyOrder)
        #expect(updatedContent.hasSuffix("\n"))
    }

    @Test("Delete preserves remaining catalog key order and trailing newline")
    func deletePreservesRemainingOrderAndTrailingNewline() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.catalogPersistenceRegression)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let deletedKey = "sample.export.saveCopyDetail"
        let expectedKeyOrder = rootStringKeys(in: TestFixtures.catalogPersistenceRegression)
            .filter { $0 != deletedKey }

        try await parser.deleteKey(deletedKey)

        let updatedContent = try String(contentsOfFile: path, encoding: .utf8)
        #expect(rootStringKeys(in: updatedContent) == expectedKeyOrder)
        #expect(updatedContent.hasSuffix("\n"))
    }

    @Test("New catalog keys append after existing keys")
    func newKeysAppendAfterExistingKeys() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.catalogPersistenceRegression)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let originalKeyOrder = rootStringKeys(in: TestFixtures.catalogPersistenceRegression)

        try await parser.addTranslation(
            key: "sample.sidebar.settings",
            language: "en",
            value: "Settings"
        )

        let updatedContent = try String(contentsOfFile: path, encoding: .utf8)
        #expect(rootStringKeys(in: updatedContent) == originalKeyOrder + ["sample.sidebar.settings"])
        #expect(updatedContent.hasSuffix("\n"))
    }

    @Test("Regression fixture compiles with xcstringstool after batch write")
    func regressionFixtureCompilesWithXCStringsTool() async throws {
        guard xcstringstoolIsAvailable() else {
            return
        }

        let path = try TestHelper.createTempFile(content: TestFixtures.catalogPersistenceRegression)
        defer { TestHelper.removeTempFile(at: path) }

        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("xcatalog_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outputDirectory) }

        let parser = XCStringsParser(path: path)
        let entries = spanishTranslations.map { key, value in
            BatchTranslationEntry(key: key, translations: ["es": value])
        }

        _ = try await parser.addTranslationsBatch(entries: entries)

        let result = try runProcess(
            executable: "/usr/bin/xcrun",
            arguments: [
                "xcstringstool",
                "compile",
                path,
                "--output-directory",
                outputDirectory.path,
                "--language",
                "es",
                "--dry-run",
            ]
        )

        #expect(result.exitStatus == 0, "xcstringstool failed: \(result.standardError)")
    }

    private func decodeFixture(_ content: String) throws -> XCStringsFile {
        let data = try #require(content.data(using: .utf8))
        return try JSONDecoder().decode(XCStringsFile.self, from: data)
    }

    private func localizationLanguages(in entry: StringEntry) -> Set<String> {
        guard let localizations = entry.localizations else {
            return []
        }

        return Set(localizations.keys)
    }

    private func rootStringKeys(in content: String) -> [String] {
        content.split(separator: "\n", omittingEmptySubsequences: false).compactMap { line in
            let line = String(line)
            let prefix = "    \""
            guard line.hasPrefix(prefix), line.hasSuffix("{") else {
                return nil
            }

            let keyStart = line.index(line.startIndex, offsetBy: prefix.count)
            guard let keyEnd = line[keyStart...].firstIndex(of: "\"") else {
                return nil
            }

            return String(line[keyStart..<keyEnd])
        }
    }

    private func xcstringstoolIsAvailable() -> Bool {
        (try? runProcess(executable: "/usr/bin/xcrun", arguments: ["--find", "xcstringstool"]).exitStatus) == 0
    }

    private func runProcess(executable: String, arguments: [String]) throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        try process.run()
        process.waitUntilExit()

        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = error.fileHandleForReading.readDataToEndOfFile()

        return ProcessResult(
            exitStatus: process.terminationStatus,
            standardOutput: String(data: outputData, encoding: .utf8) ?? "",
            standardError: String(data: errorData, encoding: .utf8) ?? ""
        )
    }

    private struct ProcessResult {
        let exitStatus: Int32
        let standardOutput: String
        let standardError: String
    }
}
