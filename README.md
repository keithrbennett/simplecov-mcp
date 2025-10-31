# simplecov-mcp

> MCP server + CLI + Ruby library for inspecting SimpleCov coverage data

[![Gem Version](https://badge.fury.io/rb/simplecov-mcp.svg)](https://badge.fury.io/rb/simplecov-mcp)

## What is simplecov-mcp?

**simplecov-mcp** makes SimpleCov coverage data queryable and actionable through three interfaces:

- **MCP server** - Let AI assistants analyze your coverage
- **CLI** - Fast command-line coverage reports and queries
- **Ruby library** - Programmatic API for custom tooling

Works with any SimpleCov-generated `.resultset.json` file—no runtime dependency on your test suite.

### Key capabilities

- Flexible path resolution (absolute or relative paths)
- Staleness detection (identifies outdated coverage files)
- Multi-suite resultset merging when needed
- Multiple useful output formats (tables, JSON, annotated source)

### Practical use cases

- Query coverage data from AI assistants, e.g.:
  - "Using simplecov-mcp, analyze test coverage data and write a report to a markdown file containing a free text analysis of each issue and then two tables, one sorted in descending order of urgency, the other in ascending order of level of effort."
  - "Using simplecov-mcp, generate a table of directories and their average coverage rates, in ascending order of coverage."
- Find files with the lowest coverage
- Investigate specific files or directories
- Generate CI/CD coverage reports
- Create custom pass/fail predicates for scripts and CI - use the library API or CLI JSON output to implement arbitrarily complex coverage rules beyond simple thresholds (e.g., require higher coverage for critical paths, exempt test utilities, track coverage trends)

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
- ✅ **Staleness detection** - Identify outdated coverage (missing files, timestamp mismatches, line count changes)
- ✅ **Multi-suite support** - Automatic merging of multiple test suites (RSpec + Cucumber, etc.)
- ✅ **Flexible path resolution** - Works with absolute or relative paths
- ✅ **Comprehensive error handling** - Context-aware messages for each mode
- ⚠️ **Branch coverage limitation** - Branch-level metrics are collapsed to per-line totals. Use native SimpleCov reports for branch-by-branch analysis.

## Multi-Suite Coverage Merging

### How It Works

When a `.resultset.json` file contains multiple test suites (e.g., RSpec + Cucumber), `simplecov-mcp` automatically merges them using SimpleCov's combine logic. All covered files from every suite become available to the CLI, library, and MCP tools.

**Performance:** Single-suite projects avoid loading SimpleCov at runtime. Multi-suite resultsets trigger a lazy SimpleCov load only when needed, keeping the tool fast for the simpler coverage configurations.

### Current Limitations

**Staleness checks:** When suites are merged, we keep a single "latest suite" timestamp. This matches prior behavior but may under-report stale files if only some suites were re-run after a change. A per-file timestamp refinement is planned. Until then, consider multi-suite staleness checks advisory rather than definitive.

**Multiple resultset files:** Only suites stored inside a *single* `.resultset.json` are merged automatically. If your project produces separate resultset files (e.g., different CI jobs writing `coverage/job1/.resultset.json`, `coverage/job2/.resultset.json`), you must merge them yourself before pointing `simplecov-mcp` at the combined file.

## Documentation

**Getting Started:**
- [Installation](docs/INSTALLATION.md) - Setup for different environments
- [CLI Usage](docs/CLI_USAGE.md) - Command-line reference
- [Examples](docs/EXAMPLES.md) - Common use cases

**Advanced Usage:**
- [MCP Integration](docs/MCP_INTEGRATION.md) - AI assistant configuration
- [Library API](docs/LIBRARY_API.md) - Ruby API documentation
- [Error Handling](docs/ERROR_HANDLING.md) - Error modes and exceptions

**Reference:**
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues
- [Development](docs/DEVELOPMENT.md) - Contributing guide

## Requirements

- **Ruby >= 3.2** (required by `mcp` gem dependency)
- SimpleCov-generated `.resultset.json` file
- `simplecov` gem >= 0.21
- RVM users: export your preferred ruby/gemset *before* running commands (e.g. `rvm use 3.4.5@simplecov-mcp`)

## Configuring the Resultset

`simplecov-mcp` automatically searches for `.resultset.json` in standard locations (`coverage/.resultset.json`, `.resultset.json`, `tmp/.resultset.json`). For non-standard locations:

```sh
# Command-line option (highest priority)
simplecov-mcp --resultset /path/to/your/coverage

# Environment variable (project-wide default)
export SIMPLECOV_MCP_OPTS="--resultset /path/to/your/coverage"

# MCP server configuration
# Add to your MCP client config:
# "args": ["--resultset", "/path/to/your/coverage"]
```

See [CLI Usage Guide](docs/CLI_USAGE.md#-r---resultset-path) for complete details.



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

## Commands and Tools

**CLI Subcommands:** `list`, `summary`, `uncovered`, `detailed`, `raw`, `version`

**MCP Tools:** `coverage_summary_tool`, `coverage_detailed_tool`, `coverage_raw_tool`, `uncovered_lines_tool`, `all_files_coverage_tool`, `coverage_table_tool`, `help_tool`, `version_tool`

📖 **See also:**
- [CLI Usage Guide](docs/CLI_USAGE.md) - Complete command-line reference
- [MCP Integration Guide](docs/MCP_INTEGRATION.md#available-mcp-tools) - MCP tools documentation

## Troubleshooting

- **"command not found"** - See [Installation Guide](docs/INSTALLATION.md#path-configuration)
- **"cannot load such file -- mcp"** - Upgrade to Ruby >= 3.2
- **"Could not find .resultset.json"** - Run tests to generate coverage. See the [Configuring the Resultset](#configuring-the-resultset) section for more details.
- **MCP server won't connect** - Check PATH and Ruby version in [MCP Troubleshooting](docs/MCP_INTEGRATION.md#troubleshooting)
- **Codex on macOS with RVM** - Codex's macOS sandbox disallows `/bin/ps`, which RVM needs. Use a different version manager (rbenv, chruby) or run outside the Codex environment.

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

`simplecov-mcp` declares a runtime dependency on `simplecov` (>= 0.21) to support multi-suite merging using SimpleCov's combine helpers. The dependency is lazy-loaded only when needed, ensuring fast startup for single-suite projects.

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

## Next Steps

📦 **Install:** `gem install simplecov-mcp`

📖 **Read:** [CLI Usage Guide](docs/CLI_USAGE.md) | [MCP Integration](docs/MCP_INTEGRATION.md)

🐛 **Report issues:** [GitHub Issues](https://github.com/keithrbennett/simplecov-mcp/issues)

⭐ **Star the repo** if you find it useful!
