import Foundation
import Testing
@testable import XCStringsKit

@Suite("Write and delete operations for xcstrings files")
struct XCStringsWriterTests {
    // MARK: - addTranslation

    @Test("addTranslation adds new key and translation")
    func addTranslationNewKey() throws {
        var file = try loadFixture(TestFixtures.empty)

        file = try XCStringsWriter.addTranslation(to: file, key: "NewKey", language: "en", value: "New Value")

        #expect(file.strings["NewKey"] != nil)
        #expect(file.strings["NewKey"]?.localizations?["en"]?.stringUnit?.value == "New Value")
    }

    @Test("addTranslation adds translation to existing key")
    func addTranslationExistingKey() throws {
        var file = try loadFixture(TestFixtures.singleKeySingleLang)

        file = try XCStringsWriter.addTranslation(to: file, key: "Hello", language: "ja", value: "こんにちは")

        #expect(file.strings["Hello"]?.localizations?["ja"]?.stringUnit?.value == "こんにちは")
        #expect(file.strings["Hello"]?.localizations?["en"]?.stringUnit?.value == "Hello")
    }

    @Test("addTranslation throws when translation exists and allowOverwrite is false")
    func addTranslationThrowsWhenExists() throws {
        let file = try loadFixture(TestFixtures.singleKeySingleLang)

        #expect(throws: XCStringsError.self) {
            _ = try XCStringsWriter.addTranslation(to: file, key: "Hello", language: "en", value: "New Value")
        }
    }

    @Test("addTranslation overwrites when allowOverwrite is true")
    func addTranslationOverwrite() throws {
        var file = try loadFixture(TestFixtures.singleKeySingleLang)

        file = try XCStringsWriter.addTranslation(to: file, key: "Hello", language: "en", value: "Updated", allowOverwrite: true)

        #expect(file.strings["Hello"]?.localizations?["en"]?.stringUnit?.value == "Updated")
    }

    @Test("addTranslation overwrite preserves existing localization metadata")
    func addTranslationOverwritePreservesLocalizationMetadata() throws {
        var file = try loadFixture(Self.catalogWithTargetLocalizationMetadata)

        file = try XCStringsWriter.addTranslation(
            to: file,
            key: "settings.title",
            language: "ja",
            value: "更新済み設定",
            allowOverwrite: true
        )

        assertJapaneseSettingsMetadataPreserved(in: file, value: "更新済み設定")
    }

    @Test("addTranslation rejects non-translatable keys")
    func addTranslationRejectsNonTranslatableKey() throws {
        let file = try loadFixture(TestFixtures.withNonTranslatableKey)

        #expect(throws: XCStringsError.self) {
            _ = try XCStringsWriter.addTranslation(to: file, key: "BrandName", language: "ja", value: "ブランド名")
        }
    }

    @Test("addTranslation accepts reordered positional placeholders")
    func addTranslationAcceptsReorderedPositionalPlaceholders() throws {
        var file = try loadFixture(TestFixtures.catalogPersistenceRegression)

        file = try XCStringsWriter.addTranslation(
            to: file,
            key: "sample.library.itemAccessibilityLabel",
            language: "es",
            value: "Píxeles: %2$lld por %3$lld, elemento %1$@"
        )

        #expect(
            file.strings["sample.library.itemAccessibilityLabel"]?.localizations?["es"]?.stringUnit?.value
                == "Píxeles: %2$lld por %3$lld, elemento %1$@"
        )
    }

    @Test("addTranslation rejects dropped format placeholders")
    func addTranslationRejectsDroppedFormatPlaceholders() throws {
        let file = try loadFixture(TestFixtures.catalogPersistenceRegression)

        #expect(throws: XCStringsError.self) {
            _ = try XCStringsWriter.addTranslation(
                to: file,
                key: "sample.library.itemAccessibilityLabel",
                language: "es",
                value: "Elemento, %1$@, %2$lld píxeles"
            )
        }
    }

    @Test("addTranslation rejects type-changed format placeholders")
    func addTranslationRejectsTypeChangedFormatPlaceholders() throws {
        let file = try loadFixture(TestFixtures.catalogPersistenceRegression)

        #expect(throws: XCStringsError.self) {
            _ = try XCStringsWriter.addTranslation(
                to: file,
                key: "sample.library.itemAccessibilityLabel",
                language: "es",
                value: "Elemento, %1$@, %2$d por %3$lld píxeles"
            )
        }
    }

    @Test("addTranslation rejects dropped i printf placeholder")
    func addTranslationRejectsDroppedIPrintfPlaceholder() throws {
        var file = try loadFixture(TestFixtures.empty)
        file = try XCStringsWriter.addTranslation(
            to: file,
            key: "sample.unreadCount",
            language: "en",
            value: "You have %i unread messages"
        )

        #expect(throws: XCStringsError.self) {
            _ = try XCStringsWriter.addTranslation(
                to: file,
                key: "sample.unreadCount",
                language: "es",
                value: "Tienes mensajes sin leer"
            )
        }
    }

    @Test("addTranslation refuses variation-backed keys")
    func addTranslationRejectsVariationBackedKey() throws {
        let file = try loadFixture(TestFixtures.pluralVariations)

        #expect(throws: XCStringsError.self) {
            _ = try XCStringsWriter.addTranslation(
                to: file,
                key: "%lld items",
                language: "es",
                value: "%lld elementos"
            )
        }
    }

    @Test("addTranslation refuses substitution-backed keys")
    func addTranslationRejectsSubstitutionBackedKey() throws {
        let file = try loadFixture(TestFixtures.withSubstitutions)

        #expect(throws: XCStringsError.self) {
            _ = try XCStringsWriter.addTranslation(
                to: file,
                key: "items.count",
                language: "es",
                value: "%#@itemCount@"
            )
        }
    }

    // MARK: - addTranslations

    @Test("addTranslations adds multiple languages")
    func addTranslationsMultiple() throws {
        var file = try loadFixture(TestFixtures.empty)

        file = try XCStringsWriter.addTranslations(to: file, key: "Greeting", translations: [
            "en": "Hello",
            "ja": "こんにちは",
            "de": "Hallo",
        ])

        #expect(file.strings["Greeting"]?.localizations?["en"]?.stringUnit?.value == "Hello")
        #expect(file.strings["Greeting"]?.localizations?["ja"]?.stringUnit?.value == "こんにちは")
        #expect(file.strings["Greeting"]?.localizations?["de"]?.stringUnit?.value == "Hallo")
    }

    @Test("addTranslations uses incoming source language value for new symbolic keys")
    func addTranslationsUsesIncomingSourceLanguageForNewSymbolicKey() throws {
        var file = try loadFixture(TestFixtures.empty)

        file = try XCStringsWriter.addTranslations(to: file, key: "photo.accessibility.label", translations: [
            "en": "Photo, %@, %lld pixels",
            "es": "Foto, %1$@, %2$lld píxeles",
        ])

        #expect(file.strings["photo.accessibility.label"]?.localizations?["es"]?.stringUnit?.value == "Foto, %1$@, %2$lld píxeles")
    }

    @Test("addTranslations overwrite validates sibling languages against incoming source value")
    func addTranslationsOverwriteValidatesSiblingLanguagesAgainstIncomingSourceValue() throws {
        let file = try loadFixture(Self.catalogWithSiblingSourceUpdate)

        #expect(throws: XCStringsError.self) {
            _ = try XCStringsWriter.addTranslations(
                to: file,
                key: "photo.title",
                translations: [
                    "en": "Photo %@",
                    "es": "Foto",
                ],
                allowOverwrite: true
            )
        }
    }

    @Test("addTranslations rejects non-translatable keys")
    func addTranslationsRejectNonTranslatableKey() throws {
        let file = try loadFixture(TestFixtures.withNonTranslatableKey)

        #expect(throws: XCStringsError.self) {
            _ = try XCStringsWriter.addTranslations(to: file, key: "BrandName", translations: ["ja": "ブランド名"])
        }
    }

    // MARK: - updateTranslation

    @Test("updateTranslation updates existing translation")
    func updateTranslation() throws {
        var file = try loadFixture(TestFixtures.singleKeySingleLang)

        file = try XCStringsWriter.updateTranslation(in: file, key: "Hello", language: "en", value: "Hi there")

        #expect(file.strings["Hello"]?.localizations?["en"]?.stringUnit?.value == "Hi there")
    }

    @Test("updateTranslation preserves existing localization metadata")
    func updateTranslationPreservesLocalizationMetadata() throws {
        var file = try loadFixture(Self.catalogWithTargetLocalizationMetadata)

        file = try XCStringsWriter.updateTranslation(
            in: file,
            key: "settings.title",
            language: "ja",
            value: "更新済み設定"
        )

        assertJapaneseSettingsMetadataPreserved(in: file, value: "更新済み設定")
    }

    @Test("updateTranslation throws for non-existent key")
    func updateTranslationKeyNotFound() throws {
        let file = try loadFixture(TestFixtures.singleKeySingleLang)

        #expect(throws: XCStringsError.self) {
            _ = try XCStringsWriter.updateTranslation(in: file, key: "NonExistent", language: "en", value: "Value")
        }
    }

    @Test("updateTranslation throws for non-existent language")
    func updateTranslationLanguageNotFound() throws {
        let file = try loadFixture(TestFixtures.singleKeySingleLang)

        #expect(throws: XCStringsError.self) {
            _ = try XCStringsWriter.updateTranslation(in: file, key: "Hello", language: "ja", value: "Value")
        }
    }

    @Test("updateTranslation rejects non-translatable keys")
    func updateTranslationRejectsNonTranslatableKey() throws {
        let file = try loadFixture(TestFixtures.withLocaleOnlyOnNonTranslatableKey)

        #expect(throws: XCStringsError.self) {
            _ = try XCStringsWriter.updateTranslation(in: file, key: "BrandName", language: "ja", value: "更新済み")
        }
    }

    // MARK: - updateTranslations

    @Test("updateTranslations updates multiple languages")
    func updateTranslationsMultiple() throws {
        var file = try loadFixture(TestFixtures.singleKeyMultipleLangs)

        file = try XCStringsWriter.updateTranslations(in: file, key: "Hello", translations: [
            "en": "Hi",
            "ja": "やあ",
            "de": "Hi",
        ])

        #expect(file.strings["Hello"]?.localizations?["en"]?.stringUnit?.value == "Hi")
        #expect(file.strings["Hello"]?.localizations?["ja"]?.stringUnit?.value == "やあ")
        #expect(file.strings["Hello"]?.localizations?["de"]?.stringUnit?.value == "Hi")
    }

    @Test("updateTranslations preserves existing localization metadata")
    func updateTranslationsPreservesLocalizationMetadata() throws {
        var file = try loadFixture(Self.catalogWithTargetLocalizationMetadata)

        file = try XCStringsWriter.updateTranslations(
            in: file,
            key: "settings.title",
            translations: ["ja": "更新済み設定"]
        )

        assertJapaneseSettingsMetadataPreserved(in: file, value: "更新済み設定")
    }

    @Test("updateTranslations validates sibling languages against incoming source value")
    func updateTranslationsValidatesSiblingLanguagesAgainstIncomingSourceValue() throws {
        let file = try loadFixture(Self.catalogWithSiblingSourceUpdate)

        #expect(throws: XCStringsError.self) {
            _ = try XCStringsWriter.updateTranslations(
                in: file,
                key: "photo.title",
                translations: [
                    "en": "Photo %@",
                    "es": "Foto",
                ]
            )
        }
    }

    @Test("updateTranslations accepts sibling languages that preserve incoming source placeholders")
    func updateTranslationsAcceptsSiblingLanguagesPreservingIncomingSourcePlaceholders() throws {
        var file = try loadFixture(Self.catalogWithSiblingSourceUpdate)

        file = try XCStringsWriter.updateTranslations(
            in: file,
            key: "photo.title",
            translations: [
                "en": "Photo %@",
                "es": "Foto %@",
            ]
        )

        #expect(file.strings["photo.title"]?.localizations?["en"]?.stringUnit?.value == "Photo %@")
        #expect(file.strings["photo.title"]?.localizations?["es"]?.stringUnit?.value == "Foto %@")
    }

    @Test("addTranslationsBatch overwrite preserves existing localization metadata")
    func addTranslationsBatchOverwritePreservesLocalizationMetadata() throws {
        let file = try loadFixture(Self.catalogWithTargetLocalizationMetadata)

        let result = XCStringsWriter.addTranslationsBatch(
            to: file,
            entries: [
                BatchTranslationEntry(key: "settings.title", translations: ["ja": "更新済み設定"]),
            ],
            allowOverwrite: true
        )

        #expect(result.result.successCount == 1)
        assertJapaneseSettingsMetadataPreserved(in: result.file, value: "更新済み設定")
    }

    @Test("updateTranslationsBatch preserves existing localization metadata")
    func updateTranslationsBatchPreservesLocalizationMetadata() throws {
        let file = try loadFixture(Self.catalogWithTargetLocalizationMetadata)

        let result = XCStringsWriter.updateTranslationsBatch(
            in: file,
            entries: [
                BatchTranslationEntry(key: "settings.title", translations: ["ja": "更新済み設定"]),
            ]
        )

        #expect(result.result.successCount == 1)
        assertJapaneseSettingsMetadataPreserved(in: result.file, value: "更新済み設定")
    }

    @Test("updateTranslationsBatch validates sibling languages against incoming source value")
    func updateTranslationsBatchValidatesSiblingLanguagesAgainstIncomingSourceValue() throws {
        let file = try loadFixture(Self.catalogWithSiblingSourceUpdate)

        let result = XCStringsWriter.updateTranslationsBatch(
            in: file,
            entries: [
                BatchTranslationEntry(
                    key: "photo.title",
                    translations: [
                        "en": "Photo %@",
                        "es": "Foto",
                    ]
                ),
            ]
        )

        #expect(result.result.successCount == 0)
        #expect(result.result.failedCount == 1)
        #expect(result.file.strings["photo.title"]?.localizations?["en"]?.stringUnit?.value == "Photo")
        #expect(result.file.strings["photo.title"]?.localizations?["es"]?.stringUnit?.value == "Foto")
    }

    @Test("updateTranslations throws for non-existent key")
    func updateTranslationsKeyNotFound() throws {
        let file = try loadFixture(TestFixtures.singleKeyMultipleLangs)

        #expect(throws: XCStringsError.self) {
            _ = try XCStringsWriter.updateTranslations(in: file, key: "NonExistent", translations: ["en": "Value"])
        }
    }

    @Test("updateTranslations throws for non-existent language")
    func updateTranslationsLanguageNotFound() throws {
        let file = try loadFixture(TestFixtures.singleKeyMultipleLangs)

        #expect(throws: XCStringsError.self) {
            _ = try XCStringsWriter.updateTranslations(in: file, key: "Hello", translations: ["fr": "Bonjour"])
        }
    }

    @Test("updateTranslations rejects non-translatable keys")
    func updateTranslationsRejectNonTranslatableKey() throws {
        let file = try loadFixture(TestFixtures.withLocaleOnlyOnNonTranslatableKey)

        #expect(throws: XCStringsError.self) {
            _ = try XCStringsWriter.updateTranslations(in: file, key: "BrandName", translations: ["ja": "更新済み"])
        }
    }

    @Test("updateTranslation rejects non-positional placeholder reordering")
    func updateTranslationRejectsNonPositionalReordering() throws {
        var file = try loadFixture(TestFixtures.empty)
        file = try XCStringsWriter.addTranslation(to: file, key: "About %@ (%lld)", language: "en", value: "About %@ (%lld)")
        file = try XCStringsWriter.addTranslation(to: file, key: "About %@ (%lld)", language: "es", value: "Acerca de %@ (%lld)")

        #expect(throws: XCStringsError.self) {
            _ = try XCStringsWriter.updateTranslation(
                in: file,
                key: "About %@ (%lld)",
                language: "es",
                value: "%lld elementos para %@"
            )
        }
    }

    @Test("updateTranslation accepts positional reordering for implicit source placeholders")
    func updateTranslationAcceptsPositionalReorderingForImplicitSource() throws {
        var file = try loadFixture(TestFixtures.empty)
        file = try XCStringsWriter.addTranslation(to: file, key: "About %@ (%lld)", language: "en", value: "About %@ (%lld)")
        file = try XCStringsWriter.addTranslation(to: file, key: "About %@ (%lld)", language: "es", value: "Acerca de %@ (%lld)")

        file = try XCStringsWriter.updateTranslation(
            in: file,
            key: "About %@ (%lld)",
            language: "es",
            value: "%2$lld elementos para %1$@"
        )

        #expect(file.strings["About %@ (%lld)"]?.localizations?["es"]?.stringUnit?.value == "%2$lld elementos para %1$@")
    }

    // MARK: - renameKey

    @Test("renameKey renames key")
    func renameKey() throws {
        var file = try loadFixture(TestFixtures.singleKeySingleLang)

        file = try XCStringsWriter.renameKey(in: file, from: "Hello", to: "Greeting")

        #expect(file.strings["Hello"] == nil)
        #expect(file.strings["Greeting"] != nil)
        #expect(file.strings["Greeting"]?.localizations?["en"]?.stringUnit?.value == "Hello")
    }

    @Test("renameKey throws for non-existent key")
    func renameKeyNotFound() throws {
        let file = try loadFixture(TestFixtures.singleKeySingleLang)

        #expect(throws: XCStringsError.self) {
            _ = try XCStringsWriter.renameKey(in: file, from: "NonExistent", to: "NewName")
        }
    }

    @Test("renameKey throws when target key exists")
    func renameKeyTargetExists() throws {
        let file = try loadFixture(TestFixtures.multipleKeysPartialTranslations)

        #expect(throws: XCStringsError.self) {
            _ = try XCStringsWriter.renameKey(in: file, from: "Hello", to: "Goodbye")
        }
    }

    // MARK: - deleteKey

    @Test("deleteKey removes key")
    func deleteKey() throws {
        var file = try loadFixture(TestFixtures.singleKeySingleLang)

        file = try XCStringsWriter.deleteKey(from: file, key: "Hello")

        #expect(file.strings["Hello"] == nil)
    }

    @Test("deleteKey throws for non-existent key")
    func deleteKeyNotFound() throws {
        let file = try loadFixture(TestFixtures.singleKeySingleLang)

        #expect(throws: XCStringsError.self) {
            _ = try XCStringsWriter.deleteKey(from: file, key: "NonExistent")
        }
    }

    // MARK: - deleteTranslation

    @Test("deleteTranslation removes specific language")
    func deleteTranslation() throws {
        var file = try loadFixture(TestFixtures.singleKeyMultipleLangs)

        file = try XCStringsWriter.deleteTranslation(from: file, key: "Hello", language: "ja")

        #expect(file.strings["Hello"]?.localizations?["ja"] == nil)
        #expect(file.strings["Hello"]?.localizations?["en"] != nil)
    }

    @Test("deleteTranslation throws for non-existent key")
    func deleteTranslationKeyNotFound() throws {
        let file = try loadFixture(TestFixtures.singleKeyMultipleLangs)

        #expect(throws: XCStringsError.self) {
            _ = try XCStringsWriter.deleteTranslation(from: file, key: "NonExistent", language: "en")
        }
    }

    @Test("deleteTranslation throws for non-existent language")
    func deleteTranslationLanguageNotFound() throws {
        let file = try loadFixture(TestFixtures.singleKeySingleLang)

        #expect(throws: XCStringsError.self) {
            _ = try XCStringsWriter.deleteTranslation(from: file, key: "Hello", language: "fr")
        }
    }

    // MARK: - deleteTranslations

    @Test("deleteTranslations removes multiple languages")
    func deleteTranslationsMultiple() throws {
        var file = try loadFixture(TestFixtures.singleKeyMultipleLangs)

        file = try XCStringsWriter.deleteTranslations(from: file, key: "Hello", languages: ["ja", "de"])

        #expect(file.strings["Hello"]?.localizations?["ja"] == nil)
        #expect(file.strings["Hello"]?.localizations?["de"] == nil)
        #expect(file.strings["Hello"]?.localizations?["en"] != nil)
    }

    @Test("deleteTranslations throws for non-existent key")
    func deleteTranslationsKeyNotFound() throws {
        let file = try loadFixture(TestFixtures.singleKeyMultipleLangs)

        #expect(throws: XCStringsError.self) {
            _ = try XCStringsWriter.deleteTranslations(from: file, key: "NonExistent", languages: ["en"])
        }
    }

    @Test("deleteTranslations throws for non-existent language")
    func deleteTranslationsLanguageNotFound() throws {
        let file = try loadFixture(TestFixtures.singleKeyMultipleLangs)

        #expect(throws: XCStringsError.self) {
            _ = try XCStringsWriter.deleteTranslations(from: file, key: "Hello", languages: ["fr"])
        }
    }

    // MARK: - Helper

    private func loadFixture(_ content: String) throws -> XCStringsFile {
        let data = content.data(using: .utf8)!
        return try JSONDecoder().decode(XCStringsFile.self, from: data)
    }

    private func assertJapaneseSettingsMetadataPreserved(in file: XCStringsFile, value: String) {
        let localization = file.strings["settings.title"]?.localizations?["ja"]

        #expect(localization?.stringUnit?.value == value)
        #expect(localization?.stringUnit?.state == "needs_review")
        expectStringValue(localization?.unknownFields["localizationNote"], equals: "reviewed-by-l10n")
        expectStringValue(localization?.unknownFields["vendorStatus"], equals: "approved")
        expectStringValue(localization?.stringUnit?.unknownFields["reviewStatus"], equals: "approved")
    }

    private func expectStringValue(_ value: XCStringsRawJSONValue?, equals expected: String) {
        if case .string(let actual) = value {
            #expect(actual == expected)
            return
        }

        #expect(Bool(false))
    }

    private static let catalogWithTargetLocalizationMetadata = """
    {
      "sourceLanguage": "en",
      "strings": {
        "settings.title": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "Settings"
              }
            },
            "ja": {
              "stringUnit": {
                "state": "needs_review",
                "value": "古い設定",
                "reviewStatus": "approved"
              },
              "localizationNote": "reviewed-by-l10n",
              "vendorStatus": "approved"
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    private static let catalogWithSiblingSourceUpdate = """
    {
      "sourceLanguage": "en",
      "strings": {
        "photo.title": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "Photo"
              }
            },
            "es": {
              "stringUnit": {
                "state": "translated",
                "value": "Foto"
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """
}
