# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Ruby gem that provides an MCP (Model Context Protocol) server and CLI for inspecting SimpleCov coverage data. The gem can operate as both:
1. **MCP Server**: Exposes coverage tools via JSON-RPC over stdio for integration with MCP clients
2. **CLI Tool**: Command-line interface for viewing coverage reports and file-specific data

## Key Architecture

### Dual Mode Operation
The main entry point (`SimpleCovMcp.run`) automatically detects whether to run as:
- **CLI mode**: When TTY input, explicit subcommands, or `SIMPLECOV_MCP_CLI=1` env var
- **MCP server mode**: When piped input (JSON-RPC from MCP clients)

### Core Components
- **`CoverageModel`** (`lib/simple_cov_mcp/model.rb`): Core API for querying coverage data
- **`CoverageCLI`** (`lib/simple_cov_mcp/cli.rb`): CLI interface with subcommands
- **`MCPServer`** (`lib/simple_cov_mcp/mcp_server.rb`): MCP protocol server
- **Tools** (`lib/simple_cov_mcp/tools/`): Individual MCP tools for different coverage queries
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
ruby -Ilib exe/simplecov-mcp

# Test MCP server (single-line JSON-RPC)
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"coverage_summary_tool","arguments":{"path":"lib/simple_cov_mcp.rb"}}}' | ruby -Ilib exe/simplecov-mcp
 
# Discover available tools before issuing a request
echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"help_tool","arguments":{}}}' | ruby -Ilib exe/simplecov-mcp
```

### Building
```bash
gem build simplecov-mcp.gemspec     # Build gem
gem install simplecov-mcp-*.gem     # Install locally
```

## Key Patterns

### Error Handling Strategy
The codebase uses context-aware error handling via `ErrorHandlerFactory`:
- **CLI**: User-friendly messages, exit codes, optional debug mode
- **Library**: Raises custom exceptions for programmatic handling
- **MCP Server**: Structured error responses, logging to `~/simplecov_mcp.log`

### Path Resolution
Uses a multi-strategy approach for finding files in coverage data:
1. Exact absolute path match
2. Path without working directory prefix
3. Basename (filename) matching as fallback

### Resultset Discovery
Searches for `.resultset.json` in this order:
1. Explicit `--resultset` path or `SIMPLECOV_RESULTSET` env var
2. `.resultset.json` in project root
3. `coverage/.resultset.json`
4. `tmp/.resultset.json`

## MCP Tools Available

- `coverage_raw_tool` - Original SimpleCov lines array
- `coverage_summary_tool` - Covered/total/percentage summary
- `uncovered_lines_tool` - List of uncovered line numbers
- `coverage_detailed_tool` - Per-line coverage with hit counts
- `all_files_coverage_tool` - Project-wide coverage table
- `coverage_table_tool` - Formatted coverage table
- `help_tool` - Indexed guidance on the tools above
- `version_tool` - Version information

### Prompt & Response Examples
- JSON responses are returned as `type: "resource"` with `resource.mimeType: "application/json"` and JSON in `resource.text`. Text-only outputs (table, version) remain `type: "text"`.
- **Prompt:** “What’s the coverage for `lib/simple_cov_mcp/model.rb`?” → call `coverage_summary_tool` with `{ "path": "lib/simple_cov_mcp/model.rb" }` and parse JSON from `content[0].resource.text`.
- **Prompt:** “Show uncovered lines for `spec/fixtures/project1/lib/bar.rb`.” → call `uncovered_lines_tool` with the same path.
- **Prompt:** “List files with the worst coverage.” → call `all_files_coverage_tool` (leave defaults or set `{ "sort_order": "ascending" }`).
- **Uncertain?** Call `help_tool` (optionally with `{ "query": "uncovered" }`) before proceeding.

## Testing Notes

- Run `bundle exec rspec` to generate coverage data that the tool can analyze
- The gem requires Ruby >= 3.2 due to the `mcp` dependency
- No SimpleCov runtime dependency - only reads the generated `.resultset.json` files
- Test files are in `spec/` and follow standard RSpec conventions

## Important Conventions

- Use `simple_cov_mcp` as the require path (not `simplecov_mcp` or `simple_cov/mcp`)
- All paths in the API should work with both absolute and relative forms
- The executable is `simplecov-mcp` (with hyphen)
- Error messages should be user-friendly in CLI mode, structured in MCP mode
