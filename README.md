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
simplecov-mcp
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

- `coverage_raw(path, root=".")`
- `coverage_summary(path, root=".")`
- `uncovered_lines(path, root=".")`
- `coverage_detailed(path, root=".")`
- `all_files_coverage(root=".")`

Example (manual):

```
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"coverage_summary","arguments":{"path":"lib/foo.rb"}}}' | simplecov-mcp
```

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

## License

MIT
