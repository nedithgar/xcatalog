# xcatalog

CLI tool and MCP server for CRUD operations on xcstrings (String Catalog) files.

## Motivation

Large xcstrings files can contain thousands of localization keys across multiple languages, resulting in massive JSON files. When AI assistants or other tools read these files directly, they consume a significant amount of tokens, potentially exceeding context limits or rapidly depleting token budgets.

This tool provides a **token-efficient** approach by offering targeted CRUD operations:

- **Query only what you need**: Fetch specific keys or languages instead of returning the entire catalog JSON
- **Incremental updates**: Add or update individual translations without sending the full file through an assistant context
- **Quick stats**: Get coverage and progress summaries without returning every entry

By using the MCP server or CLI, AI assistants can work with xcstrings files of any size while keeping token usage minimal.

## Installation

### Using Mise

```bash
mise use -g ubi:nedithgar/xcatalog
```

### Using nest ([mtj0928/nest](https://github.com/mtj0928/nest))
```bash
nest install nedithgar/xcatalog
```

### Build from source

```bash
git clone https://github.com/nedithgar/xcatalog.git
cd xcatalog
swift build -c release
```

Binary will be at `.build/release/xcatalog`.

## MCP Server

The MCP server is available as a subcommand:

```bash
xcatalog mcp
```

### Configuration

Add to your Claude Code MCP settings:

```json
{
  "mcpServers": {
    "xcatalog": {
      "command": "xcatalog",
      "args": ["mcp"]
    }
  }
}
```

### Available Tools

| Tool | Description |
|------|-------------|
| `xcatalog_health` | Report running version and schema metadata, with local path diagnostics gated behind explicit opt-in |
| `xcatalog_create_file` | Create a new xcstrings file |
| `xcatalog_list_keys` | List all keys |
| `xcatalog_list_languages` | List languages present in the file |
| `xcatalog_list_untranslated` | List untranslated keys |
| `xcatalog_list_stale` | List keys with stale extraction state |
| `xcatalog_preflight_locale` | Classify target-locale work before writing translations |
| `xcatalog_validate_catalog` | Validate catalog parseability, placeholders, rich records, suspicious keys, and optional compile dry-run |
| `xcatalog_validate_placeholders` | Validate placeholder consistency across translated locales |
| `xcatalog_find_suspicious_keys` | Find empty, punctuation-only, or format-only accidental keys |
| `xcatalog_batch_list_stale` | List stale keys across multiple files |
| `xcatalog_get_source_language` | Get source language |
| `xcatalog_get_key` | Get metadata and translations for a key |
| `xcatalog_check_key` | Check if key exists |
| `xcatalog_check_coverage` | Check key language coverage with explicit measured or not-applicable state |
| `xcatalog_stats_coverage` | Get overall coverage statistics, including compact tri-state summaries |
| `xcatalog_stats_progress` | Get translation progress by language |
| `xcatalog_batch_stats_coverage` | Get coverage for multiple files at once, including compact tri-state summaries |
| `xcatalog_batch_check_keys` | Check if multiple keys exist |
| `xcatalog_batch_add_translations` | Add translations for multiple keys at once |
| `xcatalog_batch_update_translations` | Update translations for multiple keys at once |
| `xcatalog_supplement_locale` | Atomically supplement one locale from a key-to-value translation map |
| `xcatalog_add_translation` | Add translation for single language |
| `xcatalog_add_translations` | Add translations for multiple languages |
| `xcatalog_update_translation` | Update translation for single language |
| `xcatalog_update_translations` | Update translations for multiple languages |
| `xcatalog_rename_key` | Rename key |
| `xcatalog_delete_key` | Delete entire key |
| `xcatalog_delete_translation` | Delete translation for single language |
| `xcatalog_delete_translations` | Delete translations for multiple languages |

### Local Development

For feedback-loop development against a local checkout, point your MCP client at the development launcher instead of a release binary:

```json
{
  "mcpServers": {
    "xcatalog-dev": {
      "command": "/absolute/path/to/xcatalog/scripts/dev-mcp.sh",
      "env": {
        "XCATALOG_ALLOWED_ROOTS": "/path/to/YourApp",
        "XCATALOG_HEALTH_INCLUDE_SENSITIVE": "true"
      }
    }
  }
}
```

The launcher rebuilds the debug product, exports build metadata, and then starts:

```bash
/absolute/path/to/xcatalog/.build/debug/xcatalog mcp
```

Use `xcatalog_health` at the start of a local development session to verify which server process is running. By default, the response omits local filesystem paths and returns public metadata such as version, server name, tool schema version, build configuration, build date, and git commit only when `XCATALOG_GIT_COMMIT` is provided by the launcher. To include `binaryPath`, `currentWorkingDirectory`, and parsed `XCATALOG_ALLOWED_ROOTS`, set `XCATALOG_HEALTH_INCLUDE_SENSITIVE=true` on the server and call `xcatalog_health` with `includeSensitivePaths: true`. `XCATALOG_ALLOWED_ROOTS` is diagnostic health metadata only; read and write tools operate on the explicit file paths passed in each request.

MCP hosts generally do not hot-reload tool configuration or tool schemas. If you change MCP server registration, tool names, argument schemas, or the configured command path, restart or reload the MCP host. If you only change implementation behind the same command path, rebuild and restart the MCP server process through the host.

### Sample App Integration Recipe

Use a real app repository as an integration target without mixing tool changes and product localization changes:

1. Keep tool changes on a branch in your local `xcatalog` checkout.
2. Configure the MCP client to use `scripts/dev-mcp.sh` and optionally set `XCATALOG_ALLOWED_ROOTS` to the app repository you are testing against so `xcatalog_health` can report it.
3. Start a session by calling `xcatalog_health`.
4. Run read-only checks against app catalogs before writing:

```text
/path/to/YourApp/SharedLocalization/Localizable.xcstrings
/path/to/YourApp/AppTarget/AppTarget.xcstrings
/path/to/YourApp/PlatformShell/PlatformShell.xcstrings
```

5. Write to one locale and one catalog slice at a time while `xcatalog` is still under active development.
6. Convert every app failure or noisy diff into a sanitized fixture or test in this repository.
7. Land `xcatalog` fixes separately from app localization changes.

## CLI Usage

### Create Operations

```bash
# Create a new xcstrings file
xcatalog create path/to/Localizable.xcstrings

# Create with specific source language
xcatalog create path/to/Localizable.xcstrings --source-language ja

# Overwrite existing file
xcatalog create path/to/Localizable.xcstrings --overwrite
```

### Read Operations

```bash
# List all keys
xcatalog list keys --file path/to/Localizable.xcstrings

# List languages
xcatalog list languages --file path/to/Localizable.xcstrings

# List untranslated keys for a language
xcatalog list untranslated --file path/to/Localizable.xcstrings --lang ja

# List stale keys (potentially unused)
xcatalog list stale --file path/to/Localizable.xcstrings

# Classify locale work before writing
xcatalog list preflight --file path/to/Localizable.xcstrings --lang ja

# Compact preflight summary for agent planning
xcatalog list preflight --file path/to/Localizable.xcstrings --lang ja --compact

# List stale keys across multiple files
xcatalog batch stale -f file1.xcstrings file2.xcstrings file3.xcstrings

# Get source language
xcatalog get source-language --file path/to/Localizable.xcstrings

# Get metadata and translations for a key
xcatalog get key "Hello" --file path/to/Localizable.xcstrings
xcatalog get key "Hello" --file path/to/Localizable.xcstrings --lang ja

# Check if key exists
xcatalog check key "Hello" --file path/to/Localizable.xcstrings

# Check key coverage
xcatalog check coverage "Hello" --file path/to/Localizable.xcstrings

# Get overall statistics
xcatalog stats coverage --file path/to/Localizable.xcstrings

# Get compact overall statistics
xcatalog stats coverage --file path/to/Localizable.xcstrings --compact

# Get progress for a language
xcatalog stats progress --file path/to/Localizable.xcstrings --lang ja

# Get batch coverage for multiple files
xcatalog stats batch-coverage -f file1.xcstrings file2.xcstrings file3.xcstrings

# Get compact batch coverage for multiple files
xcatalog stats batch-coverage -f file1.xcstrings file2.xcstrings file3.xcstrings --compact
```

### Validation Operations

```bash
# Validate parseability, model decoding, placeholders, rich records, and suspicious keys
xcatalog validate catalog --file path/to/Localizable.xcstrings

# Also run xcstringstool compile --dry-run; omit --language to compile all catalog languages
xcatalog validate catalog --file path/to/Localizable.xcstrings --validate-compile
xcatalog validate catalog --file path/to/Localizable.xcstrings --validate-compile --language ja --language es

# Compact validation summary with counts and short issue list
xcatalog validate catalog --file path/to/Localizable.xcstrings --validate-compile --compact

# Validate placeholder consistency across every translated locale
xcatalog validate placeholders --file path/to/Localizable.xcstrings

# Find accidental SwiftUI-generated keys such as "", "/", or "(%@)"
xcatalog validate suspicious-keys --file path/to/Localizable.xcstrings
```

### Update Operations

```bash
# Add translation (single language)
xcatalog add key "Hello" --file path/to/Localizable.xcstrings --lang ja --value "こんにちは"

# Add translation (multiple languages)
xcatalog add key "Hello" --file path/to/Localizable.xcstrings -t ja:こんにちは en:Hello

# Update translation (single language)
xcatalog update key "Hello" --file path/to/Localizable.xcstrings --lang ja --value "こんにちは！"

# Update translations (multiple languages)
xcatalog update key "Hello" --file path/to/Localizable.xcstrings -t ja:こんにちは en:Hello de:Hallo

# Rename key
xcatalog rename key "Hello" --file path/to/Localizable.xcstrings --to "Greeting"
```

### Delete Operations

```bash
# Delete entire key
xcatalog delete key "Hello" --file path/to/Localizable.xcstrings

# Delete translation for specific language only
xcatalog delete key "Hello" --file path/to/Localizable.xcstrings -l ja

# Delete translations for multiple languages
xcatalog delete key "Hello" --file path/to/Localizable.xcstrings -l ja en fr
```

### Batch Operations

```bash
# List stale keys across multiple files
xcatalog batch stale -f file1.xcstrings file2.xcstrings file3.xcstrings

# Check if multiple keys exist
xcatalog batch check --file path/to/Localizable.xcstrings -k Hello Goodbye Welcome

# Check with specific language
xcatalog batch check --file path/to/Localizable.xcstrings -k Hello Goodbye -l ja

# Add translations for multiple keys at once
xcatalog batch add --file path/to/Localizable.xcstrings \
  -e "Hello=ja:こんにちは,en:Hello" \
  -e "Goodbye=ja:さようなら,en:Goodbye"

# Add with overwrite (replace existing translations)
xcatalog batch add --file path/to/Localizable.xcstrings --overwrite \
  -e "Hello=ja:こんにちは,en:Hello"

# Update translations for multiple keys at once
xcatalog batch update --file path/to/Localizable.xcstrings \
  -e "Hello=ja:こんにちは！,en:Hello!" \
  -e "Goodbye=ja:さようなら！"

# Plan a one-locale supplement without writing
xcatalog batch supplement --file path/to/Localizable.xcstrings --lang ja --dry-run \
  -e "Hello=こんにちは" \
  -e "Goodbye=さようなら"

# Compact supplement result for agent workflows
xcatalog batch supplement --file path/to/Localizable.xcstrings --lang ja --dry-run --compact \
  -e "Hello=こんにちは" \
  -e "Goodbye=さようなら"

# Dry-run the exact projected catalog and compile it without mutating the real file
xcatalog batch supplement --file path/to/Localizable.xcstrings --lang ja --dry-run --validate-compile --compact \
  -e "Hello=こんにちは" \
  -e "PhotoLabel=写真、%1$@、%2$lld x %3$lld ピクセル"

# Atomically supplement one locale; refuses the whole write if any entry is unsafe
xcatalog batch supplement --file path/to/Localizable.xcstrings --lang ja \
  -e "Hello=こんにちは" \
  -e "Goodbye=さようなら"

# Explicitly allow partial writes and compile a temporary catalog before saving
xcatalog batch supplement --file path/to/Localizable.xcstrings --lang ja --allow-partial --validate-compile \
  -e "Hello=こんにちは" \
  -e "Goodbye=さようなら"

# Update existing target localizations during supplement
xcatalog batch supplement --file path/to/Localizable.xcstrings --lang ja --overwrite \
  -e "Hello=こんにちは" \
  -e "Goodbye=さようなら"
```

### Common Options

- `--file <path>`: xcstrings file path for single-file operations. Batch file-list commands use `-f, --files`.
- `--pretty`: Pretty-printed JSON output where supported.
- `--compact`: Summary JSON where supported. CLI compact mode is available for `list preflight`, `stats coverage`, `stats batch-coverage`, `batch supplement`, and `validate catalog`.

## Output Notes

- `get key` and `xcatalog_get_key` return `KeyInfo` metadata together with translations. The JSON includes `comment`, `isCommentAutoGenerated`, `shouldTranslate`, `extractionState`, `languages`, and `translations`.
- Passing `--lang` or `language` filters the `translations` payload to that locale while keeping the key metadata in the response. If the key exists but that locale is missing, the command still returns `KeyInfo` with an empty `translations` payload.
- `check key` and `xcatalog_check_key` become locale-strict when a language is provided: they return `true` only when that locale has an actual localization record, even for keys marked `shouldTranslate: false`.
- `list languages` and `xcatalog_list_languages` return the source language plus locales present anywhere in the catalog. Coverage and progress calculations use only languages in scope for translatable entries.
- Coverage and progress commands now return a `coverage` object with `state` (`measured` or `notApplicable`) and `percent` instead of a top-level `coveragePercent` field. Measured percentages are serialized rounded to two decimal places, and incomplete coverage is never rounded up to `100.0`.
- Keys marked with `shouldTranslate: false` are excluded from untranslated lists and coverage totals. If a key, language, or file has no translatable content, coverage is reported as `notApplicable`.
- Add, update, and supplement writes reject or classify as unsafe any localization write to keys marked `shouldTranslate: false` so coverage and write behavior stay consistent.
- Compact coverage outputs use `completionState` and may include `incompleteLanguages` and `notApplicableLanguages`.
- CLI compact preflight, supplement, stats, and catalog validation outputs keep the full report available by default, but return decision-oriented summaries when `--compact` is set. MCP `xcatalog_preflight_locale`, `xcatalog_supplement_locale`, and `xcatalog_validate_catalog` also default to full output unless `compact: true` is passed. MCP `xcatalog_stats_coverage` and `xcatalog_batch_stats_coverage` default to compact output; pass `compact: false` for full coverage payloads.
- `batch supplement` inserts missing target localizations by default. Existing target localizations are reported as `unchanged` when the value already matches or `skip` when the value differs; pass `--overwrite` or MCP `overwrite: true` to update differing existing target values.
- `batch supplement --dry-run --validate-compile` applies the accepted plan to an in-memory projected catalog and runs `xcstringstool compile --dry-run` against a temporary copy without mutating the real file. If the atomic plan has blocking diagnostics and `--allow-partial` is not set, compile validation is skipped with `notRunDueToBlockingDiagnostics`. Results include `wouldWrite` and `compileValidationRanOnProjectedCatalog` so MCP clients can distinguish a plan-only dry run from a projected compile dry run.
- Validation commands return structured reports. `validate catalog` checks JSON parseability, model decoding, placeholder consistency, rich substitution/variation preservation after an encode/decode round trip, suspicious key hygiene, and optional `xcstringstool compile --dry-run`.
- Suspicious key detection flags empty keys, punctuation-only keys, and format-only keys such as `""`, `/`, and `(%@)` so callers can fix the SwiftUI call sites before committing catalog changes.
- MCP add, update, rename, delete, batch add, and batch update tools return structured JSON instead of plain success text. Responses include `file`, `operationType`, `key`, `languages`, `fileChanged`, action counts such as `insertedCount` and `updatedCount`, per-entry `previousState` and `finalState` where applicable, `placeholderValidations`, and `validationWarnings`.
- Write operations are serialized per canonical catalog path across parser instances, so parallel MCP calls cannot race through independent load-modify-save cycles for the same `.xcstrings` file. Prefer batch writes or `batch supplement` for multi-key work anyway: one planned write produces clearer diagnostics, fewer file rewrites, and less response noise than many parallel single-key calls.

Example MCP write response:

```json
{
  "success": true,
  "file": "path/to/Localizable.xcstrings",
  "operationType": "updateTranslation",
  "key": "Hello",
  "languages": ["ja"],
  "fileChanged": true,
  "insertedCount": 0,
  "updatedCount": 1,
  "deletedCount": 0,
  "renamedCount": 0,
  "failedCount": 0,
  "entries": [
    {
      "key": "Hello",
      "language": "ja",
      "action": "updated",
      "previousState": {
        "key": "Hello",
        "language": "ja",
        "value": "こんにちは",
        "state": "translated",
        "hasVariations": false,
        "hasSubstitutions": false
      },
      "finalState": {
        "key": "Hello",
        "language": "ja",
        "value": "やあ",
        "state": "translated",
        "hasVariations": false,
        "hasSubstitutions": false
      },
      "diagnostics": []
    }
  ],
  "placeholderValidations": [],
  "validationWarnings": []
}
```

## Requirements

- macOS 13+
- Swift 6.0+

## Acknowledgements

xcatalog is derived from
[Ryu0118/xcstrings-crud](https://github.com/Ryu0118/xcstrings-crud).
See [NOTICE.md](NOTICE.md) for attribution and license notices.

## License

xcatalog is distributed under the MIT License. See [LICENSE](LICENSE) for the
full license text and [NOTICE.md](NOTICE.md) for upstream attribution.
