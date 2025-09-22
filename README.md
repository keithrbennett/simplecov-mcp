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
```

### MCP Quick Start

- Prereqs: Ruby 3.2+; run tests once so `coverage/.resultset.json` exists.
- One-off MCP requests can be made by piping JSON-RPC to the server:

**Important**: JSON-RPC messages must be on a single line (no line breaks). Multi-line JSON will cause parse errors.

```sh
# Per-file summary (staleness off)
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"coverage_summary_tool","arguments":{"path":"lib/foo.rb","resultset":"coverage","stale":"off"}}}' | simplecov-mcp

# All files with project-level staleness checks
echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"all_files_coverage_tool","arguments":{"resultset":"coverage","stale":"error","tracked_globs":["lib/**/*.rb"]}}}' | simplecov-mcp
```

Tip: In an MCP-capable editor/agent, configure `simplecov-mcp` as a stdio server and call the same tool names with the `arguments` shown above.

Response content types (MCP):

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

----


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
  - `#raw_for(path)`, `#summary_for(path)`, `#uncovered_for(path)`, `#detailed_for(path)`, `#all_files(sort_order:)`
  - Return shapes shown above (keys and value types). For `all_files`, each row also includes `'stale' => true|false`.
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

- `list` — show the table of all files (sorted ascending by default)
- `summary <path>` — show covered/total/% for a file
- `raw <path>` — show the original SimpleCov lines array
- `uncovered <path>` — show uncovered lines and summary
- `detailed <path>` — show per-line rows with hits and covered
- `version` — show version information

Global flags (OptionParser):

- `--cli` (alias `--report`) — force CLI output
- `--resultset PATH` — path or directory for `.resultset.json`
- `--root PATH` — project root (default `.`)
- `--json` — print JSON output for machine use
- `--sort-order ascending|descending` — for `list`
- `--source[=MODE]` — include source text for `summary`, `uncovered`, `detailed` (MODE: `full` or `uncovered`; default `full`)
- `--source-context N` — for `--source=uncovered`, lines of context (default 2)
- `--color` / `--no-color` — enable/disable ANSI colors in source output
- `--stale off|error` — staleness checking mode (default `off`)
- `--tracked-globs x,y,z` — globs for files that should be covered (applies to `list` staleness only)
- `--help` — show usage

Select a nonstandard resultset path:

```sh
simplecov-mcp --cli --resultset build/coverage/.resultset.json
# or
SIMPLECOV_RESULTSET=build/coverage/.resultset.json simplecov-mcp --cli
```

You can also pass a directory that contains `.resultset.json` (common when the file lives in a `coverage/` folder):

```sh
simplecov-mcp --cli --resultset coverage
# or via env
SIMPLECOV_RESULTSET=coverage simplecov-mcp --cli
```

Forces CLI mode:

```sh
simplecov-mcp --cli
# or
SIMPLECOV_MCP_CLI=1 simplecov-mcp
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

- CLI: use subcommands. Pass `--resultset PATH` or set `SIMPLECOV_RESULTSET`.
- MCP: pass `resultset` in tool arguments, or set `SIMPLECOV_RESULTSET`.

## Troubleshooting

- MCP client fails to start or times out
  - Likely cause: launching `simplecov-mcp` with an older Ruby that cannot load the `mcp` gem. This gem requires Ruby >= 3.2.
  - Check the Ruby your MCP client uses: run `ruby -v` in the same environment your client inherits; ensure it reports 3.2+.
  - Fix PATH or select a newer Ruby via rbenv/rvm/asdf, then retry. You can configure your MCP client to point to the shim/binary for that Ruby version. For example:
    - rbenv shim: `~/.rbenv/shims/simplecov-mcp`
    - asdf shim: `~/.asdf/shims/simplecov-mcp`
    - RVM wrapper: `/Users/you/.rvm/wrappers/ruby-3.3.0/simplecov-mcp` (adjust version)
    - Codex CLI example (`~/.codex/config.toml`):
      ```toml
      # Use the Ruby 3.2+ shim for the MCP server
      [tools.simplecov_mcp]
      command = "/Users/you/.rbenv/shims/simplecov-mcp"
      cwd = "/path/to/your/project"
      ```
  - Validate manually: `simplecov-mcp --cli` (or from this repo: `ruby -Ilib exe/simplecov-mcp --cli`). If you see the coverage table, the binary starts correctly.
  - On failures, check `~/simplecov_mcp.log` for details.

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
ruby -Ilib exe/simplecov-mcp --cli
```

Run tests with coverage (SimpleCov writes to `coverage/`):

```sh
bundle exec rspec
# open coverage/index.html for HTML report, or run exe/simplecov-mcp for table summary
```

## License

MIT
