import ArgumentParser
import Testing
@testable import XCStringsCLI

@Suite("CLI compact option parsing")
struct CompactOptionParsingTests {
    @Test("list preflight parses compact flag")
    func listPreflightParsesCompactFlag() throws {
        let command = try ListCommand.Preflight.parse([
            "--file", "/tmp/Localizable.xcstrings",
            "--lang", "es",
            "--compact",
        ])

        #expect(command.file == "/tmp/Localizable.xcstrings")
        #expect(command.lang == "es")
        #expect(command.compact)
    }

    @Test("batch supplement parses compact flag")
    func batchSupplementParsesCompactFlag() throws {
        let command = try BatchCommand.Supplement.parse([
            "--file", "/tmp/Localizable.xcstrings",
            "--lang", "es",
            "--entries", "Hello=Hola",
            "--compact",
        ])

        #expect(command.file == "/tmp/Localizable.xcstrings")
        #expect(command.lang == "es")
        #expect(command.entries == ["Hello=Hola"])
        #expect(command.compact)
    }

    @Test("validate catalog parses compact flag")
    func validateCatalogParsesCompactFlag() throws {
        let command = try ValidateCommand.Catalog.parse([
            "--file", "/tmp/Localizable.xcstrings",
            "--compact",
        ])

        #expect(command.file == "/tmp/Localizable.xcstrings")
        #expect(command.compact)
    }
}
