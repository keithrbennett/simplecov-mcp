# simplecov-mcp

MCP server + CLI for inspecting SimpleCov coverage data.

This gem provides:

- An MCP (Model Context Protocol) server exposing tools to query coverage for files.
- A flexible CLI with subcommands to list all files, show a file summary, print raw coverage arrays, list uncovered lines, and display detailed per-line hits. Supports JSON output, displaying annotated source code (full file or uncovered lines with context), and custom resultset locations.

## Features

- MCP server tools for coverage queries: raw, summary, uncovered, detailed, and all-files list.
- CLI subcommands: `list`, `summary`, `raw`, `uncovered`, `detailed` (default `list`).
- JSON output with `--json` for machine use; human-readable tables/rows by default.
- Annotated source snippets with `--source[=full|uncovered]` and `--source-context N`; optional colors with `--color/--no-color`.
- Flexible resultset location: `--resultset PATH` or `SIMPLECOV_RESULTSET`; accepts file or directory; sensible default search order.
- Works installed as a gem, via Bundler (`bundle exec`), or directly from this repo’s `exe/` (symlink-safe).

## SimpleCov Independence

This codebase does not require, and is not connected to, the `simplecov` library at runtime. Its only interaction is reading the JSON resultset file that SimpleCov generates (`.resultset.json`). As long as that file exists in your project (in a default or specified location), the CLI and MCP server can operate without `require "simplecov"` in your app or test process.

## Installation

Add to your Gemfile or install directly:

```
gem install simplecov-mcp
```

Require path is `simplecov/mcp` (also `simplecov_mcp`). Executable is `simplecov-mcp`.

## Usage

### Resultset Location

- Defaults (search order):
  1. `.resultset.json`
  2. `coverage/.resultset.json`
  3. `tmp/.resultset.json`
- Override via CLI: `--resultset PATH` (PATH may be the file itself or a directory containing `.resultset.json`).
- Override via environment: `SIMPLECOV_RESULTSET=PATH` (file or directory). This takes precedence over defaults. The CLI flag, when present, takes precedence over the environment variable.

### CLI Mode

Run in a project directory with a SimpleCov resultset:

```
simplecov-mcp            # same as 'list'
```

Subcommands:

- `list` — show the table of all files (sorted ascending by default)
- `summary <path>` — show covered/total/% for a file
- `raw <path>` — show the original SimpleCov lines array
- `uncovered <path>` — show uncovered lines and summary
- `detailed <path>` — show per-line rows with hits and covered

Global flags (OptionParser):

- `--cli` (alias `--report`) — force CLI output
- `--resultset PATH` — path or directory for `.resultset.json`
- `--root PATH` — project root (default `.`)
- `--json` — print JSON output for machine use
- `--sort-order ascending|descending` — for `list`
- `--source[=MODE]` — include source text for `summary`, `uncovered`, `detailed` (MODE: `full` or `uncovered`; default `full`)
- `--source-context N` — for `--source=uncovered`, lines of context (default 2)
- `--color` / `--no-color` — enable/disable ANSI colors in source output
- `--help` — show usage

Select a nonstandard resultset path:

```
simplecov-mcp --cli --resultset build/coverage/.resultset.json
# or
SIMPLECOV_RESULTSET=build/coverage/.resultset.json simplecov-mcp --cli
```

You can also pass a directory that contains `.resultset.json` (common when the file lives in a `coverage/` folder):

```
simplecov-mcp --cli --resultset coverage
# or via env
SIMPLECOV_RESULTSET=coverage simplecov-mcp --cli
```

Forces CLI mode:

```
simplecov-mcp --cli
# or
COVERAGE_MCP_CLI=1 simplecov-mcp
```

Example output:

```
┌───────────────────────────┬──────────┬──────────┬────────┐
│ File                      │        % │  Covered │  Total │
├───────────────────────────┼──────────┼──────────┼────────┤
│ spec/user_spec.rb         │    85.71 │       12 │     14 │
│ lib/models/user.rb        │    92.31 │       12 │     13 │
│ lib/services/auth.rb      │   100.00 │        8 │      8 │
└───────────────────────────┴──────────┴──────────┴────────┘
```

Files are sorted by percentage (ascending), then by path.

### MCP Server Mode

When stdin has data (e.g., from an MCP client), the program runs as an MCP server over stdio.

Available tools:

- `coverage_raw(path, root=".", resultset=nil)`
- `coverage_summary(path, root=".", resultset=nil)`
- `uncovered_lines(path, root=".", resultset=nil)`
- `coverage_detailed(path, root=".", resultset=nil)`
- `all_files_coverage(root=".", resultset=nil)`

Notes:

- `resultset` lets clients pass a nonstandard path to `.resultset.json` directly (absolute or relative to `root`). It may be:
  - a file path to `.resultset.json`, or
  - a directory path containing `.resultset.json` (e.g., `coverage/`).
- If `resultset` is omitted, the server checks `SIMPLECOV_RESULTSET`, then searches `.resultset.json`, `coverage/.resultset.json`, `tmp/.resultset.json` in that order.

Example (manual):

```
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"coverage_summary","arguments":{"path":"lib/foo.rb"}}}' | simplecov-mcp
```

With an explicit resultset path:

```
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"coverage_summary","arguments":{"path":"lib/foo.rb","resultset":"build/coverage/.resultset.json"}}}' | simplecov-mcp
```

With a resultset directory:

```
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"coverage_summary","arguments":{"path":"lib/foo.rb","resultset":"coverage"}}}' | simplecov-mcp
```

CLI vs MCP summary:

- CLI: use subcommands. Pass `--resultset PATH` or set `SIMPLECOV_RESULTSET`.
- MCP: pass `resultset` in tool arguments, or set `SIMPLECOV_RESULTSET`.

### Notes

- Library entrypoint: `require "simplecov/mcp"` or `require "simplecov_mcp"`
- Programmatic run: `Simplecov::Mcp.run(ARGV)`
- Logs basic diagnostics to `~/coverage_mcp.log`.

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

```
bundle install
ruby -Ilib exe/simplecov-mcp --cli
```

Run tests with coverage (SimpleCov writes to `coverage/`):

```
bundle exec rspec
# open coverage/index.html for HTML report, or run exe/simplecov-mcp for table summary
```

## License

MIT
