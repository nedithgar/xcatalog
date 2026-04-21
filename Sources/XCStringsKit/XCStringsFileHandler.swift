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
            return try decoder.decode(XCStringsFile.self, from: data)
        } catch {
            throw XCStringsError.invalidFileFormat(path: path, reason: error.localizedDescription)
        }
    }

    /// Save xcstrings file to disk
    func save(_ file: XCStringsFile) throws {
        let url = URL(fileURLWithPath: path)
        let data = try encodedData(for: file)

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
        let data = try encodedData(for: file)

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw XCStringsError.writeError(path: path, reason: error.localizedDescription)
        }
    }

    private func encodedData(for file: XCStringsFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            return try encoder.encode(file)
        } catch {
            throw XCStringsError.writeError(path: path, reason: error.localizedDescription)
        }
    }
}
