# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Ruby gem that provides an MCP (Model Context Protocol) server and CLI for inspecting SimpleCov coverage data. The gem can operate as both:
1. **MCP Server**: Exposes coverage tools via JSON-RPC over stdio for integration with MCP clients
2. **CLI Tool**: Command-line interface for viewing coverage reports and file-specific data

## Key Architecture

### Dual Mode Operation
The main entry point (`CovLoupe.run`) automatically detects whether to run as:
- **CLI mode**: When TTY input or explicit subcommands are provided
- **MCP server mode**: When piped input (JSON-RPC from MCP clients)

### Core Components
- **`CoverageModel`** (`lib/cov_loupe/model.rb`): Core API for querying coverage data
- **`CoverageCLI`** (`lib/cov_loupe/cli.rb`): CLI interface with subcommands
- **`MCPServer`** (`lib/cov_loupe/mcp_server.rb`): MCP protocol server
- **Tools** (`lib/cov_loupe/tools/`): Individual MCP tools for different coverage queries
- **Error Handling**: Context-aware error handling for CLI vs library vs MCP server usage

### Coverage Data Flow
1. Reads SimpleCov `.resultset.json` files (no runtime dependency on SimpleCov)
2. Resolves file paths using multiple strategies (absolute, relative, basename matching)
3. Provides coverage data in multiple formats: raw arrays, summaries, detailed per-line, uncovered lines

## Development Commands

### Setup
```bash
bundle install
```

### Testing
```bash
bundle exec rspec                    # Run all tests
bundle exec rspec spec/path_spec.rb  # Run specific test file
```
Tests generate coverage data to `coverage/.resultset.json` which the tool can then analyze.

### Manual Testing
```bash
# Test CLI locally during development
bundle exec exe/cov-loupe

# Test MCP server (JSON-RPC on a single line; pipe to jq for pretty output)
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"coverage_summary_tool","arguments":{"path":"lib/simple_cov_mcp.rb"}}}' | bundle exec exe/cov-loupe
 
# Discover available tools before issuing a request
echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"help_tool","arguments":{}}}' | bundle exec exe/cov-loupe
```

### Building
```bash
gem build cov-loupe.gemspec     # Build gem
gem install cov-loupe-*.gem     # Install locally
```

## Key Patterns

### Error Handling Strategy
The codebase uses context-aware error handling via `ErrorHandlerFactory`:
- **CLI**: User-friendly messages, exit codes, optional debug mode
- **Library**: Raises custom exceptions for programmatic handling
- **MCP Server**: Structured error responses, logging to `./cov_loupe.log`

### Path Resolution
Uses a multi-strategy approach for finding files in coverage data:
1. Exact absolute path match
2. Path without working directory prefix
3. Basename (filename) matching as fallback

### Resultset Discovery

The tool locates the `.resultset.json` file by checking a series of default paths or by using a path specified by the user. For a detailed explanation of the configuration options, see the [Configuring the Resultset](README.md#configuring-the-resultset) section in the main README.

## MCP Tools Available

- `coverage_raw_tool` - Original SimpleCov lines array
- `coverage_summary_tool` - Covered/total/percentage summary
- `uncovered_lines_tool` - List of uncovered line numbers
- `coverage_detailed_tool` - Per-line coverage with hit counts
- `all_files_coverage_tool` - Project-wide coverage table
- `coverage_totals_tool` - Aggregated line totals across project
- `coverage_table_tool` - Formatted coverage table
- `validate_tool` - Validate coverage against custom policies (Ruby predicates)
- `help_tool` - Indexed guidance on the tools above
- `version_tool` - Version information

### Prompt & Response Examples
- All responses are returned as `type: "text"` with content in `text`. JSON responses contain a JSON string that should be parsed. This format ensures maximum compatibility with MCP clients.
- **Prompt:** "What's the coverage for `lib/cov_loupe/model.rb`?" → call `coverage_summary_tool` with `{ "path": "lib/cov_loupe/model.rb" }` and parse JSON from `content[0].text`.
- **Prompt:** “Show uncovered lines for `spec/fixtures/project1/lib/bar.rb`.” → call `uncovered_lines_tool` with the same path.
- **Prompt:** “List files with the worst coverage.” → call `all_files_coverage_tool` (leave defaults or set `{ "sort_order": "ascending" }`).
- **Uncertain?** Call `help_tool` before proceeding.

## Testing Notes

- Run `bundle exec rspec` to generate coverage data that the tool can analyze
- The gem requires Ruby >= 3.2 due to the `mcp` dependency
- SimpleCov is a lazy-loaded runtime dependency - only loaded when multi-suite resultsets need merging
- Test files are in `spec/` and follow standard RSpec conventions

## Documentation

- **README.md** - Main documentation in the project root
- **docs/user/** - User-facing documentation (installation, CLI usage, MCP integration, troubleshooting, examples, etc.)
- **docs/dev/** - Developer documentation (architecture, decisions, contributing)

## Important Conventions

- Use `cov_loupe` as the require path (matches the gem name SimpleCov)
- All paths in the API should work with both absolute and relative forms
- The executable is `cov-loupe` (with hyphen)
- Error messages should be user-friendly in CLI mode, structured in MCP mode
