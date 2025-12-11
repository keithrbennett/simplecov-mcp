<!-- Invisible SEO-friendly H1 -->
<h1 style="position:absolute; left:-9999px; top:auto; width:1px; height:1px; overflow:hidden;">
  CovLoupe
</h1>

<p style="text-align:center; margin-bottom:-36px;">
  <img src="dev/images/cov-loupe-logo.png" alt="CovLoupe logo" width="560">
</p>

<p style="text-align:center;">
  An MCP server, command line utility, and library for Ruby SimpleCov test coverage analysis.


[![Gem Version](https://badge.fury.io/rb/cov-loupe.svg)](https://badge.fury.io/rb/cov-loupe)

## What is cov-loupe?

**cov-loupe** makes SimpleCov coverage data queryable and actionable through three interfaces:

- **MCP server** - Lets AI assistants analyze your coverage
- **CLI** - Fast command-line coverage reports and queries
- **Ruby library** - Programmatic API for custom tooling

Works with any SimpleCov-generated `.resultset.json` file—no runtime dependency on your test suite.

### Key Features

- ✅ **Multiple interfaces** - MCP server, CLI, and Ruby API
- **Annotated source code** - `-s full|uncovered` / `--source full|uncovered` with `-c N` / `--context-lines N` for context lines
- ✅ **Staleness detection** - Identify outdated coverage (missing files, timestamp mismatches, line count changes)
- ✅ **Multi-suite support** - Automatic merging of multiple test suites (RSpec + Cucumber, etc.)
- ✅ **Flexible path resolution** - Works with absolute or relative paths
- ✅ **Comprehensive error handling** - Context-aware messages for each mode
- ⚠️ **Branch coverage limitation** - Branch-level metrics are collapsed to per-line totals. Use native SimpleCov reports for branch-by-branch analysis.

### Practical Use Cases

- Query coverage data from AI assistants, e.g.:
  - "Using cov-loupe, analyze test coverage data and write a report to a markdown file containing a free text analysis of each issue and then two tables, one sorted in descending order of urgency, the other in ascending order of level of effort."
  - "Using cov-loupe, generate a table of directories and their average coverage rates, in ascending order of coverage."
- Find files with the lowest coverage
- Investigate specific files or directories
- Generate CI/CD coverage reports
- Create custom pass/fail predicates for scripts and CI - use the library API or CLI JSON output to implement arbitrarily complex coverage rules beyond simple thresholds (e.g., require higher coverage for critical paths, exempt test utilities, track coverage trends)

## Quick Start

### Installation

```sh
gem install cov-loupe
```

### Generate Coverage Data

```sh
# Run your tests with SimpleCov enabled
bundle exec rspec  # or your test command

# Verify coverage was generated
ls -l coverage/.resultset.json
```

### Basic Usage

**CLI - View Coverage Table:**
```sh
cov-loupe
```

**CLI - Check Specific File:**
```sh
cov-loupe summary lib/cov_loupe/model.rb
cov-loupe uncovered lib/cov_loupe/cli.rb
```

**CLI - Find the Project Homepage Fast:**
Run `cov-loupe -h` and the banner's second line shows the repository URL. Some terminal applications (e.g. iTerm2) will enable direct clicking the link using modifier keys such as `Cmd` or `Alt`.
```
Usage:      cov-loupe [options] [subcommand] [args]
Repository: https://github.com/keithrbennett/cov-loupe  # <--- Project URL ---
```

**Ruby Library:**
```ruby
require "cov_loupe"

model = CovLoupe::CoverageModel.new
files = model.all_files
# => [{ "file" => "lib/cov_loupe/model.rb", "covered" => 114, "total" => 118, "percentage" => 96.61, "stale" => false }, ...]

summary = model.summary_for("lib/cov_loupe/model.rb")
# => { "file" => "lib/cov_loupe/model.rb", "summary" => { "covered" => 114, "total" => 118, "percentage" => 96.61 }, "stale" => false }
```

**MCP Server:**
See [MCP Integration Guide](docs/user/MCP_INTEGRATION.md) for AI assistant setup.

## Multi-Suite Coverage Merging

### How It Works

When a `.resultset.json` file contains multiple test suites (e.g., RSpec + Cucumber), `cov-loupe` automatically merges them using SimpleCov's combine logic. All covered files from every suite become available to the CLI, library, and MCP tools.

**Performance:** Single-suite projects avoid loading SimpleCov at runtime. Multi-suite resultsets trigger a lazy SimpleCov load only when needed, keeping the tool fast for the simpler coverage configurations.

### Current Limitations

**Staleness checks:** When suites are merged, we keep a single "latest suite" timestamp. This matches prior behavior but may under-report stale files if only some suites were re-run after a change. A per-file timestamp refinement is planned. Until then, consider multi-suite staleness checks advisory rather than definitive.

**Multiple resultset files:** Only suites stored inside a *single* `.resultset.json` are merged automatically. If your project produces separate resultset files (e.g., different CI jobs writing `coverage/job1/.resultset.json`, `coverage/job2/.resultset.json`), you must merge them yourself before pointing `cov-loupe` at the combined file.

## Documentation

**Getting Started:**
- [Installation](docs/user/INSTALLATION.md) - Setup for different environments
- [CLI Usage](docs/user/CLI_USAGE.md) - Command-line reference
- [Examples](docs/user/EXAMPLES.md) - Common use cases

**Advanced Usage:**
- [MCP Integration](docs/user/MCP_INTEGRATION.md) - AI assistant configuration
- [CLI Fallback for LLMs](docs/user/CLI_FALLBACK_FOR_LLMS.md) - Using CLI when MCP isn't available
- [Library API](docs/user/LIBRARY_API.md) - Ruby API documentation
- [Advanced Usage](docs/user/ADVANCED_USAGE.md) - Staleness detection, error modes, path resolution
- [Error Handling](docs/user/ERROR_HANDLING.md) - Error modes and exceptions

**Reference:**
- [Architecture](docs/dev/ARCHITECTURE.md) - Design and internals
- [Branch Coverage](docs/dev/BRANCH_ONLY_COVERAGE.md) - Branch coverage limitations
- [Troubleshooting](docs/user/TROUBLESHOOTING.md) - Common issues
- [Development](docs/dev/DEVELOPMENT.md) - Contributing guide

## Requirements

- **Ruby >= 3.2** (required by `mcp` gem dependency)
- SimpleCov-generated `.resultset.json` file
- `simplecov` gem >= 0.21

## Configuring the Resultset

`cov-loupe` automatically searches for `.resultset.json` in standard locations (`coverage/.resultset.json`, `.resultset.json`, `tmp/.resultset.json`). For non-standard locations:

```sh
# Command-line option (highest priority) - use -r or --resultset
cov-loupe -r /path/to/your/coverage

# Environment variable (project-wide default)
export COV_LOUPE_OPTS="-r /path/to/your/coverage"

# MCP server configuration
# Add to your MCP client config (used as defaults for MCP tools):
# "args": ["-r", "/path/to/your/coverage"]
```

**MCP precedence:** For MCP tool calls, per-request JSON parameters win over the CLI args used to start the server (including `COV_LOUPE_OPTS`). If neither is provided, built-in defaults are used (`root: '.'`, `raise_on_stale: false`, etc.).

See [CLI Usage Guide](docs/user/CLI_USAGE.md#-r---resultset-path) for complete details.



## Common Workflows

### Find Coverage Gaps

```sh
# Files with worst coverage
cov-loupe -o d list           # -o = --sort-order, d = descending (worst at end)
cov-loupe list | less         # display table in pager, worst files first
cov-loupe list | head -10     # truncate the table

# Specific directory
cov-loupe -g "lib/cov_loupe/tools/**/*.rb" list  # -g = --tracked-globs

# Export for analysis
cov-loupe -fJ list > coverage-report.json
```

### Working with JSON Output

The `-fJ` flag enables programmatic processing of coverage data using command-line JSON tools.

**Using jq:**
```sh
# Filter files below 80% coverage
cov-loupe -fJ list | jq '.files[] | select(.percentage < 80)'
```

**Using Ruby one-liners:**
```sh
# Count files below threshold
cov-loupe -fJ list | ruby -r json -e '
  puts JSON.parse($stdin.read)["files"].count { |f| f["percentage"] < 80 }
'
```

**Using rexe:**

[rexe](https://github.com/keithrbennett/rexe) is a Ruby gem that enables shorter Ruby command lines by providing command-line options for input and output formats, plus other conveniences. It eliminates the need for explicit JSON parsing and formatting code.

Install: `gem install rexe`

```sh
# Filter files below 80% coverage with pretty-printed JSON output
cov-loupe -fJ list | rexe -ij -mb -oJ 'self["files"].select { |f| f["percentage"] < 80 }'

# Count files below threshold
cov-loupe -fJ list | rexe -ij -mb -op 'self["files"].count { |f| f["percentage"] < 80 }'

# Human-readable output with AwesomePrint
cov-loupe -fJ list | rexe -ij -mb -oa 'self["files"].first(3)'
```

With rexe's `-ij -mb` options, `self` automatically becomes the parsed JSON object. The same holds true for JSON output -- using `-oJ` produces pretty-printed JSON without explicit formatting calls. Rexe also supports YAML input/output (`-iy`, `-oy`) and AwesomePrint output (`-oa`) for human consumption.

Run `rexe -h` to see all available options, or visit the [rexe project page](https://github.com/keithrbennett/rexe) for more examples.

For comprehensive JSON processing examples, see [docs/user/EXAMPLES.md](docs/user/EXAMPLES.md).

### CI/CD Integration

```sh
# Fail build if coverage is stale (--raise-on-stale or -S)
cov-loupe --raise-on-stale list || exit 1

# Generate coverage report artifact
cov-loupe -fJ list > artifacts/coverage.json
```

### Investigate Specific Files

```sh
# Quick summary
cov-loupe summary lib/cov_loupe/model.rb

# See uncovered lines
cov-loupe uncovered lib/cov_loupe/cli.rb

# View in context
cov-loupe -s u -c 3 uncovered lib/cov_loupe/cli.rb  # -s = --source (u = uncovered), -c = --context-lines

# Detailed hit counts
cov-loupe detailed lib/cov_loupe/util.rb

# Project totals
cov-loupe totals
cov-loupe -fJ totals
```

## Commands and Tools

**CLI Subcommands:** `list`, `summary`, `uncovered`, `detailed`, `raw`, `totals`, `validate`, `version`

**MCP Tools:** `coverage_summary_tool`, `coverage_detailed_tool`, `coverage_raw_tool`, `uncovered_lines_tool`, `all_files_coverage_tool`, `coverage_totals_tool`, `coverage_table_tool`, `validate_tool`, `help_tool`, `version_tool`

📖 **See also:**
- [CLI Usage Guide](docs/user/CLI_USAGE.md) - Complete command-line reference
- [MCP Integration Guide](docs/user/MCP_INTEGRATION.md#available-mcp-tools) - MCP tools documentation

## Troubleshooting

- **"command not found"** - See [Installation Guide](docs/user/INSTALLATION.md#path-configuration)
- **"cannot load such file -- mcp"** - Requires Ruby >= 3.2. Verify: `ruby -v`
- **"Could not find .resultset.json"** - Ensure SimpleCov is configured in your test suite, then run tests to generate coverage. See the [Configuring the Resultset](#configuring-the-resultset) section for more details.
- **MCP server won't connect** - Check PATH and Ruby version in [MCP Troubleshooting](docs/user/MCP_INTEGRATION.md#troubleshooting)
- **RVM in sandboxed environments (macOS)** - RVM requires `/bin/ps` which may be blocked by sandbox restrictions. Use rbenv or chruby instead.

For more detailed help, see the full [Troubleshooting Guide](docs/user/TROUBLESHOOTING.md).

## Development

```sh
# Clone and setup
git clone https://github.com/keithrbennett/cov-loupe.git
cd cov-loupe
bundle install

# Run tests
bundle exec rspec

# Test locally
bundle exec exe/cov-loupe

# Build and install
gem build cov-loupe.gemspec
gem install cov-loupe-*.gem
```

See [docs/dev/DEVELOPMENT.md](docs/dev/DEVELOPMENT.md) for more.

## SimpleCov Dependency

`cov-loupe` declares a runtime dependency on `simplecov` (>= 0.21) to support multi-suite merging using SimpleCov's combine helpers. The dependency is lazy-loaded only when needed, ensuring fast startup for single-suite projects.

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

- **GitHub:** https://github.com/keithrbennett/cov-loupe
- **RubyGems:** https://rubygems.org/gems/cov-loupe
- **Issues:** https://github.com/keithrbennett/cov-loupe/issues
- **Changelog:** [RELEASE_NOTES.md](RELEASE_NOTES.md)

## Related Files

- [CLAUDE.md](CLAUDE.md) - Claude Code integration notes
- [AGENTS.md](AGENTS.md) - AI agent configuration
- [GEMINI.md](GEMINI.md) - Gemini-specific guidance

---

## Next Steps

📦 **Install:** `gem install cov-loupe`

📖 **Read:** [CLI Usage Guide](docs/user/CLI_USAGE.md) | [MCP Integration](docs/user/MCP_INTEGRATION.md)

🐛 **Report issues:** [GitHub Issues](https://github.com/keithrbennett/cov-loupe/issues)

⭐ **Star the repo** if you find it useful!
