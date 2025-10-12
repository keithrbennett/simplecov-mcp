# simplecov-mcp

> MCP server + CLI + Ruby library for inspecting SimpleCov coverage data

[![Gem Version](https://badge.fury.io/rb/simplecov-mcp.svg)](https://badge.fury.io/rb/simplecov-mcp)

## What is simplecov-mcp?

A flexible tool for analyzing SimpleCov coverage data with three interfaces:

- **🤖 MCP Server** - Integrate coverage queries with AI coding assistants (Claude, Cursor, etc.)
- **💻 CLI** - Command-line coverage reports, queries, and analysis
- **💎 Ruby Library** - Programmatic API for custom coverage analysis

Single-suite projects avoid loading SimpleCov at runtime, while multi-suite resultsets trigger a lazy SimpleCov load so coverage can be merged correctly.

## Quick Start

### Installation

```sh
gem install simplecov-mcp
```

### Generate Coverage Data

```sh
# Run your tests with SimpleCov enabled
bundle exec rspec  # or your test command

# Verify coverage was generated
ls coverage/.resultset.json
```

### Basic Usage

**CLI - View Coverage Table:**
```sh
simplecov-mcp
```

**CLI - Check Specific File:**
```sh
simplecov-mcp summary lib/simplecov_mcp/model.rb
simplecov-mcp uncovered lib/simplecov_mcp/cli.rb
```

**Ruby Library:**
```ruby
require "simplecov_mcp"

model = SimpleCovMcp::CoverageModel.new
files = model.all_files
# => [{ "file" => "lib/simplecov_mcp/model.rb", "covered" => 114, "total" => 118, "percentage" => 96.61, "stale" => false }, ...]

summary = model.summary_for("lib/simplecov_mcp/model.rb")
# => { "file" => "lib/simplecov_mcp/model.rb", "summary" => { "covered" => 114, "total" => 118, "pct" => 96.61 }, "stale" => false }
```

**MCP Server:**
See [MCP Integration Guide](docs/MCP_INTEGRATION.md) for AI assistant setup.

## Key Features

- ✅ **Multiple interfaces** - MCP server, CLI, and Ruby API
- ✅ **Rich output formats** - Tables, JSON, annotated source code
- ✅ **Staleness detection** - Identify outdated coverage for CI/CD
  - **M** (Missing): File no longer exists
  - **T** (Timestamp): File modified after coverage was generated
  - **L** (Length): Line count mismatch between source and coverage
- ✅ **Lazy SimpleCov dependency** - Only loads SimpleCov when multiple suites need merging
- ✅ **Flexible path resolution** - Works with absolute or relative paths
- ✅ **Comprehensive error handling** - Context-aware messages for each mode
- ⚠️ **Branch metrics summarized** - SimpleCov MCP does not report individual
  branch legs. When a resultset contains branch-only coverage data we collapse
  the hits into a single per-line total so coverage tables, CLI commands, and
  MCP tools remain compatible. Use native SimpleCov reports if you require
  branch-by-branch visibility.

## Multiple Coverage Suites

- `.resultset.json` files that contain several suites (e.g., RSpec + Cucumber) are merged automatically using SimpleCov’s combine logic. All covered files from every suite are now available to the CLI, library, and MCP tools.
- When suites are merged we currently keep a single “latest suite” timestamp for staleness checks. That matches prior behaviour but can under-report stale files if only some suites were re-run after a change. A per-file timestamp refinement is planned; until then, consider multi-suite staleness advisory rather than definitive.
- The gem now depends on `simplecov` at runtime so the merge logic is always available. Single-suite resultsets still load instantly because SimpleCov is only required when needed.
- Only suites stored inside a *single* `.resultset.json` are merged. If your project produces separate resultset files (for example, different CI jobs writing `coverage/job1/.resultset.json`, `coverage/job2/.resultset.json`, …) you must merge them yourself before pointing `simplecov-mcp` at the combined file.

## Documentation

📚 **Complete Guides:**

- **[Installation](docs/INSTALLATION.md)** - Setup for different environments and version managers
- **[CLI Usage](docs/CLI_USAGE.md)** - Complete command-line reference with examples
- **[MCP Integration](docs/MCP_INTEGRATION.md)** - Configure with AI assistants (Claude, Cursor, Codex)
- **[Library API](docs/LIBRARY_API.md)** - Ruby API documentation and recipes
- **[Examples](docs/EXAMPLES.md)** - Cookbook of common use cases
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[Development](docs/DEVELOPMENT.md)** - Contributing and development guide
- **[Error Handling](docs/ERROR_HANDLING.md)** - Error modes and exception handling

## Quick Examples

**CLI (lowest coverage first):** `simplecov-mcp`

**Ruby summary:**
```ruby
require "simplecov_mcp"
model = SimpleCovMcp::CoverageModel.new
summary = model.summary_for("lib/simplecov_mcp/model.rb")
# => { "file" => "...", "summary" => { "covered" => 114, "total" => 118, "pct" => 96.61 }, "stale" => false }
```

More in [CLI Usage](docs/CLI_USAGE.md) and [Library API](docs/LIBRARY_API.md).

## Requirements


- **Ruby >= 3.2** (required by `mcp` gem dependency)
- SimpleCov-generated `.resultset.json` file
- `simplecov` gem >= 0.21 (only loaded when multiple suites require merging)
- RVM users: export your preferred ruby/gemset *before* running commands (e.g. `rvm use 3.4.5@simplecov-mcp`).

### Note for Codex on macOS

Codex’s macOS sandbox disallows running `/bin/ps`. RVM depends on `ps` to bootstrap its environment, so `bundle exec rspec` fails in that sandbox because the shell falls back to the system Ruby 2.6. There isn’t a repo-side fix—use a Ruby version manager that doesn’t rely on `ps`, or run the suite outside that environment. (Codex on Ubuntu, Gemini, and Claude Code aren’t affected.)

## Configuring the Resultset

`simplecov-mcp` needs to locate the `.resultset.json` file generated by SimpleCov. You can configure this in several ways, which are checked in the following order of precedence:

**1. Command-Line Option (`--resultset`)**

This is the most direct way to specify the location. It overrides all other settings.

```sh
# Exact path to the file
simplecov-mcp --resultset /path/to/your/coverage/.resultset.json

# Path to the directory containing the file
simplecov-mcp --resultset /path/to/your/coverage
```

**2. Environment Variable (`SIMPLECOV_MCP_OPTS`)**

You can set default options in an environment variable. This is useful for setting a project-wide default without having to type it every time.

```sh
export SIMPLECOV_MCP_OPTS="--resultset /path/to/your/coverage"
```

Command-line options will always override the environment variable.

**3. Default Search Paths**

If no path is provided via the command line or environment variables, `simplecov-mcp` will search for `.resultset.json` in the following common locations, relative to the project root:

1.  `.resultset.json`
2.  `coverage/.resultset.json`
3.  `tmp/.resultset.json`

**4. MCP Server Configuration**

When running as an MCP server, you can configure the resultset path in your client's configuration file.

```json
{
  "mcpServers": {
    "simplecov-mcp": {
      "command": "/path/to/simplecov-mcp",
      "args": ["--resultset", "/path/to/your/coverage"]
    }
  }
}
```

For more details on MCP configuration, see the [MCP Integration Guide](docs/MCP_INTEGRATION.md).



## Common Workflows

### Find Coverage Gaps

```sh
# Files with worst coverage
simplecov-mcp list --sort-order d # display table in descending order, worst will be at end of output
simplecov-mcp list -o d           # same as above, short form option
simplecov-mcp list | less         # display table in pager, worst files first
simplecov-mcp list | head -10     # truncate the table

# Specific directory
simplecov-mcp list --tracked-globs "lib/simplecov_mcp/tools/**/*.rb"

# Export for analysis
simplecov-mcp list --json > coverage-report.json
```

### CI/CD Integration

```sh
# Fail build if coverage is stale
simplecov-mcp --stale error || exit 1

# Generate coverage report artifact
simplecov-mcp list --json > artifacts/coverage.json
```

### Investigate Specific Files

```sh
# Quick summary
simplecov-mcp summary lib/simplecov_mcp/model.rb

# See uncovered lines
simplecov-mcp uncovered lib/simplecov_mcp/cli.rb

# View in context
simplecov-mcp uncovered lib/simplecov_mcp/cli.rb --source=uncovered --source-context 3

# Detailed hit counts
simplecov-mcp detailed lib/simplecov_mcp/util.rb
```

## CLI Subcommands

- `list` - Show all files with coverage (default)
- `summary <path>` - Coverage summary for a file
- `raw <path>` - Raw SimpleCov lines array
- `uncovered <path>` - List uncovered line numbers
- `detailed <path>` - Per-line coverage with hit counts
- `version` - Show version information

Run `simplecov-mcp --help` for complete options.

## MCP Tools

When running as an MCP server, these tools are exposed:

- `coverage_summary_tool` - File coverage summary
- `coverage_detailed_tool` - Per-line coverage
- `coverage_raw_tool` - Raw SimpleCov array
- `uncovered_lines_tool` - Uncovered line numbers
- `all_files_coverage_tool` - Project-wide coverage
- `coverage_table_tool` - Formatted table
- `help_tool` - Tool discovery and guidance
- `version_tool` - Version information

See [MCP Integration Guide](docs/MCP_INTEGRATION.md#available-mcp-tools) for details.

## Troubleshooting

- **"command not found"** - See [Installation Guide](docs/INSTALLATION.md#path-configuration)
- **"cannot load such file -- mcp"** - Upgrade to Ruby >= 3.2
- **"Could not find .resultset.json"** - Run tests to generate coverage. See the [Configuring the Resultset](#configuring-the-resultset) section for more details.
- **MCP server won't connect** - Check PATH and Ruby version in [MCP Troubleshooting](docs/MCP_INTEGRATION.md#troubleshooting)

For more detailed help, see the full [Troubleshooting Guide](docs/TROUBLESHOOTING.md).

## Development

```sh
# Clone and setup
git clone https://github.com/keithrbennett/simplecov-mcp.git
cd simplecov-mcp
bundle install

# Run tests
bundle exec rspec

# Test locally
ruby -Ilib exe/simplecov-mcp

# Build and install
gem build simplecov-mcp.gemspec
gem install simplecov-mcp-*.gem
```

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for more *(coming soon)*.

## SimpleCov Dependency

`simplecov-mcp` now declares a runtime dependency on `simplecov` so it can merge multi-suite resultsets using SimpleCov’s own combine helpers. Single-suite projects still avoid loading SimpleCov at runtime, but when multiple suites are present the gem lazily requires SimpleCov to merge the coverage hashes.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass (`bundle exec rspec`)
5. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Links

- **GitHub:** https://github.com/keithrbennett/simplecov-mcp
- **RubyGems:** https://rubygems.org/gems/simplecov-mcp
- **Issues:** https://github.com/keithrbennett/simplecov-mcp/issues
- **Changelog:** [RELEASE_NOTES.md](RELEASE_NOTES.md)

## Related Files

- [CLAUDE.md](CLAUDE.md) - Claude Code integration notes
- [AGENTS.md](AGENTS.md) - AI agent configuration
- [GEMINI.md](GEMINI.md) - Gemini-specific guidance

---

**Made with ❤️ for better Ruby test coverage analysis**
