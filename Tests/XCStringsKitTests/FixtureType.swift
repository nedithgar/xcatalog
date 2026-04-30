import Foundation
import Testing
@testable import XCStringsKit

// MARK: - Fixture Enum for Parameterized Tests

enum FixtureType: String, CaseIterable, CustomTestStringConvertible {
    case empty
    case singleKeySingleLang
    case singleKeyMultipleLangs
    case multipleKeysPartialTranslations
    case withComments
    case japaneseSource
    case manyKeys
    case specialCharacters
    case emptyLocalizations
    case manyLanguages
    case variousStates
    case pluralVariations
    case deviceVariations
    case withStaleKeys
    case withLocaleOnlyOnNonTranslatableKey
    case realWorldSample
    case catalogPersistenceRegression

    var testDescription: String { rawValue }

    var content: String {
        switch self {
        case .empty: TestFixtures.empty
        case .singleKeySingleLang: TestFixtures.singleKeySingleLang
        case .singleKeyMultipleLangs: TestFixtures.singleKeyMultipleLangs
        case .multipleKeysPartialTranslations: TestFixtures.multipleKeysPartialTranslations
        case .withComments: TestFixtures.withComments
        case .japaneseSource: TestFixtures.japaneseSource
        case .manyKeys: TestFixtures.manyKeys
        case .specialCharacters: TestFixtures.specialCharacters
        case .emptyLocalizations: TestFixtures.emptyLocalizations
        case .manyLanguages: TestFixtures.manyLanguages
        case .variousStates: TestFixtures.variousStates
        case .pluralVariations: TestFixtures.pluralVariations
        case .deviceVariations: TestFixtures.deviceVariations
        case .withStaleKeys: TestFixtures.withStaleKeys
        case .withLocaleOnlyOnNonTranslatableKey: TestFixtures.withLocaleOnlyOnNonTranslatableKey
        case .realWorldSample: TestFixtures.realWorldSample
        case .catalogPersistenceRegression: TestFixtures.catalogPersistenceRegression
        }
    }

    var expectedKeyCount: Int {
        switch self {
        case .empty: 0
        case .singleKeySingleLang: 1
        case .singleKeyMultipleLangs: 1
        case .multipleKeysPartialTranslations: 3
        case .withComments: 2
        case .japaneseSource: 1
        case .manyKeys: 10
        case .specialCharacters: 3
        case .emptyLocalizations: 2
        case .manyLanguages: 1
        case .variousStates: 3
        case .pluralVariations: 2
        case .deviceVariations: 1
        case .withStaleKeys: 4
        case .withLocaleOnlyOnNonTranslatableKey: 2
        case .realWorldSample: 4
        case .catalogPersistenceRegression: 6
        }
    }

    var expectedSourceLanguage: String {
        switch self {
        case .japaneseSource: "ja"
        default: "en"
        }
    }
}
