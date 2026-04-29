# xcatalog

CLI and MCP server for xcstrings (String Catalog) CRUD operations.

## IMPORTANT: **We do not need backward compatibility because this is still in early development.**

## Build & Test

```bash
swift build           # Build all targets
swift test            # Run all tests
swift build -c release # Release build
```

## Architecture

- `Sources/XCStringsKit/` - Core library (models, parser, reader, writer, stats, validation, supplement workflow)
- `Sources/XCStringsCLI/` - CLI commands using ArgumentParser (includes `mcp` subcommand)
- `Sources/XCStringsMCP/` - MCP server using swift-sdk
- `Sources/xcatalog/` - CLI entry point (`xcatalog mcp` starts the MCP server)

## Code Style

- Swift 6.0 with strict concurrency
- Use `async/await` for async operations
- Errors defined in `Errors.swift`, use `XCStringsError` enum
- All public APIs should have clear parameter names

## Key Files

- `Sources/XCStringsKit/Models/XCStrings.swift` - Data and output models
- `Sources/XCStringsKit/XCStringsParser.swift` - Actor facade for file operations
- `Sources/XCStringsKit/XCStringsReader.swift` - Read operations (list, get, check)
- `Sources/XCStringsKit/XCStringsWriter.swift` - Write operations (add, update, delete, rename, batch)
- `Sources/XCStringsKit/XCStringsStatsCalculator.swift` - Coverage and progress stats
- `Sources/XCStringsKit/XCStringsCatalogValidator.swift` - Catalog, placeholder, rich-record, and suspicious-key validation
- `Sources/XCStringsKit/XCStringsPreflightClassifier.swift` - Target-locale write planning
- `Sources/XCStringsKit/LocaleSupplementWorkflow.swift` - Atomic one-locale supplement planning and execution
- `Sources/XCStringsKit/FormatStringSafety.swift` - Placeholder safety checks
- `Sources/XCStringsKit/XCStringsFileAccessCoordinator.swift` - Per-catalog write serialization
- `Sources/XCStringsMCP/MCPServer.swift` - MCP tool schema registration
- `Sources/XCStringsMCP/ToolHandlerRegistry.swift` - MCP tool-name to handler mapping

## Testing

```bash
swift test --filter XCStringsKitTests  # Run core library tests
swift test --filter XCStringsCLITests  # Run CLI parsing tests
swift test --filter XCStringsMCPTests  # Run MCP handler and integration tests
```

Tests use fixture-based approach. See `Tests/XCStringsKitTests/TestFixtures.swift` and `Tests/XCStringsMCPTests/TestSupport.swift` for test data generation.

## Behavior Notes

- `get key` returns `KeyInfo` metadata together with `translations`, not just translation values.
- `get key --lang <locale>` is lenient: if the key exists but that locale is missing, it still returns `KeyInfo` with an empty `translations` payload.
- `check key --lang <locale>` is strict: it returns `true` only when that locale has an actual localization record, even for keys with `shouldTranslate: false`.
- `list languages` returns the source language plus locales present anywhere in the catalog. Coverage/progress calculations use only languages in scope for translatable entries.
- Keys with `shouldTranslate: false` are excluded from untranslated lists and coverage/progress totals.
- Add, update, and supplement writes reject or classify as unsafe writes to keys with `shouldTranslate: false`.
- Coverage and progress outputs use `CoverageMeasurement` with `state` (`measured` or `notApplicable`) and optional `percent`. Measured percentages are serialized rounded to two decimal places, and incomplete coverage is never rounded up to `100.0`.
- Compact coverage summaries expose `completionState`, `incompleteLanguages`, and `notApplicableLanguages`.
- CLI compact output is opt-in with `--compact` for preflight, stats, supplement, and catalog validation commands. MCP stats coverage tools default to compact output; pass `compact: false` for full coverage payloads.
- `batch supplement` inserts missing target localizations by default. Existing target localizations become `unchanged` when values match or `skip` when values differ; pass `--overwrite` or MCP `overwrite: true` to update differing existing values.
- `batch supplement --dry-run --validate-compile` validates a projected temporary catalog without mutating the real file. Blocking atomic plans skip compile validation unless partial writes are allowed.
- Validation commands return structured reports for JSON/model shape, placeholders, rich substitution/variation preservation, suspicious keys, and optional `xcstringstool compile --dry-run`.
- MCP add, update, rename, delete, batch add, and batch update tools return structured write responses with operation type, file change status, action counts, entry snapshots, placeholder validations, and warnings.
- `XCATALOG_ALLOWED_ROOTS` is diagnostic health metadata only; read and write tools operate on the explicit file paths passed in each request.
