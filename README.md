# simplecov-mcp

MCP server + CLI for inspecting SimpleCov coverage data.

This gem provides:

- An MCP (Model Context Protocol) server exposing tools to query coverage for files.
- A human-friendly CLI that prints a sorted table of file coverage.

## Installation

Add to your Gemfile or install directly:

```
gem install simplecov-mcp
```

Require path is `simplecov/mcp` (also `simplecov_mcp`). Executable is `simplecov-mcp`.

## Usage

Environment variable:

- `SIMPLECOV_RESULTSET` — optional explicit path to `.resultset.json`.

Search order for resultset:

1. `.resultset.json`
2. `coverage/.resultset.json`
3. `tmp/.resultset.json`

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
``;

Example output:

```
┌───────────────────────────┬──────────┬──────────┬────────┐
│ File                      │        % │  Covered │  Total │
├───────────────────────────┼──────────┼──────────┼────────┤
│ lib/models/user.rb        │    92.31 │       12 │     13 │
│ lib/services/auth.rb      │   100.00 │        8 │      8 │
│ spec/user_spec.rb         │    85.71 │       12 │     14 │
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
