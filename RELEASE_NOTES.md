# Release Notes

## v2.0.0.pre.1 (Unreleased)

### 🚨 BREAKING CHANGE

The `--success-predicate` option has been **removed** and replaced with the `validate` subcommand.

**Migration:**
```bash
# Before
simplecov-mcp --success-predicate policy.rb

# After
simplecov-mcp validate policy.rb
```

**Why:** Subcommand architecture provides better CLI semantics, consistent with tools like git/docker, and enables inline code support via `-i` flag.

**Details:** Exit codes unchanged (0=pass, 1=fail, 2=error). See `docs/user/ADVANCED_USAGE.md` for complete usage and examples.

### ✨ New Features

- **validate subcommand**: File mode (`validate <file>`) and inline mode (`validate -i <code>`)
- **MCP support**: New `validate_tool` with `code` and `file` parameters

---

## v1.1.0

- Add a `total` CLI subcommand and matching `coverage_totals_tool` that report covered/total/uncovered line counts plus the average coverage percent.
- Refactor command line and environment argument handling

## v1.0.1 (2025-10-23)

- Make error output more helpful when a result set file is not found, esp. when the command name is run without args in a non-project directory.

## v1.0.0 (2025-10-18)

🎉 **Major Release: Production-Ready Coverage Analysis Tool**

This release represents a complete maturation of simplecov-mcp from experimental proof-of-concept to production-ready tool. The v1.0.0 milestone brings comprehensive documentation, robust error handling, extensive test coverage, architectural improvements, and a polished user experience across all three interfaces (MCP server, CLI, and Ruby library).

### 🌟 Major Features

#### Multi-Suite Coverage Merging
- **Automatic merging** of multiple test suites from a single `.resultset.json` file (e.g., RSpec + Cucumber)
- **Lazy loading** of SimpleCov dependency - only loaded when multi-suite merging is needed
- **Performance optimized** - single-suite projects remain fast with no SimpleCov runtime overhead
- See `docs/user/ADVANCED_USAGE.md` for configuration details

#### Branch Coverage Support (with Limitations)
- **Branch-level data handling** - reads and processes SimpleCov branch coverage data
- **Line-level aggregation** - branch hits are summed per line since individual branch tracking isn't supported yet
- **Graceful degradation** - use native SimpleCov HTML reports for detailed branch-by-branch analysis
- See `docs/dev/BRANCH_ONLY_COVERAGE.md` for details and limitations

#### Enhanced Staleness Detection
- **Three staleness indicators**:
  - `M` - File modified after coverage run (timestamp-based)
  - `T` - File timestamp unavailable or coverage missing
  - `L` - Line count mismatch between source and coverage
- **Per-file reporting** in all outputs (CLI tables, JSON, MCP responses)
- **Configurable modes**: `--stale off|error` for CI/CD integration
- Improved edge case handling for files outside project root

#### Success Predicates for CI/CD
- **Custom exit code logic** via `--success-predicate` flag
- **Ruby code evaluation** - Load lambdas or other callable objects to define coverage policies
- **Flexible policy definitions** - Check minimum thresholds, file-based rules, directory-specific requirements, etc.
- **Examples provided** in `examples/success_predicates/`:
  - Project-wide minimum coverage
  - Per-directory thresholds
  - Class-based policies
  - Maximum low-coverage file count
- See `docs/user/ADVANCED_USAGE.md#success-predicates` for usage and security considerations

#### Comprehensive CLI Enhancements
- **Default command improved** - `simplecov-mcp` shows sorted coverage table (no subcommand needed)
- **Flexible sorting** - `--sort-order a|d` or `--sort-order ascending|descending`
- **Annotated source code** - `--source=full|uncovered` with `--source-context N` for context lines
- **Optional colorization** - `--color/--no-color` for source code output
- **Tracked globs** - `--tracked-globs PATTERN` to filter files or detect new untested files
- **User-specified defaults via environment variable** - `SIMPLECOV_MCP_OPTS` environment variable value is prepended to ARGV for option parsing
- **Configurable logging** - `--log-file PATH` or `stdout`/`stderr` (default: `./simplecov_mcp.log`)

### 🏗️ Architecture & Code Quality

#### Major Refactoring
- **Command pattern** - CLI subcommands extracted to individual command classes (`lib/simplecov_mcp/commands/`)
- **Presenter pattern** - Shared presentation logic for all output formats (`lib/simplecov_mcp/presenters/`)
- **Resolver pattern** - Path and coverage line resolution extracted to dedicated classes (`lib/simplecov_mcp/resolvers/`)
- **Factory pattern** - Error handlers and command instantiation centralized
- **Shared test examples** - DRY test suite with shared behaviors documented in `spec/shared_examples/README.md`

#### Error Handling Overhaul
- **Context-aware errors** - Different error strategies for CLI, library, and MCP server modes
- **Three error modes**: `off`, `on`, `trace` (configurable via `--error-mode` or `SIMPLECOV_MCP_OPTS`)
- **Custom exception hierarchy** - `SimpleCovMcp::Error` base class with specific subtypes
- **Logging fallback** - Graceful degradation to stderr when log file is unavailable (CLI/library modes only)
- **Structured MCP errors** - JSON-RPC compliant error responses with proper error codes
- See `docs/user/ERROR_HANDLING.md` for complete reference

#### Improved Path Resolution
- **Multi-strategy matching**:
  1. Exact absolute path
  2. Path without working directory prefix
  3. Basename (filename) fallback
- **New `PathRelativizer` class** - Consistent relative path handling across codebase
- **Configurable root** - `--root PATH` option to resolve relative paths against different directories

#### Test Coverage Excellence
- **Comprehensive test suite** - 546 examples across 55 test files
- **High coverage** - 98.49% line coverage, 90.36% branch coverage (self-reported via SimpleCov)
- **Integration tests** - Real-world scenarios in `spec/integration_spec.rb`
- **MCP integration tests** - JSON-RPC protocol validation in `spec/mcp_server_integration_spec.rb`
- **Edge case testing** - Exhaustive error condition coverage in `spec/errors_edge_cases_spec.rb`
- **Test documentation** - `spec/MCP_INTEGRATION_TESTS_README.md` and `spec/TIMESTAMPS.md`

### 📚 Documentation Overhaul

#### Comprehensive Documentation Suite
All documentation moved under audience-specific directories (`docs/user` for usage guides, `docs/dev` for contributor content):

**Getting Started:**
- `docs/user/INSTALLATION.md` - Installation for all environments (gem, Bundler, source, RVM, rbenv, etc.)
- `docs/user/CLI_USAGE.md` - Complete command-line reference with examples
- `docs/user/EXAMPLES.md` - Common use cases and workflows

**Advanced Usage:**
- `docs/user/ADVANCED_USAGE.md` - Success predicates, multi-suite merging, resultset configuration
- `docs/user/MCP_INTEGRATION.md` - AI assistant setup (Claude Code, Cursor, Zed, etc.)
- `docs/user/LIBRARY_API.md` - Complete Ruby API documentation with recipes

**Reference:**
- `docs/user/ERROR_HANDLING.md` - Error modes, exception types, logging
- `docs/user/TROUBLESHOOTING.md` - Common issues and solutions
- `docs/dev/ARCHITECTURE.md` - System design and component overview
- `docs/dev/DEVELOPMENT.md` - Contributing guide
- `docs/dev/BRANCH_ONLY_COVERAGE.md` - Branch coverage support and limitations

**Architectural Decisions:**
- `docs/dev/arch-decisions/*.md` - 5 detailed ADRs documenting major design decisions
- `docs/dev/arch-decisions/README.md` - Index and overview

**Additional Resources:**
- `docs/dev/presentations/simplecov-mcp-presentation.md` - Slide deck for talks/demos
- `examples/success_predicates/README.md` - Success predicate examples and patterns
- `prompts/*.md` - AI prompt templates for coverage analysis

#### Improved README
- **Value proposition first** - Clear explanation of what simplecov-mcp does and why it matters
- **Quick Start section** - Get running in 3 steps
- **Audience-based organization** - Documentation grouped by user journey (Getting Started, Advanced, Reference)
- **Next Steps section** - Clear calls-to-action at end
- **Reduced length** - Main README streamlined from 967 lines to 272 lines by extracting content to dedicated docs

### 🔧 Developer Experience

#### Configuration Improvements
- **Environment variable options** - `SIMPLECOV_MCP_OPTS` prepended to ARGV for option parsing
- **Force CLI mode** - `--force-cli` flag to disable MCP server mode detection
- **Flexible resultset location** - Multiple resolution strategies with sensible defaults
- **Normalized options** - Consistent internal representation of enumerated options (symbols)

#### Logging Enhancements
- **Configurable log file** - `--log-file PATH` (or `-l`) command-line option
- **Programmatic control** - `SimpleCovMcp.default_log_file=` and `SimpleCovMcp.active_log_file=` for runtime changes
- **Mode-aware logging** - MCP mode prohibits `stdout` logging (would corrupt JSON-RPC protocol), allows `stderr` or file
- **Timestamped log entries** - All log messages include ISO 8601 timestamps

#### Build & Release
- **Dependabot integration** - Automated dependency updates (`.github/dependabot.yml`)
- **License added** - MIT License (`LICENSE` file)
- **Gemspec improvements** - Tighter version constraints, correct file list
- **Version command** - `simplecov-mcp version` for easy version checking

### 🐛 Bug Fixes

#### CLI Fixes
- **Subcommand extraction** - Fixed `--source` flag incorrectly treated as subcommand (lib/simplecov_mcp/constants.rb:9-19)
- **Option argument parsing** - Centralized list of options expecting arguments to prevent similar bugs
- **Invalid option handling** - Clean error messages for unrecognized CLI flags
- **Help text formatting** - Improved readability and consistency

#### Path Resolution Fixes
- **Double-path bug** - Fixed resultset resolver creating invalid paths like `spec/fixtures/project1/spec/fixtures/project1/coverage`
- **Relative path handling** - Stopped indiscriminately running `File.absolute_path(resultset, @root)` on already-absolute paths
- **Files outside root** - Graceful handling of coverage data for files outside project root directory

#### Coverage Processing Fixes
- **Branch-only coverage** - No longer crashes on resultsets with branch data but no line data
- **String timestamps** - Handles both integer and string timestamps in resultset JSON
- **Multiple resultsets** - Proper merging when `.resultset.json` contains multiple test suite entries
- **Line count mismatches** - Accurate staleness detection handles trailing newline differences between source and coverage data

#### Error Handling Fixes
- **Library mode exceptions** - Consistent `SimpleCovMcp::Error` exceptions (not bare `RuntimeError`)
- **MCP error format** - JSON-RPC compliant error responses
- **Missing resultset** - Clear error messages with actionable suggestions
- **Fallback logging** - stderr logging when primary log destination is unavailable (not in MCP mode)

### 🔄 Breaking Changes

#### Naming Consistency
- **Module name** - Now consistently `SimpleCovMcp` (matching SimpleCov's single-word style)
- **Legacy shim removed** - `SimpleCov::Mcp` entry point no longer supported
- **Require path** - Changed from `simple_cov/mcp` to `simplecov_mcp`
- **File paths** - All files moved from `lib/simple_cov_mcp/` to `lib/simplecov_mcp/`

#### Option Changes
- **Removed environment variables**: `SIMPLECOV_RESULTSET`, `SIMPLECOV_MCP_CLI`, `SIMPLECOV_MCP_DEBUG`, `SIMPLECOV_MCP_LOG`
- **New environment variable**: `SIMPLECOV_MCP_OPTS` - use this instead (supports all CLI options including `--log-file`)
- **CLI flag removed**: `--cli` (replaced by `--force-cli`)
- **Error mode enum**: Changed from `--debug` to `--error-mode trace|on|off`
- **Subcommand changes**: `table` and `all-files` subcommands merged into `list`

#### API Changes
- **CoverageModel constructor** - Options now use consistent symbol keys (not mixed strings/symbols)
- **Staleness return values** - Changed from boolean to letter codes (`'M'`, `'T'`, `'L'`, or `false`)
- **Error classes** - Custom exception hierarchy replaces generic `RuntimeError`

### 📊 Statistics

- **175 files changed** with 15,712 insertions and 2,142 deletions
- **152 commits** since v0.3.0
- **Comprehensive documentation** - 12 major documentation files in `docs/`, 5 ADRs, 7 example scripts
- **Test coverage** - Self-reported coverage via SimpleCov (view with `simplecov-mcp list`)

### 🙏 Acknowledgments

This release benefited from extensive AI pair programming sessions with Codex, Claude Code, GLM-4.6 (Z-AI), Gemini, and Warp.

See `CLAUDE.md`, `AGENTS.md`, and `GEMINI.md` for AI agent integration notes.

### 📦 Upgrade Guide

#### From v0.3.0

1. **Update require statements:**
   ```ruby
   # Old
   require 'simple_cov/mcp'

   # New
   require 'simplecov_mcp'
   ```

2. **Update environment variables:**
   ```sh
   # Old
   export SIMPLECOV_RESULTSET=/path/to/coverage
   export SIMPLECOV_MCP_DEBUG=1

   # New
   export SIMPLECOV_MCP_OPTS="--resultset /path/to/coverage --error-mode trace"
   ```

3. **Update CLI commands:**
   ```sh
   # Old
   simplecov-mcp table
   simplecov-mcp all-files

   # New (merged into 'list')
   simplecov-mcp list
   simplecov-mcp        # default command is 'list'
   ```

4. **Update MCP configurations:**
   - Review `docs/user/MCP_INTEGRATION.md` for updated setup instructions
   - Log file now defaults to `./simplecov_mcp.log` (was `~/simplecov_mcp.log`)

5. **Handle new error types in library code:**
   ```ruby
   # Old
   rescue RuntimeError => e

   # New
   rescue SimpleCovMcp::FileError => e
   rescue SimpleCovMcp::ConfigurationError => e
   rescue SimpleCovMcp::Error => e  # catch-all
   ```

### 🔮 Possible Future Improvements

- **Per-file staleness timestamps** in multi-suite scenarios
- **Multiple resultset file merging** (currently only merges suites within single file)
- **Full branch coverage support** with individual branch tracking
- **Web interface** for interactive coverage exploration
- **Additional output formats** (HTML reports, badges, etc.)

### 🔗 Links

- **Changelog:** [RELEASE_NOTES.md](RELEASE_NOTES.md)
- **GitHub:** https://github.com/keithrbennett/simplecov-mcp
- **RubyGems:** https://rubygems.org/gems/simplecov-mcp
- **Issues:** https://github.com/keithrbennett/simplecov-mcp/issues

---

**Full Changelog**: v0.3.0...v1.0.0

---

## v0.2.1

* Fixed JSON data key issue and resulting test failure.

## v0.2.0

* Massive enhancements and improvements.

## v0.1.0

* Initial version.
