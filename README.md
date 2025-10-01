# simplecov-mcp

MCP server + CLI + includable library for inspecting SimpleCov coverage data.

This gem provides:

- An MCP (Model Context Protocol) server exposing tools to query coverage for files.
- A flexible CLI with subcommands to list all files, show a file summary, print raw coverage arrays, list uncovered lines, and display detailed per-line hits. Supports JSON output, displaying annotated source code (full file or uncovered lines with context), and custom resultset locations.
- An includable Ruby library for programmatic access to coverage data via the `SimpleCovMcp::CoverageModel` API.

## Features

- MCP server tools for coverage queries: raw, summary, uncovered, detailed, all-files list, and version.
 - Per-file staleness flag in list outputs to highlight files newer than coverage or with line-count mismatches (shown as a compact '!' column in the CLI).
- CLI subcommands: `list`, `summary`, `raw`, `uncovered`, `detailed`, `version` (default `list`).
- JSON output with `--json` for machine use; human-readable tables/rows by default.
- Annotated source snippets with `--source[=full|uncovered]` and `--source-context N`; optional colors with `--color/--no-color`.
- Flexible resultset location: `--resultset PATH` or `SIMPLECOV_RESULTSET`; accepts file or directory; sensible default search order.
- Works installed as a gem, via Bundler (`bundle exec`), or directly from this repo’s `exe/` (symlink-safe).

## SimpleCov Independence

This codebase does not require, and is not connected to, the `simplecov` library at runtime. Its only interaction is reading the JSON resultset file that SimpleCov generates (`.resultset.json`). As long as that file exists in your project (in a default or specified location), the CLI and MCP server can operate without `require "simplecov"` in your app or test process.

## Installation

Add to your Gemfile or install directly:

```sh
gem install simplecov-mcp
```

Require path is `simple_cov_mcp` (also `simplecov_mcp`). Legacy `simple_cov/mcp` is supported via shim. Executable is `simplecov-mcp`.

## Usage

### Library Usage (Ruby)

Use this gem programmatically to inspect coverage without running the CLI or MCP server. The primary entry point is `SimpleCovMcp::CoverageModel`.

Basics:

```ruby
require "simple_cov_mcp"

# Defaults (omit args; shown here with comments):
# - root: "."
# - resultset: resolved from SIMPLECOV_RESULTSET or common paths under root
# - staleness: "off" (no stale checks)
# - tracked_globs: nil (no project-level file-set checks)
model = SimpleCovMcp::CoverageModel.new

# Custom configuration (non-default values):
model = SimpleCovMcp::CoverageModel.new(
  root: "/path/to/project",        # non-default project root
  resultset: "build/coverage",      # file or directory containing .resultset.json
  staleness: "error",               # enable stale checks (raise on stale)
  tracked_globs: ["lib/**/*.rb"]    # for 'all_files' staleness: flag new/missing files
)

# List all files with coverage summary, sorted ascending by % (default)
files = model.all_files
# => [ { 'file' => '/abs/path/lib/foo.rb', 'covered' => 12, 'total' => 14, 'percentage' => 85.71, 'stale' => false }, ... ]

# Per-file summaries
summary = model.summary_for("lib/foo.rb")
# => { 'file' => '/abs/.../lib/foo.rb', 'summary' => {'covered'=>12, 'total'=>14, 'pct'=>85.71} }

raw = model.raw_for("lib/foo.rb")
# => { 'file' => '/abs/.../lib/foo.rb', 'lines' => [nil, 1, 0, 3, ...] }

uncovered = model.uncovered_for("lib/foo.rb")
# => { 'file' => '/abs/.../lib/foo.rb', 'uncovered' => [5, 9, 12], 'summary' => { ... } }

detailed = model.detailed_for("lib/foo.rb")
# => { 'file' => '/abs/.../lib/foo.rb', 'lines' => [{'line' => 1, 'hits' => 1, 'covered' => true}, ...], 'summary' => { ... } }

# Generate formatted table string (same as CLI output)
table = model.format_table
# => returns formatted table string with borders, headers, and summary counts

# Custom table with specific rows and sort order
custom_rows = [
  { 'file' => '/abs/.../lib/foo.rb', 'covered' => 12, 'total' => 14, 'percentage' => 85.71, 'stale' => false },
  { 'file' => '/abs/.../lib/bar.rb', 'covered' => 8, 'total' => 10, 'percentage' => 80.0, 'stale' => true }
]
custom_table = model.format_table(custom_rows, sort_order: :descending)
# => formatted table with the provided rows in descending order

# Filter files by directory (e.g., only show files in lib/)
all_files_data = model.all_files
lib_files = all_files_data.select { |file| file['file'].include?('/lib/') }
lib_files_table = model.format_table(lib_files, sort_order: :ascending)
# => formatted table showing only files from lib/ directory

# Filter by pattern (e.g., only show test files)
test_files = all_files_data.select { |file| file['file'].include?('_spec.rb') || file['file'].include?('_test.rb') }
test_files_table = model.format_table(test_files, sort_order: :descending)
# => formatted table showing only test/spec files, sorted by coverage

# For more advanced filtering examples including staleness analysis and CI/CD integration,
# see examples/filter_and_table_demo.rb and examples/filter_and_table_demo-output.md
```

**Complete Example Script**: 
See [examples/filter_and_table_demo.rb](examples/filter_and_table_demo.rb) for a comprehensive 
demonstration of library usage including directory filtering, pattern matching, coverage thresholds,
and staleness analysis. Run it with `ruby examples/filter_and_table_demo.rb`.

### MCP Server Integration

#### Prerequisites
- Ruby 3.2+ with `simplecov-mcp` gem installed
- SimpleCov coverage data (run tests to generate `coverage/.resultset.json`)
- MCP-compatible client (editor, agent, or tool) (needed only for MCP mode, not for CLI or library modes)

#### Claude Code Compatibility Note
**Current Status**: Claude Code has a bug in its MCP client implementation that prevents it from working with spec-compliant MCP servers like simplecov-mcp. Claude Code will automatically fall back to using the CLI interface instead.

**Technical Details**: Claude Code incorrectly requires `uri` fields for all resource content and rejects the `text` field that is central to `TextResourceContents` per the official MCP specification. This affects all MCP servers that return text-based resource content.

**Bug Report**: [Claude Code Issue #8239](https://github.com/anthropics/claude-code/issues/8239)

**Workaround**: Claude Code users can still access all functionality through the CLI interface, which works perfectly. The CLI provides the same coverage analysis capabilities with human-readable tables and JSON output options.

#### Quick Test (Manual)
Test the MCP server manually by piping JSON-RPC messages:

**Important**: JSON-RPC messages must be on a single line (no line breaks). Multi-line JSON will cause parse errors.

```sh
# Basic file summary
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"coverage_summary_tool","arguments":{"path":"lib/simple_cov_mcp/model.rb"}}}' | simplecov-mcp

# All files with custom resultset location
echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"all_files_coverage_tool","arguments":{"resultset":"coverage","sort_order":"ascending"}}}' | simplecov-mcp

# Discover available tools
echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"help_tool","arguments":{}}}' | simplecov-mcp
```


#### Available MCP Tools

All tools accept these common parameters:
- `root` (optional): Project root directory (default: current directory)
- `resultset` (optional): Path to `.resultset.json` file or directory containing it
- `stale` (optional): Staleness checking mode - `"off"` (default) or `"error"`

**File-specific tools** (require `path` parameter):
- `coverage_summary_tool` - Get coverage summary for a file
- `coverage_detailed_tool` - Get per-line coverage details
- `coverage_raw_tool` - Get raw SimpleCov lines array
- `uncovered_lines_tool` - Get list of uncovered line numbers

**Project-wide tools**:
- `all_files_coverage_tool` - Get coverage data for all files
  - Additional parameters: `sort_order` (`"ascending"`|`"descending"`), `tracked_globs` (array)
- `coverage_table_tool` - Get formatted coverage table
- `help_tool` - Get information about available tools
  - Optional parameter: `query` (string to filter help entries)
- `version_tool` - Get version information

Response content types (MCP):
Library Usage (Ruby)
- JSON data returns as a single `type: "resource"` item with `resource.mimeType: "application/json"` and the JSON string in `resource.text` (e.g., `name: "coverage_summary.json"`).
- Human-readable strings (e.g., the table and version) return as `type: "text"`.
- Errors return as `type: "text"` with a friendly message.

Resultset resolution:

- If `resultset:` is provided, it may be:
  - a file path to `.resultset.json`, or
  - a directory containing `.resultset.json` (e.g., `coverage/`).
- If `resultset:` is omitted, resolution follows:
  1) `ENV["SIMPLECOV_RESULTSET"]` (file or directory), then
  2) `.resultset.json`, 3) `coverage/.resultset.json`, 4) `tmp/.resultset.json` under `root`.

Path semantics:

- Methods accept paths relative to `root` or absolute paths. Internally, the model resolves to an absolute path and looks up coverage by:
  1) exact absolute path,
  2) the path without the current working directory prefix,
  3) filename (basename) match as a last resort.

Sorting:

```ruby
model.all_files(sort_order: :descending) # or :ascending (default)
```

## Example Prompts

Using simplecov-mcp, show me a table of all files and their coverages.

----

Using simplecov-mcp, find the uncovered code lines and report to me, in a markdown file:

* the most important coverage omissions to address
* the simplest coverage omissions to address
* analyze the risk of the current state of coverage
* propose a plan of action (if any) to improve coverage state

See the [examples/prompts](examples/prompts) directory for more.

----


## Environment Variables

This application supports one environment variable for configuration:

### `SIMPLECOV_MCP_OPTS`
**Purpose**: Specifies command-line options to be applied automatically
**Format**: Shell-style string containing any valid CLI options
**Default**: None (empty)
**Examples**:
```bash
# Set default resultset location and enable JSON output
SIMPLECOV_MCP_OPTS="--resultset coverage/.resultset.json --json"

# Configure error handling and log file
SIMPLECOV_MCP_OPTS="--error-mode on_with_trace --log-file /var/log/simplecov.log"

# Force CLI mode for scripts (useful when auto-detection fails)
SIMPLECOV_MCP_OPTS="--force-cli"

# Use quoted strings for paths with spaces
SIMPLECOV_MCP_OPTS='--resultset "/path with spaces/coverage"'
```

**Precedence**: Command-line arguments override environment options
```bash
# This will use on_with_trace (from command line), not off (from environment)
SIMPLECOV_MCP_OPTS="--error-mode off" simplecov-mcp --error-mode on_with_trace summary lib/file.rb
```

**Supported Options**: Any CLI option works in `SIMPLECOV_MCP_OPTS`:
- `-r`, `--resultset PATH` - Specify coverage data location
- `--error-mode MODE` - Set error handling mode (off|on|on_with_trace)
- `-l`, `--log-file PATH` - Set log file location (use `-` to disable)
- `--json` - Enable JSON output
- `--force-cli` - Force CLI mode even when piped
- `--color` / `--no-color` - Control colored output
- `-s`, `--source[=MODE]` - Include source output (MODE: `full` or `uncovered`)
- `-S`, `--stale MODE` - Set staleness checking mode
- `-g`, `--tracked-globs x,y,z` - Globs for files that should be covered (list staleness only)
- `-R`, `--root PATH` - Project root (default `.`)
- And all other CLI options

**Error Handling**: Malformed options in `SIMPLECOV_MCP_OPTS` will cause the application to exit with a configuration error message.

## Error Handling

This tool provides different error handling behavior depending on how it's used:

### CLI Mode
When used as a command-line tool, errors are displayed as user-friendly messages without stack traces:

```bash
$ simplecov-mcp summary nonexistent.rb
File error: No coverage data found for the specified file
```

For debugging, set the `SIMPLECOV_MCP_DEBUG=1` environment variable to see full stack traces.

### Library Mode
When used as a Ruby library, errors are raised as custom exception classes that can be caught and handled:

```ruby
begin
  SimpleCovMcp.run_as_library(['summary', 'missing.rb'])
rescue SimpleCovMcp::FileError => e
  puts "Handled gracefully: #{e.user_friendly_message}"
end
```

Available exception classes:
- `SimpleCovMcp::Error` - Base error class
- `SimpleCovMcp::FileError` - File not found or access issues
- `SimpleCovMcp::CoverageDataError` - Invalid or missing coverage data
- `SimpleCovMcp::ConfigurationError` - Configuration problems
- `SimpleCovMcp::UsageError` - Command usage errors

### MCP Server Mode
When running as an MCP server, errors are handled internally and returned as structured responses to the MCP client. The MCP server uses:

- **Logging enabled** - Errors are logged to `~/simplecov_mcp.log` for server debugging
- **Clean error messages** - User-friendly messages are returned to the client (no stack traces unless `SIMPLECOV_MCP_DEBUG=1`)
- **Structured responses** - Errors are returned as proper MCP tool responses, not exceptions

The MCP server automatically configures error handling appropriately for server usage.

### Custom Error Handlers
Library usage defaults to no logging to avoid side effects, but you can customize this:

```ruby
# Default library behavior - no logging
SimpleCovMcp.run_as_library(['summary', 'file.rb'])

# Custom error handler with logging enabled
handler = SimpleCovMcp::ErrorHandler.new(
  log_errors: true,         # Enable logging for library usage
  show_stack_traces: false  # Clean error messages
)
SimpleCovMcp.run_as_library(argv, error_handler: handler)

# Or configure globally for MCP tools
SimpleCovMcp.configure_error_handling do |handler|
  handler.log_errors = true
  handler.show_stack_traces = true  # For debugging
end
```

### Legacy Error Handling Tips

- Missing resultset: `SimpleCov::Mcp::CovUtil.find_resultset` raises with guidance to run tests or set `SIMPLECOV_RESULTSET`.
- Missing file coverage: lookups raise `"No coverage entry found for <path>"`.

Example: fail CI if a file has uncovered lines

```ruby
require "simple_cov_mcp"

model = SimpleCovMcp::CoverageModel.new(root: Dir.pwd)
res   = model.uncovered_for("lib/foo.rb")
if res['uncovered'].any?
  warn "Uncovered lines in lib/foo.rb: #{res['uncovered'].join(", ")}"
  exit 1
end
```

Example: enforce a project-wide minimum percentage

```ruby
require "simple_cov_mcp"

threshold = 90.0
min = model.all_files.map { |r| r['percentage'] }.min || 100.0
if min < threshold
  warn "Min coverage %.2f%% is below threshold %.2f%%" % [min, threshold]
  exit 1
end
```

Public API stability:

- Consider the following public and stable under SemVer:
  - `SimpleCovMcp::CoverageModel.new(root:, resultset:, staleness: 'off', tracked_globs: nil)`
  - `#raw_for(path)`, `#summary_for(path)`, `#uncovered_for(path)`, `#detailed_for(path)`, `#all_files(sort_order:)`, `#format_table(rows: nil, sort_order:, check_stale:, tracked_globs:)`
  - Return shapes shown above (keys and value types). For `all_files`, each row also includes `'stale' => true|false`.
  - `#format_table` returns a formatted table string with Unicode borders and summary counts.
- CLI (`SimpleCovMcp.run(argv)`) and MCP tools remain stable but are separate surfaces.
- Internal helpers under `SimpleCovMcp::CovUtil` may change; prefer `CoverageModel` unless you need low-level access.

### Resultset Location

- Defaults (search order):
  1. `.resultset.json`
  2. `coverage/.resultset.json`
  3. `tmp/.resultset.json`
- Override via CLI: `--resultset PATH` (PATH may be the file itself or a directory containing `.resultset.json`).
- Override via environment: `SIMPLECOV_RESULTSET=PATH` (file or directory). This takes precedence over defaults. The CLI flag, when present, takes precedence over the environment variable.

### CLI Mode

### Stale Coverage Errors

When strict staleness checking is enabled, the model (and CLI) raise a
`CoverageDataStaleError` if a source file appears newer than the coverage data
or the line counts differ.

- Enable per instance: `SimpleCovMcp::CoverageModel.new(staleness: 'error')`

The error message is detailed and includes:

- File and Coverage times (UTC and local) and line counts
- A delta indicating how much newer the file is than coverage
- The absolute path to the r`.resultset.json` used

Example excerpt:

```
Coverage data stale: Coverage data appears stale for lib/foo.rb
File      - time: 2025-09-16T14:03:22Z (local 2025-09-16T07:03:22-07:00), lines: 226
Coverage  - time: 2025-09-15T21:11:09Z (local 2025-09-15T14:11:09-07:00), lines: 220
Delta     - file is +123s newer than coverage
Resultset - /path/to/your/project/coverage/.resultset.json
```

Run in a project directory with a SimpleCov resultset:

```sh
simplecov-mcp            # same as 'list'
```

Subcommands:

- `list` — show files coverage (table or --json, sorted ascending by default)
- `summary <path>` — show covered/total/% for a file
- `raw <path>` — show the original SimpleCov lines array
- `uncovered <path>` — show uncovered lines and summary
- `detailed <path>` — show per-line rows with hits and covered
- `version` — show version information

Global flags (OptionParser):

- `-r`, `--resultset PATH` — path or directory for `.resultset.json`
- `-R`, `--root PATH` — project root (default `.`)
- `-j`, `--json` — print JSON output for machine use
- `-o`, `--sort-order a|d` — for `list` (`a` = ascending, `d` = descending)
- `-s`, `--source[=MODE]` — include source text for `summary`, `uncovered`, `detailed` (MODE: `full` or `uncovered`; default `full`)
- `-c`, `--source-context N` — for `--source=uncovered`, lines of context (default 2)
- `--color` / `--no-color` — enable/disable ANSI colors in source output
- `-S`, `--stale off|error` — staleness checking mode (default `off`)
- `-g`, `--tracked-globs x,y,z` — globs for filtering files (applies to `list`)
- `-l`, `--log-file PATH` — set log file location (use `-` to disable)
- `-h`, `--help` — show usage

#### CLI Examples

**Basic Usage:**
```sh
# Show coverage table for all files (default)
simplecov-mcp

# Show coverage summary for a specific file
simplecov-mcp summary lib/my_class.rb

# Show uncovered lines with source context (using short options)
simplecov-mcp uncovered lib/my_class.rb -s=uncovered -c 3

# Get detailed per-line coverage with full source
simplecov-mcp detailed lib/my_class.rb -s
```

**Custom Resultset Location:**
```sh
# Using short option with file path
simplecov-mcp -r build/coverage/.resultset.json

# Using short option with directory (looks for .resultset.json inside)
simplecov-mcp -r coverage

# Using environment variable
SIMPLECOV_RESULTSET=coverage/.resultset.json simplecov-mcp

# Environment variable with directory
SIMPLECOV_RESULTSET=coverage simplecov-mcp summary lib/my_class.rb
```

**JSON Output and Sorting:**
```sh
# JSON output for machine consumption (short option)
simplecov-mcp -j

# Sort by highest coverage first
simplecov-mcp list -o d

# The long flag also accepts shortcuts
simplecov-mcp list --sort-order a

# Combined: JSON output with custom resultset and sorting (mixed short/long options)
simplecov-mcp list -j -r coverage -o a

# Compact: JSON summary with source included
simplecov-mcp summary lib/my_class.rb -j -s
```

**Staleness Checking:**
```sh
# Enable strict staleness checking (exits with error if stale)
simplecov-mcp -S error

# Check for new files that should be covered
simplecov-mcp list -S error -g "lib/**/*.rb,app/**/*.rb"

# Summary with staleness checking
simplecov-mcp summary lib/my_class.rb -S error
```

**Force CLI Mode:**
```sh
# When you need to ensure CLI output (e.g., in scripts)
SIMPLECOV_MCP_CLI=1 simplecov-mcp list --json
```

Example output:

```text
┌───────────────────────────┬──────────┬──────────┬────────┬───┐
│ File                      │        % │  Covered │  Total │ ! │
├───────────────────────────┼──────────┼──────────┼────────┼───┤
│ spec/user_spec.rb         │    85.71 │       12 │     14 │   │
│ lib/models/user.rb        │    92.31 │       12 │     13 │ ! │
│ lib/services/auth.rb      │   100.00 │        8 │      8 │   │
└───────────────────────────┴──────────┴──────────┴────────┴───┘
```

Files are sorted by percentage (ascending), then by path.

### MCP Server Mode

When stdin has data (e.g., from an MCP client), the program runs as an MCP server over stdio.

Available tools:

- `coverage_raw_tool(path, root=".", resultset=nil, stale='off')`
- `coverage_summary_tool(path, root=".", resultset=nil, stale='off')`
- `uncovered_lines_tool(path, root=".", resultset=nil, stale='off')`
- `coverage_detailed_tool(path, root=".", resultset=nil, stale='off')`
- `all_files_coverage_tool(root=".", resultset=nil, stale='off', tracked_globs=nil)`
  - Returns `{ files: [{"file","covered","total","percentage","stale"}, ...] }` where `stale` is a boolean.
- `version_tool()` — returns version information

Response shape and content types:

- JSON tools above return a single content item `{ "type": "resource", "resource": { "mimeType": "application/json", "text": "{...}", "name": "<tool>.json" } }`.
- `coverage_table_tool` and `version_tool` return `{ "type": "text", "text": "..." }`.

Notes:

- `resultset` lets clients pass a nonstandard path to `.resultset.json` directly (absolute or relative to `root`). It may be:
  - a file path to `.resultset.json`, or
  - a directory path containing `.resultset.json` (e.g., `coverage/`).
- If `resultset` is omitted, the server checks `SIMPLECOV_RESULTSET`, then searches `.resultset.json`, `coverage/.resultset.json`, `tmp/.resultset.json` in that order.
- `stale` controls staleness checking per call (`off` or `error`).
- For `all_files_coverage`, `tracked_globs` detects new project files missing from coverage, and the tool also flags covered files that are newer than the coverage timestamp or present in coverage but deleted in the project.

Example (manual - note single-line JSON-RPC format):

```sh
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"coverage_summary_tool","arguments":{"path":"lib/foo.rb"}}}' | simplecov-mcp
```

With an explicit resultset path:

```sh
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"coverage_summary_tool","arguments":{"path":"lib/foo.rb","resultset":"build/coverage/.resultset.json"}}}' | simplecov-mcp
```

With a resultset directory:

```sh
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"coverage_summary_tool","arguments":{"path":"lib/foo.rb","resultset":"coverage"}}}' | simplecov-mcp
```

CLI vs MCP summary:

- CLI: use subcommands and global flags. Pass `--resultset PATH` or set `SIMPLECOV_RESULTSET`.
- MCP: pass `resultset` in tool arguments, or set `SIMPLECOV_RESULTSET`.

## Troubleshooting

### Installation and Setup Issues

#### Ruby Version Compatibility
**Problem**: `simplecov-mcp` fails to start or reports missing dependencies
**Symptoms**: 
- "command not found: simplecov-mcp"
- "cannot load such file -- mcp"
- MCP client reports connection timeout

**Solutions**:
1. **Check Ruby version**: This gem requires Ruby >= 3.2
   ```sh
   ruby -v  # Should report 3.2.0 or higher
   ```

2. **Fix PATH for version managers**:
   ```sh
   # rbenv
   rbenv rehash
   which simplecov-mcp  # Should point to rbenv shim
   
   # asdf
   asdf reshim ruby
   which simplecov-mcp  # Should point to asdf shim
   
   # RVM
   rvm use 3.2.0  # or your preferred 3.2+ version
   which simplecov-mcp
   ```

3. **MCP client configuration with specific Ruby version**:
   ```json
   {
     "mcpServers": {
       "simplecov-mcp": {
         "command": "/home/user/.rbenv/shims/simplecov-mcp",
         "args": [],
         "env": {"SIMPLECOV_RESULTSET": "coverage"}
       }
     }
   }
   ```

#### PATH and Installation Issues
**Problem**: Gem installed but command not found

**Solutions**:
1. **Add gem bin directory to PATH**:
   ```sh
   # Find gem bin directory
   gem env | grep "EXECUTABLE DIRECTORY"
   # or
   ruby -e 'puts Gem.bindir'
   
   # Add to your shell profile (.bashrc, .zshrc, etc.)
   export PATH="$(ruby -e 'puts Gem.bindir'):$PATH"
   ```

2. **Use bundle exec** (if in a project with Gemfile):
   ```sh
   bundle exec simplecov-mcp
   ```

### Coverage Data Issues

#### Missing .resultset.json File
**Problem**: "Could not find .resultset.json" error

**Solutions**:
1. **Generate coverage data first**:
   ```sh
   # Run your test suite to generate coverage
   bundle exec rspec  # or your test command
   ls coverage/.resultset.json  # verify file exists
   ```

2. **Specify custom location**:
   ```sh
   # If coverage file is elsewhere
   simplecov-mcp --resultset path/to/.resultset.json
   # or
   SIMPLECOV_RESULTSET=path/to/coverage simplecov-mcp
   ```

#### Stale Coverage Data
**Problem**: "Coverage data appears stale" warnings or errors

**Solutions**:
1. **Regenerate coverage** (recommended):
   ```sh
   bundle exec rspec  # or your test command
   ```

2. **Disable staleness checking**:
   ```sh
   simplecov-mcp --stale off  # Default behavior
   ```

3. **Use staleness checking to find issues**:
   ```sh
   # Let it show which files are stale
   simplecov-mcp -S error -g "lib/**/*.rb"
   ```

#### File Not Found in Coverage
**Problem**: "No coverage data found for file" error

**Solutions**:
1. **Check file path**: Use path relative to project root or absolute path
   ```sh
   # Good
   simplecov-mcp summary lib/my_class.rb
   # Also good
   simplecov-mcp summary /full/path/to/lib/my_class.rb
   ```

2. **Verify file is covered**: Check if file is in coverage report
   ```sh
   simplecov-mcp | grep "my_class.rb"
   ```

3. **File might not be executed by tests**: Add tests that exercise the file

### MCP Server Issues

#### MCP Client Connection Problems
**Problem**: MCP client can't connect or times out

**Diagnostic steps**:
1. **Test manually**:
   ```sh
   # This should show coverage table
   simplecov-mcp
   
   # Test MCP server mode
   echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"version_tool","arguments":{}}}' | simplecov-mcp
   ```

2. **Check logs**:
   ```sh
   tail -f ~/simplecov_mcp.log
   ```

3. **Enable debug mode**:
   ```sh
   SIMPLECOV_MCP_DEBUG=1 simplecov-mcp
   ```

#### JSON-RPC Parse Errors
**Problem**: MCP server reports JSON parse errors

**Solutions**:
1. **Ensure single-line JSON**: JSON-RPC messages must be on one line
   ```sh
   # Wrong (multi-line)
   echo '{
  "jsonrpc": "2.0",
  "id": 1
}' | simplecov-mcp
   
   # Correct (single line)
   echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"version_tool","arguments":{}}}' | simplecov-mcp
   ```

#### MCP Tool Errors
**Problem**: MCP tools return error responses

**Common solutions**:
1. **Check required parameters**:
   ```json
   {"name": "coverage_summary_tool", "arguments": {"path": "lib/file.rb"}}
   ```

2. **Use help_tool to discover tools**:
   ```json
   {"name": "help_tool", "arguments": {}}
   ```

3. **Check parameter format**:
   ```json
   {"name": "all_files_coverage_tool", "arguments": {"tracked_globs": ["lib/**/*.rb"]}}
   ```

### Performance Issues

#### Slow Coverage Analysis
**Problem**: Commands take a long time to complete

**Solutions**:
1. **Large .resultset.json files**: Consider splitting tests or using filters
2. **Many files**: Use specific file paths instead of `list` command
3. **Network drives**: Ensure coverage files are on local storage

### Environment-Specific Issues

#### Docker/Container Issues
**Problem**: Can't find files or coverage in containerized environments

**Solutions**:
1. **Mount project directory**:
   ```sh
   docker run -v $(pwd):/app -w /app ruby:3.2 simplecov-mcp
   ```

2. **Set correct working directory**:
   ```sh
   simplecov-mcp -R /app
   ```

#### CI/CD Issues
**Problem**: Works locally but fails in CI

**Solutions**:
1. **Check Ruby version in CI**:
   ```yaml
   - name: Setup Ruby
     uses: ruby/setup-ruby@v1
     with:
       ruby-version: 3.2
   ```

2. **Ensure coverage is generated**:
   ```yaml
   - run: bundle exec rspec  # Generate coverage first
   - run: bundle exec simplecov-mcp --stale error
   ```

3. **Use absolute paths**:
   ```yaml
   - run: SIMPLECOV_RESULTSET=$PWD/coverage simplecov-mcp
   ```

### Getting Help

If you're still having issues:

1. **Check logs**: Look at `~/simplecov_mcp.log` for error details
2. **Enable debug mode**: Set `SIMPLECOV_MCP_DEBUG=1` for verbose output
3. **Test basic functionality**: Run `simplecov-mcp --help` and `simplecov-mcp` to verify basic operation
4. **Check your setup**: Verify Ruby version, gem installation, and coverage file existence

### Notes

- Library entrypoint: `require "simple_cov_mcp"` (also `simplecov_mcp`). Legacy `simple_cov/mcp` is supported.
- Programmatic run: `SimpleCovMcp.run(ARGV)`
- Staleness checks: pass `staleness: 'error'` to `CoverageModel` (or use CLI `--stale error`) to
  raise if source mtimes are newer than coverage or line counts mismatch. Use
  `--tracked-globs` (CLI) or `tracked_globs` (API/MCP) to flag new files.
- Logs basic diagnostics to `~/simplecov_mcp.log`.

## Executables and PATH

To run `simplecov-mcp` globally, your PATH must include where Ruby installs executables.

- Version managers
  - RVM, rbenv, asdf, chruby typically add the right bin/shim directories to PATH.
  - Ensure your shell is initialized (e.g., rbenv init, asdf reshim ruby after installs).
- Without a manager
  - Add the gem bin dir to PATH: see it with `gem env` (look for "EXECUTABLE DIRECTORY") or `ruby -e 'puts Gem.bindir'`.
  - Example: `export PATH="$HOME/.gem/ruby/3.2.0/bin:$PATH"` (adjust version).
- Alternatives
  - Use Bundler: `bundle exec simplecov-mcp` with cwd set to your project.
  - Symlink the repo executable into a bin on your PATH; the script resolves its lib/ via realpath.
  - Or configure Codex to run the executable by filename (`simplecov-mcp`) and inherit the current workspace as cwd.

## Development

Standard Ruby gem structure. After cloning:

```sh
bundle install
ruby -Ilib exe/simplecov-mcp
```

Run tests with coverage (SimpleCov writes to `coverage/`):

```sh
bundle exec rspec
# open coverage/index.html for HTML report, or run exe/simplecov-mcp for table summary
```

## Claude Code 

In general we want to avoid specifying configuration instructions here for the AI agents, since that can change, and there are several products to cover. However, Claude Code is a dominant player, and the various help resources confuse the user with many different file names and locations. So, in our experience, the simplest way to configure MCP servers for Claude Code is to use their command line tool. Here is an example:

```bash
claude mcp add simplecov-mcp -- bash -l -c "rvm use 3.3.8 && /Users/kbennett/.rvm/gems/ruby-3.3.8/bin/simplecov-mcp"
```
* The `rvm use` command is necessary only if the Ruby version is not the rvm default version.
* The -s option specifies scope. 'user' configures the MCP server globally for the current user. 'local' can be used to configure a specific project (directory tree).
* If using a version manager such as rvm, note that the executable will be in a directory tied to the Ruby version. This means that if you change the Ruby version, you'll need to remove the configuration (using `claude mcp remove...`) and then readd it with the new filespec.
* You can set the user server to your most commonly used version and override it when necessary with the '-s local' option.


## License

MIT
