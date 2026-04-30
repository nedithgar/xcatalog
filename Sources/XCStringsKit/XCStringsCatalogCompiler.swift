import Foundation

enum XCStringsCatalogCompiler {
    static func validateCompile(file: XCStringsFile, language: String) -> LocaleSupplementCompileValidation {
        guard let toolPath = findXCStringsTool() else {
            return LocaleSupplementCompileValidation(
                status: .unavailable,
                command: ["xcrun", "xcstringstool"],
                diagnostics: "xcrun could not locate xcstringstool."
            )
        }

        let fileManager = FileManager.default
        let tempRoot = fileManager.temporaryDirectory
            .appendingPathComponent("xcatalog-\(UUID().uuidString)", isDirectory: true)
        let catalogURL = tempRoot.appendingPathComponent("Supplement.xcstrings")
        let outputURL = tempRoot.appendingPathComponent("out", isDirectory: true)

        do {
            try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)
            let data = try XCStringsJSONSerializer.data(for: file, appendTrailingNewline: true)
            try data.write(to: catalogURL, options: .atomic)
            defer { try? fileManager.removeItem(at: tempRoot) }

            let command = [
                toolPath,
                "compile",
                catalogURL.path,
                "--output-directory",
                outputURL.path,
                "--language",
                language,
                "--dry-run",
            ]
            let result = run(command)

            return LocaleSupplementCompileValidation(
                status: result.exitCode == 0 ? .passed : .failed,
                command: command,
                diagnostics: result.output.isEmpty ? nil : result.output
            )
        } catch {
            try? fileManager.removeItem(at: tempRoot)
            return LocaleSupplementCompileValidation(
                status: .failed,
                command: [toolPath, "compile", catalogURL.path],
                diagnostics: error.localizedDescription
            )
        }
    }

    static func validateCompile(path: String, languages: [String]) -> CatalogCompileValidation {
        guard let toolPath = findXCStringsTool() else {
            return CatalogCompileValidation(
                status: .unavailable,
                command: ["xcrun", "xcstringstool"],
                diagnostics: "xcrun could not locate xcstringstool."
            )
        }

        let fileManager = FileManager.default
        let outputURL = fileManager.temporaryDirectory
            .appendingPathComponent("xcatalog-validate-\(UUID().uuidString)", isDirectory: true)

        do {
            try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(at: outputURL) }

            var command = [
                toolPath,
                "compile",
                path,
                "--output-directory",
                outputURL.path,
            ]
            for language in languages.sorted() {
                command.append("--language")
                command.append(language)
            }
            command.append("--dry-run")

            let result = run(command)
            return CatalogCompileValidation(
                status: result.exitCode == 0 ? .passed : .failed,
                command: command,
                diagnostics: result.output.isEmpty ? nil : result.output
            )
        } catch {
            try? fileManager.removeItem(at: outputURL)
            return CatalogCompileValidation(
                status: .failed,
                command: [toolPath, "compile", path],
                diagnostics: error.localizedDescription
            )
        }
    }

    private static func findXCStringsTool() -> String? {
        let result = run(["/usr/bin/xcrun", "--find", "xcstringstool"])
        guard result.exitCode == 0 else {
            return nil
        }

        let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    static func run(_ command: [String]) -> ProcessResult {
        guard let executable = command.first else {
            return ProcessResult(exitCode: 1, output: "Missing executable.")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(command.dropFirst())

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        let output = ProcessOutputBuffer()
        let readHandle = pipe.fileHandleForReading
        readHandle.readabilityHandler = { handle in
            output.append(handle.availableData)
        }

        do {
            try process.run()
            process.waitUntilExit()
            readHandle.readabilityHandler = nil
            output.append(readHandle.availableData)
            return ProcessResult(exitCode: process.terminationStatus, output: output.stringValue)
        } catch {
            readHandle.readabilityHandler = nil
            return ProcessResult(exitCode: 1, output: error.localizedDescription)
        }
    }

    struct ProcessResult {
        let exitCode: Int32
        let output: String
    }
}

private final class ProcessOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    var stringValue: String {
        lock.lock()
        let snapshot = data
        lock.unlock()
        return String(data: snapshot, encoding: .utf8) ?? ""
    }

    func append(_ newData: Data) {
        guard !newData.isEmpty else {
            return
        }

        lock.lock()
        data.append(newData)
        lock.unlock()
    }
}
