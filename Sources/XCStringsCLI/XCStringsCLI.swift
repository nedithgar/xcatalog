import ArgumentParser
import XCStringsKit

@available(macOS 13.0, *)
public struct XCStringsCLI: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "xcatalog",
        abstract: "A CLI tool for CRUD operations on xcstrings files",
        version: XCatalogMetadata.version,
        subcommands: [
            CreateCommand.self,
            ListCommand.self,
            GetCommand.self,
            CheckCommand.self,
            AddCommand.self,
            UpdateCommand.self,
            DeleteCommand.self,
            RenameCommand.self,
            ValidateCommand.self,
            StatsCommand.self,
            BatchCommand.self,
            MCPCommand.self,
        ]
    )

    public init() {}
}
