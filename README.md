# simplecov-mcp

> MCP server + CLI + Ruby library for inspecting SimpleCov coverage data

[![Gem Version](https://badge.fury.io/rb/simplecov-mcp.svg)](https://badge.fury.io/rb/simplecov-mcp)

## What is simplecov-mcp?

A flexible tool for analyzing SimpleCov coverage data with three interfaces:

- **🤖 MCP Server** - Integrate coverage queries with AI coding assistants (Claude, Cursor, etc.)
- **💻 CLI** - Command-line coverage reports, queries, and analysis
- **💎 Ruby Library** - Programmatic API for custom coverage analysis

All without requiring SimpleCov at runtime—just reads the `.resultset.json` file.

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
simplecov-mcp summary lib/simple_cov_mcp/model.rb
simplecov-mcp uncovered lib/simple_cov_mcp/cli.rb
```

**Ruby Library:**
```ruby
require "simple_cov_mcp"

model = SimpleCovMcp::CoverageModel.new
files = model.all_files
# => [{ "file" => "lib/simple_cov_mcp/model.rb", "covered" => 114, "total" => 118, "percentage" => 96.61, "stale" => false }, ...]

summary = model.summary_for("lib/simple_cov_mcp/model.rb")
# => { "file" => "lib/simple_cov_mcp/model.rb", "summary" => { "covered" => 114, "total" => 118, "pct" => 96.61 } }
```

**MCP Server:**
See [MCP Integration Guide](docs/MCP_INTEGRATION.md) for AI assistant setup.

## Key Features

- ✅ **Multiple interfaces** - MCP server, CLI, and Ruby API
- ✅ **Rich output formats** - Tables, JSON, annotated source code
- ✅ **Staleness detection** - Identify outdated coverage for CI/CD
- ✅ **No runtime SimpleCov dependency** - Just reads `.resultset.json`
- ✅ **Flexible path resolution** - Works with absolute or relative paths
- ✅ **Comprehensive error handling** - Context-aware messages for each mode

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
require "simple_cov_mcp"
model = SimpleCovMcp::CoverageModel.new
puts model.summary_for("lib/simple_cov_mcp/model.rb")
```

More in [CLI Usage](docs/CLI_USAGE.md) and [Library API](docs/LIBRARY_API.md).

## Requirements


- **Ruby >= 3.2** (required by `mcp` gem dependency)
- SimpleCov-generated `.resultset.json` file
- RVM users: export your preferred ruby/gemset *before* running commands (e.g. `rvm use 3.4.5@simplecov-mcp`).

### Note for Codex on macOS

Codex’s macOS sandbox disallows running `/bin/ps`. RVM depends on `ps` to bootstrap its environment, so `bundle exec rspec` fails in that sandbox because the shell falls back to the system Ruby 2.6. There isn’t a repo-side fix—use a Ruby version manager that doesn’t rely on `ps`, or run the suite outside that environment. (Codex on Ubuntu, Gemini, and Claude Code aren’t affected.)

## Environment Variables

### `SIMPLECOV_MCP_OPTS`

Set default command-line options:

```sh
# Default resultset location
export SIMPLECOV_MCP_OPTS="--resultset coverage"

# Enable JSON output by default
export SIMPLECOV_MCP_OPTS="--json"

# Multiple options
export SIMPLECOV_MCP_OPTS="--resultset build/coverage --stale error"
```

Command-line arguments override environment options.



## Common Workflows

### Find Coverage Gaps

```sh
# Files with worst coverage
simplecov-mcp list | head -10

# Specific directory
simplecov-mcp list --tracked-globs "lib/simple_cov_mcp/tools/**/*.rb"

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
simplecov-mcp summary lib/simple_cov_mcp/model.rb

# See uncovered lines
simplecov-mcp uncovered lib/simple_cov_mcp/cli.rb

# View in context
simplecov-mcp uncovered lib/simple_cov_mcp/cli.rb --source=uncovered --source-context 3

# Detailed hit counts
simplecov-mcp detailed lib/simple_cov_mcp/util.rb
```

## CLI Commands

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

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for full details.

- **"command not found"** - See [Installation Guide](docs/INSTALLATION.md#path-configuration)
- **"cannot load such file -- mcp"** - Upgrade to Ruby >= 3.2
- **"Could not find .resultset.json"** - Run tests to generate coverage
- **MCP server won't connect** - Check PATH and Ruby version in [MCP Troubleshooting](docs/MCP_INTEGRATION.md#troubleshooting)

Full troubleshooting guide: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

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

## SimpleCov Independence

This gem does **not** depend on SimpleCov at runtime. It only reads the `.resultset.json` file that SimpleCov generates. As long as that file exists, simplecov-mcp can analyze it without requiring SimpleCov in your runtime environment.

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
