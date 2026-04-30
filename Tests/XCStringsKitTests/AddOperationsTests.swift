import Foundation
import Testing
@testable import XCStringsKit

@Suite("Adding new keys and translations to xcstrings files")
struct AddOperationsTests {
    @Test("addTranslation adds new translation to existing key", arguments: [
        (FixtureType.singleKeySingleLang, "Hello", "ja", "こんにちは"),
        (FixtureType.singleKeySingleLang, "Hello", "de", "Hallo"),
        (FixtureType.multipleKeysPartialTranslations, "Goodbye", "ja", "さようなら"),
    ])
    func addTranslationToExistingKey(fixture: FixtureType, key: String, language: String, value: String) async throws {
        let path = try TestHelper.createTempFile(content: fixture.content)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)

        // Verify translation doesn't exist
        let beforeExists = try await parser.checkKey(key, language: language)
        #expect(beforeExists == false)

        // Add translation
        try await parser.addTranslation(key: key, language: language, value: value)

        // Verify translation was added
        let afterExists = try await parser.checkKey(key, language: language)
        #expect(afterExists == true)

        let translations = try await parser.getTranslation(key: key, language: language)
        #expect(translations[language]?.value == value)
    }

    @Test("addTranslation creates new key", arguments: [
        FixtureType.empty,
        FixtureType.singleKeySingleLang,
        FixtureType.multipleKeysPartialTranslations,
    ])
    func addTranslationNewKey(fixture: FixtureType) async throws {
        let path = try TestHelper.createTempFile(content: fixture.content)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let newKey = "BrandNewKey"
        let language = "en"
        let value = "Brand New Value"

        // Verify key doesn't exist
        let beforeExists = try await parser.checkKey(newKey, language: nil)
        #expect(beforeExists == false)

        // Add translation
        try await parser.addTranslation(key: newKey, language: language, value: value)

        // Verify key was created
        let afterExists = try await parser.checkKey(newKey, language: language)
        #expect(afterExists == true)

        let keys = try await parser.listKeys()
        #expect(keys.contains(newKey))
    }

    @Test("addTranslation throws when translation already exists", arguments: [
        (FixtureType.singleKeySingleLang, "Hello", "en"),
        (FixtureType.singleKeyMultipleLangs, "Hello", "ja"),
        (FixtureType.multipleKeysPartialTranslations, "Welcome", "de"),
    ])
    func addTranslationAlreadyExists(fixture: FixtureType, key: String, language: String) async throws {
        let path = try TestHelper.createTempFile(content: fixture.content)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)

        await #expect(throws: XCStringsError.self) {
            try await parser.addTranslation(key: key, language: language, value: "New Value")
        }
    }

    @Test("addTranslation rejects non-translatable keys")
    func addTranslationRejectsNonTranslatableKey() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.withNonTranslatableKey)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)

        await #expect(throws: XCStringsError.self) {
            try await parser.addTranslation(key: "BrandName", language: "ja", value: "ブランド名")
        }

        let keyInfo = try await parser.getKey("BrandName")
        #expect(keyInfo.shouldTranslate == false)
        #expect(keyInfo.translations.isEmpty)
    }

    @Test("addTranslation preserves unrelated substitution records in the same catalog")
    func addTranslationPreservesUnrelatedSubstitutions() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.withSubstitutions)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)

        try await parser.addTranslation(key: "plain.key", language: "es", value: "Simple")

        let handler = XCStringsFileHandler(path: path)
        let file = try handler.load()
        let substitution = file.strings["items.count"]?.localizations?["en"]?.substitutions?["itemCount"]
        #expect(substitution?.argNum == 1)
        #expect(substitution?.formatSpecifier == "lld")
        #expect(substitution?.variations?.plural?.one?.stringUnit?.value == "%arg item")
    }

    @Test("addTranslation creates a localization container for keys without localizations")
    func addTranslationCreatesMissingLocalizationContainer() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.emptyLocalizations)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)

        try await parser.addTranslation(key: "NoTranslation", language: "en", value: "Now Localized")

        let translation = try await parser.getTranslation(key: "NoTranslation", language: "en")
        #expect(translation["en"]?.value == "Now Localized")
    }

    @Test("addTranslation reports placeholder validations")
    func addTranslationReportsPlaceholderValidations() async throws {
        let path = try TestHelper.createTempFile(content: TestFixtures.catalogPersistenceRegression)
        defer { TestHelper.removeTempFile(at: path) }

        let parser = XCStringsParser(path: path)
        let result = try await parser.addTranslation(
            key: "sample.library.itemAccessibilityLabel",
            language: "es",
            value: "Pixels: %2$lld by %3$lld, item %1$@"
        )

        #expect(result.placeholderValidations.filter(\.checked).count == 1)
        #expect(result.placeholderValidations.first?.isValid == true)
        #expect(result.languageResults.first?.placeholderValidation?.checked == true)
    }
}
