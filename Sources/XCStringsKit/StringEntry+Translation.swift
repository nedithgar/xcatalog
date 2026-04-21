import Foundation

/// Shared semantics for translation requirements and coverage of `StringEntry`.
///
/// Centralized so the listing logic in `XCStringsReader` and the coverage math in
/// `XCStringsStatsCalculator` cannot accidentally diverge over time.
enum StringEntryTranslationSemantics {
    static func requiresTranslation(_ entry: StringEntry) -> Bool {
        entry.shouldTranslate != false
    }

    static func countsAsTranslated(_ entry: StringEntry, for language: String) -> Bool {
        guard requiresTranslation(entry) else {
            return true
        }

        let localization = entry.localizations?[language]
        return localization?.stringUnit?.value != nil || localization?.variations != nil
    }
}

extension StringEntry {
    var requiresTranslation: Bool {
        StringEntryTranslationSemantics.requiresTranslation(self)
    }

    func countsAsTranslated(for language: String) -> Bool {
        StringEntryTranslationSemantics.countsAsTranslated(self, for: language)
    }
}
