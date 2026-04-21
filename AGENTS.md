# xcstrings-crud

CLI and MCP server for xcstrings (String Catalog) CRUD operations.

## Build & Test

```bash
swift build           # Build all targets
swift test            # Run all tests
swift build -c release # Release build
```

## Architecture

- `XCStringsKit/` - Core library (models, parser, reader, writer, stats)
- `XCStringsCLI/` - CLI commands using ArgumentParser (includes MCP subcommand)
- `XCStringsMCP/` - MCP server using swift-sdk
- `xcstrings-crud/` - CLI entry point (`xcstrings-crud mcp` for MCP server)

## Code Style

- Swift 6.0 with strict concurrency
- Use `async/await` for async operations
- Errors defined in `Errors.swift`, use `XCStringsError` enum
- All public APIs should have clear parameter names

## Key Files

- `XCStrings.swift` - Data models (`StringCatalog`, `StringUnit`, etc.)
- `XCStringsParser.swift` - Facade for file operations
- `XCStringsReader.swift` - Read operations (list, get, check)
- `XCStringsWriter.swift` - Write operations (add, update, delete, rename)
- `XCStringsStatsCalculator.swift` - Coverage and progress stats

## Testing

```bash
swift test --filter XCStringsKitTests  # Run core library tests
swift test --filter XCStringsMCPTests  # Run MCP handler and integration tests
```

Tests use fixture-based approach. See `TestFixtures.swift` and `Tests/XCStringsMCPTests/TestSupport.swift` for test data generation.

## Behavior Notes

- `get key` returns `KeyInfo` metadata together with `translations`, not just translation values.
- `get key --lang <locale>` is lenient: if the key exists but that locale is missing, it still returns `KeyInfo` with an empty `translations` payload.
- `check key --lang <locale>` is strict: it returns `true` only when that locale has an actual localization record, even for keys with `shouldTranslate: false`.
- Keys with `shouldTranslate: false` are excluded from untranslated lists and coverage/progress totals.
- Coverage and progress outputs use `CoverageMeasurement` with `state` (`measured` or `notApplicable`) and optional `percent`.
- Compact coverage summaries expose `completionState`, `incompleteLanguages`, and `notApplicableLanguages`.
