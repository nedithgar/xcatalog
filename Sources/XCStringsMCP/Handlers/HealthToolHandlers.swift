import Foundation
import XCStringsKit

// MARK: - Health Handler

struct HealthHandler: ToolHandler {
    static let toolName = "xcatalog_health"

    func execute(with context: ToolContext) async throws -> String {
        let includeSensitivePaths = context.arguments.bool("includeSensitivePaths", default: false)
        let health = HealthInfo.current(includeSensitivePaths: includeSensitivePaths)
        return try JSONEncoderHelper.encode(health)
    }
}

struct HealthInfo: Codable, Sendable {
    let version: String
    let serverName: String
    let toolSchemaVersion: String
    let binaryPath: String?
    let gitCommit: String?
    let buildConfiguration: String?
    let buildDate: String?
    let currentWorkingDirectory: String?
    let allowedRoots: [String]?

    static func current(
        includeSensitivePaths: Bool = false,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        currentDirectoryPath: String = FileManager.default.currentDirectoryPath,
        executablePath: String? = Bundle.main.executablePath ?? CommandLine.arguments.first
    ) -> HealthInfo {
        let resolvedExecutablePath = executablePath ?? "unknown"
        let shouldIncludeSensitivePaths = includeSensitivePaths && sensitiveHealthOutputEnabled(from: environment)

        return HealthInfo(
            version: XCStringsMCPMetadata.version,
            serverName: XCStringsMCPMetadata.serverName,
            toolSchemaVersion: XCStringsMCPMetadata.toolSchemaVersion,
            binaryPath: shouldIncludeSensitivePaths ? resolvedExecutablePath : nil,
            gitCommit: buildMetadataValue("XCATALOG_GIT_COMMIT", from: environment),
            buildConfiguration: environment["XCATALOG_BUILD_CONFIGURATION"] ?? buildConfiguration(from: resolvedExecutablePath),
            buildDate: environment["XCATALOG_BUILD_DATE"] ?? executableModificationDate(at: resolvedExecutablePath),
            currentWorkingDirectory: shouldIncludeSensitivePaths ? currentDirectoryPath : nil,
            allowedRoots: shouldIncludeSensitivePaths ? allowedRoots(from: environment) : nil
        )
    }

    private static func sensitiveHealthOutputEnabled(from environment: [String: String]) -> Bool {
        guard let value = environment["XCATALOG_HEALTH_INCLUDE_SENSITIVE"] else {
            return false
        }

        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on":
            return true
        default:
            return false
        }
    }

    private static func buildMetadataValue(_ key: String, from environment: [String: String]) -> String? {
        guard let value = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else {
            return nil
        }

        return value
    }

    private static func allowedRoots(from environment: [String: String]) -> [String] {
        guard let value = environment["XCATALOG_ALLOWED_ROOTS"] else {
            return []
        }

        return value
            .split(whereSeparator: { $0 == ":" || $0 == "," || $0 == "\n" })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func buildConfiguration(from executablePath: String) -> String? {
        if executablePath.contains("/.build/debug/") {
            return "debug"
        }

        if executablePath.contains("/.build/release/") {
            return "release"
        }

        return nil
    }

    private static func executableModificationDate(at path: String) -> String? {
        guard path != "unknown",
              let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let modificationDate = attributes[.modificationDate] as? Date
        else {
            return nil
        }

        return ISO8601DateFormatter().string(from: modificationDate)
    }
}
