import Foundation

/// Handles file I/O operations for xcstrings files
struct XCStringsFileHandler: Sendable {
    private let path: String

    init(path: String) {
        self.path = path
    }

    /// Load xcstrings file from disk
    func load() throws -> XCStringsFile {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCStringsError.fileNotFound(path: path)
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw XCStringsError.invalidFileFormat(path: path, reason: error.localizedDescription)
        }

        do {
            let decoder = JSONDecoder()
            var file = try decoder.decode(XCStringsFile.self, from: data)
            let keyOrder = try XCStringsJSONKeyOrderScanner.scan(data)
            file.apply(keyOrder)
            return file
        } catch {
            throw XCStringsError.invalidFileFormat(path: path, reason: error.localizedDescription)
        }
    }

    /// Save xcstrings file to disk
    func save(_ file: XCStringsFile) throws {
        let url = URL(fileURLWithPath: path)
        let data = try encodedData(
            for: file,
            appendTrailingNewline: existingFileHasTrailingNewline(at: url) ?? true
        )

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw XCStringsError.writeError(path: path, reason: error.localizedDescription)
        }
    }

    /// Create a new xcstrings file
    func create(sourceLanguage: String, overwrite: Bool = false) throws {
        let url = URL(fileURLWithPath: path)

        if !overwrite && FileManager.default.fileExists(atPath: path) {
            throw XCStringsError.fileAlreadyExists(path: path)
        }

        let file = XCStringsFile(sourceLanguage: sourceLanguage)
        let data = try encodedData(for: file, appendTrailingNewline: true)

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw XCStringsError.writeError(path: path, reason: error.localizedDescription)
        }
    }

    private func encodedData(for file: XCStringsFile, appendTrailingNewline: Bool) throws -> Data {
        do {
            return try XCStringsJSONSerializer.data(for: file, appendTrailingNewline: appendTrailingNewline)
        } catch {
            throw XCStringsError.writeError(path: path, reason: error.localizedDescription)
        }
    }

    private func existingFileHasTrailingNewline(at url: URL) -> Bool? {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            return nil
        }

        return data.hasTrailingNewline
    }
}

private extension Data {
    var hasTrailingNewline: Bool {
        last == 0x0A
    }
}

private extension XCStringsFile {
    mutating func apply(_ keyOrder: XCStringsJSONKeyOrder) {
        strings.reorder(existingKeys: keyOrder.strings)

        strings.mutateValues { key, entry in
            if var localizations = entry.localizations {
                if let localizationOrder = keyOrder.localizationsByStringKey[key] {
                    localizations.reorder(existingKeys: localizationOrder)
                }

                localizations.mutateValues { language, localization in
                    let substitutionOrderKey = [key, language].joined(separator: "\u{1F}")
                    if let substitutionOrder = keyOrder.substitutionsByStringKeyAndLanguage[substitutionOrderKey] {
                        localization.substitutions?.reorder(existingKeys: substitutionOrder)
                    }
                }
                entry.localizations = localizations
            }
        }
    }
}
