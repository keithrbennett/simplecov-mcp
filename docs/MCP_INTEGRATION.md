# MCP Integration Guide

This guide covers setting up simplecov-mcp as an MCP (Model Context Protocol) server for AI coding assistants.

## Table of Contents

- [What is MCP?](#what-is-mcp)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Setup by Client](#setup-by-client)
- [Available MCP Tools](#available-mcp-tools)
- [Testing Your Setup](#testing-your-setup)
- [Troubleshooting](#troubleshooting)

## What is MCP?

The Model Context Protocol (MCP) is a standard for integrating tools and data sources with AI assistants. By running simplecov-mcp as an MCP server, you enable AI coding assistants to:

- Query coverage data for files
- Identify uncovered code
- Analyze coverage gaps
- Suggest improvements based on coverage data

### Why Use MCP with Coverage Tools?

AI assistants can help you:
- **Prioritize testing** - "Which files need coverage most urgently?"
- **Understand gaps** - "Why is this file's coverage low?"
- **Generate tests** - "Write tests for uncovered lines in this file"
- **Track progress** - "Has coverage improved since last commit?"

## Prerequisites

- **Ruby >= 3.2** (required by MCP gem dependency)
- **simplecov-mcp installed** - See [Installation Guide](INSTALLATION.md)
- **Coverage data** - Run tests to generate `coverage/.resultset.json`
- **MCP-compatible client** - Claude Code, Cursor, Codex, etc.

## Quick Start

### 1. Install simplecov-mcp

```sh
gem install simplecov-mcp
```

### 2. Verify Installation

```sh
# Find the executable path (needed for MCP configuration)
which simplecov-mcp

# Test it works
simplecov-mcp version
```

### 3. Configure Your AI Assistant

See [Setup by Client](#setup-by-client) below for specific instructions.

### 4. Generate Coverage Data

```sh
# Run your test suite
bundle exec rspec  # or your test command

# Verify coverage file exists
ls coverage/.resultset.json
```

### 5. Test the MCP Server

```sh
# Test manually
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"version_tool","arguments":{}}}' | simplecov-mcp
```

You should see a JSON-RPC response with version information.

## Setup by Client

### Claude Code

**Current Status:** Claude Code has a bug in its MCP client that prevents it from working with spec-compliant MCP servers like simplecov-mcp. Claude Code will automatically fall back to using the CLI interface.

**Bug Report:** [Claude Code Issue #8239](https://github.com/anthropics/claude-code/issues/8239)

**Workaround:** Use the CLI interface, which provides the same functionality:
```sh
# Instead of MCP tools, use CLI
simplecov-mcp list
simplecov-mcp summary lib/simple_cov_mcp/cli.rb
```

**Configuration (for when bug is fixed):**

Using the Claude CLI tool:

```sh
# Basic setup (if simplecov-mcp is in default PATH)
claude mcp add simplecov-mcp -- simplecov-mcp

# With RVM (including Ruby version switching)
claude mcp add simplecov-mcp -- bash -l -c "rvm use 3.3.8 && /Users/yourname/.rvm/gems/ruby-3.3.8/bin/simplecov-mcp"

# With rbenv
claude mcp add simplecov-mcp -- /Users/yourname/.rbenv/shims/simplecov-mcp

# With asdf
claude mcp add simplecov-mcp -- /Users/yourname/.asdf/shims/simplecov-mcp

# For project-specific configuration (local scope)
claude mcp add --scope local simplecov-mcp -- simplecov-mcp
```

**Verify configuration:**
```sh
# List configured MCP servers
claude mcp list

# Remove if needed
claude mcp remove simplecov-mcp
```

**Important Notes:**
- Use `bash -l -c` wrapper if you need to set up RVM or other shell initialization
- The executable path is tied to Ruby version with version managers
- If you change Ruby versions, remove and re-add the configuration
- Use `--scope user` for global config, `--scope local` for project-specific

### Cursor / Codex

Edit your `~/.codex/config.toml` file:

```toml
[mcp_servers.simplecov-mcp]
command = "/Users/yourname/.rbenv/shims/simplecov-mcp"
# Or with RVM:
# command = "/Users/yourname/.rvm/wrappers/ruby-3.3.8/simplecov-mcp"

trust_level = "trusted"
```

**Finding the correct path:**

```sh
# For rbenv/asdf
which simplecov-mcp

# For RVM wrappers (recommended for stability)
rvm wrapper ruby-3.3.8 simplecov-mcp simplecov-mcp
# Creates stable wrapper at: ~/.rvm/wrappers/ruby-3.3.8/simplecov-mcp
```

**Restart Codex** after editing the config file.

### Gemini

Using the Gemini CLI:

```sh
# Add MCP server
gemini mcp add simplecov-mcp /Users/yourname/.rbenv/shims/simplecov-mcp

# Or with RVM
gemini mcp add simplecov-mcp /Users/yourname/.rvm/wrappers/ruby-3.3.8/simplecov-mcp

# List configured servers
gemini mcp list

# Remove if needed
gemini mcp remove simplecov-mcp
```

### Generic MCP Client

For any MCP client that uses JSON configuration:

```json
{
  "mcpServers": {
    "simplecov-mcp": {
      "command": "/path/to/simplecov-mcp",
      "args": [],
      "env": {
        "SIMPLECOV_RESULTSET": "coverage"
      }
    }
  }
}
```

**Environment variables you can set:**
- `SIMPLECOV_RESULTSET` - Path to `.resultset.json` file or directory
- `SIMPLECOV_MCP_OPTS` - Default CLI options (though less useful for MCP mode)

## Available MCP Tools

### Tool Catalog

simplecov-mcp exposes 8 MCP tools:

| Tool | Purpose | Key Parameters |
|------|---------|----------------|
| `coverage_summary_tool` | File coverage summary | `path` |
| `coverage_detailed_tool` | Per-line coverage | `path` |
| `coverage_raw_tool` | Raw SimpleCov array | `path` |
| `uncovered_lines_tool` | List uncovered lines | `path` |
| `all_files_coverage_tool` | Project-wide coverage | `sort_order`, `tracked_globs` |
| `coverage_table_tool` | Formatted coverage table | `sort_order` |
| `help_tool` | Tool discovery | `query` (optional) |
| `version_tool` | Version information | (none) |

### Common Parameters

All file-specific tools accept these parameters:

- `path` (required for file tools) - File path (relative or absolute)
- `root` (optional) - Project root directory (default: `.`)
- `resultset` (optional) - Path to `.resultset.json` or directory containing it
- `stale` (optional) - Staleness mode: `"off"` (default) or `"error"`
- `error_mode` (optional) - Error handling: `"off"`, `"on"` (default), `"on_with_trace"`

### Tool Descriptions

#### `coverage_summary_tool`

Get covered/total/percentage for a specific file.

**Input:**
```json
{
  "path": "lib/simple_cov_mcp/model.rb",
  "root": ".",
  "resultset": "coverage"
}
```

**Output:**
```json
{
  "file": "lib/simple_cov_mcp/model.rb",
  "summary": {
    "covered": 12,
    "total": 14,
    "pct": 85.71
  }
}
```

**Example prompts:**
- "What's the coverage for lib/simple_cov_mcp/tools/coverage_summary_tool.rb?"
- "Check coverage for lib/simple_cov_mcp/tools/coverage_summary_tool.rb"

#### `uncovered_lines_tool`

List line numbers that lack coverage.

**Input:**
```json
{
  "path": "lib/simple_cov_mcp/model.rb"
}
```

**Output:**
```json
{
  "file": "lib/simple_cov_mcp/model.rb",
  "uncovered": [5, 9, 12, 18],
  "summary": {
    "covered": 10,
    "total": 14,
    "pct": 71.43
  }
}
```

**Example prompts:**
- "Show uncovered lines in lib/simple_cov_mcp/tools/coverage_summary_tool.rb"
- "Which lines need coverage in lib/simple_cov_mcp/tools/uncovered_lines_tool.rb?"

#### `coverage_detailed_tool`

Get per-line coverage with hit counts.

**Input:**
```json
{
  "path": "lib/simple_cov_mcp/model.rb"
}
```

**Output:**
```json
{
  "file": "lib/simple_cov_mcp/model.rb",
  "lines": [
    { "line": 1, "hits": 1, "covered": true },
    { "line": 2, "hits": 0, "covered": false },
    { "line": 4, "hits": 5, "covered": true }
  ],
  "summary": {
    "covered": 2,
    "total": 3,
    "pct": 66.67
  }
}
```

**Example prompts:**
- "Show detailed coverage for lib/simple_cov_mcp/model.rb"
- "How many times was each line executed in lib/simple_cov_mcp/staleness_checker.rb?"

#### `coverage_raw_tool`

Get the raw SimpleCov lines array.

**Input:**
```json
{
  "path": "lib/simple_cov_mcp/model.rb"
}
```

**Output:**
```json
{
  "file": "lib/simple_cov_mcp/model.rb",
  "lines": [1, 0, null, 5, 2, null, 1]
}
```

**Example prompts:**
- "Get raw coverage data for lib/simple_cov_mcp/model.rb"

#### `all_files_coverage_tool`

Get coverage for all files in the project.

**Input:**
```json
{
  "root": ".",
  "sort_order": "ascending",
  "tracked_globs": ["lib/simple_cov_mcp/**/*.rb"]
}
```

**Output:**
```json
{
  "files": [
    {
      "file": "lib/simple_cov_mcp/util.rb",
      "covered": 8,
      "total": 10,
      "percentage": 80.0,
      "stale": false
    },
    {
      "file": "lib/simple_cov_mcp/errors.rb",
      "covered": 12,
      "total": 12,
      "percentage": 100.0,
      "stale": false
    }
  ],
  "counts": {
    "total": 2,
    "ok": 2,
    "stale": 0
  }
}
```

**Example prompts:**
- "List all files with their coverage"
- "Show files with the worst coverage"
- "Which files have less than 80% coverage?"

#### `coverage_table_tool`

Get a formatted text table of coverage.

**Input:**
```json
{
  "sort_order": "ascending"
}
```

**Output:** (text format)
```
┌───────────────────┬────────┬──────────┬────────┬───────┐
│ File              │      % │  Covered │  Total │ Stale │
├───────────────────┼────────┼──────────┼────────┼───────┤
│ lib/simple_cov_mcp/util.rb        │  80.00 │        8 │     10 │       │
│ lib/simple_cov_mcp/errors.rb        │ 100.00 │       12 │     12 │       │
└───────────────────┴────────┴──────────┴────────┴───────┘
```

**Example prompts:**
- "Show me a coverage table"
- "Display all files coverage in a table"

#### `help_tool`

Discover available tools and get usage guidance.

**Input:**
```json
{
  "query": "uncovered"
}
```

**Output:**
```json
{
  "tools": [
    {
      "name": "uncovered_lines_tool",
      "use_when": "When you need to know which lines...",
      "inputs": ["path", "root", "resultset"],
      "examples": ["Show uncovered lines for lib/simple_cov_mcp/util.rb"]
    }
  ]
}
```

**Example prompts:**
- "What coverage tools are available?"
- "How do I check uncovered lines?"

#### `version_tool`

Get version information.

**Input:** (none required)
```json
{}
```

**Output:** (text format)
```
SimpleCovMcp version 1.0.0
```

## Example Prompts for AI Assistants

### Coverage Analysis

```
Using simplecov-mcp, show me a table of all files and their coverage percentages.
```

```
Using simplecov-mcp, find files with less than 80% coverage and tell me which ones to prioritize.
```

```
Using simplecov-mcp, analyze the coverage for lib/simple_cov_mcp/tools/ and suggest improvements.
```

### Finding Coverage Gaps

```
Using simplecov-mcp, show me the uncovered lines in lib/simple_cov_mcp/base_tool.rb and explain what they do.
```

```
Using simplecov-mcp, find the most important uncovered code in lib/simple_cov_mcp/tools/coverage_detailed_tool.rb.
```

### Test Generation

```
Using simplecov-mcp, find uncovered lines in lib/simple_cov_mcp/staleness_checker.rb and write RSpec tests for them.
```

```
Using simplecov-mcp, analyze coverage gaps in lib/simple_cov_mcp/tools/ and generate test cases.
```

### Coverage Reporting

```
Using simplecov-mcp, create a markdown report of:
- Files with worst coverage
- Most critical coverage gaps
- Recommended action items
```

## Testing Your Setup

### Manual Testing via Command Line

Test the MCP server responds to JSON-RPC:

```sh
# Test version tool (simplest)
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"version_tool","arguments":{}}}' | simplecov-mcp

# Test summary tool
echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"coverage_summary_tool","arguments":{"path":"lib/simple_cov_mcp/model.rb"}}}' | simplecov-mcp

# Test help tool
echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"help_tool","arguments":{}}}' | simplecov-mcp
```

**Important:** JSON-RPC messages must be on a single line. Multi-line JSON will cause parse errors.

### Testing in AI Assistant

Once configured, try these prompts in your AI assistant:

1. **Basic connectivity:**
   ```
   Using simplecov-mcp, show me the version.
   ```

2. **List tools:**
   ```
   Using simplecov-mcp, what tools are available?
   ```

3. **Simple query:**
   ```
   Using simplecov-mcp, show me all files with coverage.
   ```

If these work, your setup is correct!

### Checking Logs

The MCP server logs to `~/simplecov_mcp.log` by default.

```sh
# Watch logs in real-time
tail -f ~/simplecov_mcp.log

# View recent errors
grep ERROR ~/simplecov_mcp.log | tail -20
```

You can configure a different log location:

```json
{
  "mcpServers": {
    "simplecov-mcp": {
      "command": "/path/to/simplecov-mcp",
      "args": ["--log-file", "/var/log/simplecov.log"]
    }
  }
}
```

Or disable logging:

```json
{
  "mcpServers": {
    "simplecov-mcp": {
      "command": "/path/to/simplecov-mcp",
      "args": ["--log-file", "-"]
    }
  }
}
```

## Troubleshooting

### MCP Server Won't Start

**Symptom:** AI assistant reports "Could not connect to MCP server"

**Checks:**

1. **Verify executable exists:**
   ```sh
   which simplecov-mcp
   ls -l $(which simplecov-mcp)
   ```

2. **Test manually:**
   ```sh
   simplecov-mcp version
   ```

3. **Check Ruby version:**
   ```sh
   ruby -v  # Must be >= 3.2
   ```

4. **Test MCP server mode:**
   ```sh
   echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"version_tool","arguments":{}}}' | simplecov-mcp
   ```

### Path Issues with Version Managers

**Symptom:** Works in terminal but not in MCP client

**Solution:** Use absolute path to shim/wrapper

```sh
# Find the correct path
which simplecov-mcp

# For RVM, create a wrapper
rvm wrapper ruby-3.3.8 simplecov-mcp simplecov-mcp
# Use: ~/.rvm/wrappers/ruby-3.3.8/simplecov-mcp

# Update MCP config with absolute path
```

### JSON-RPC Parse Errors

**Symptom:** "Invalid JSON-RPC format" or similar errors

**Solution:** Ensure JSON is on a single line

```sh
# Wrong (multi-line)
echo '{
  "jsonrpc": "2.0"
}' | simplecov-mcp

# Correct (single line)
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"version_tool","arguments":{}}}' | simplecov-mcp
```

### Coverage Data Not Found

**Symptom:** "Could not find .resultset.json" error

**Solutions:**

1. **Generate coverage:**
   ```sh
   bundle exec rspec
   ls coverage/.resultset.json
   ```

2. **Specify resultset location in MCP config:**
   ```json
   {
     "mcpServers": {
       "simplecov-mcp": {
         "command": "/path/to/simplecov-mcp",
         "env": {
           "SIMPLECOV_RESULTSET": "coverage/.resultset.json"
         }
       }
     }
   }
   ```

3. **Or use command-line args:**
   ```json
   {
     "mcpServers": {
       "simplecov-mcp": {
         "command": "/path/to/simplecov-mcp",
         "args": ["--resultset", "coverage"]
       }
     }
   }
   ```

### Tools Not Appearing in AI Assistant

**Symptom:** AI says "I don't have access to coverage tools"

**Checks:**

1. **Verify MCP server is running:**
   - Check AI assistant's MCP server status
   - Look for connection errors

2. **Restart AI assistant:**
   - Many clients need restart after config changes

3. **Check logs:**
   ```sh
   tail -f ~/simplecov_mcp.log
   ```

4. **Try explicit tool name:**
   ```
   Using the coverage_summary_tool, check lib/simple_cov_mcp/cli.rb
   ```

### Ruby Version Mismatch

**Symptom:** "cannot load such file -- mcp" or similar

**Solution:** Ensure Ruby >= 3.2

```sh
# Check Ruby version in MCP context
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"version_tool","arguments":{}}}' | $(which simplecov-mcp)

# If error, your shim might be pointing to wrong Ruby
# For RVM, specify version:
rvm use 3.3.8
gem install simplecov-mcp
rvm wrapper ruby-3.3.8 simplecov-mcp simplecov-mcp
```

## Advanced Configuration

### Custom Resultset Location

If your coverage is in a non-standard location:

```json
{
  "mcpServers": {
    "simplecov-mcp": {
      "command": "/path/to/simplecov-mcp",
      "env": {
        "SIMPLECOV_RESULTSET": "build/coverage/.resultset.json"
      }
    }
  }
}
```

### Enable Debug Logging

For troubleshooting:

```json
{
  "mcpServers": {
    "simplecov-mcp": {
      "command": "/path/to/simplecov-mcp",
      "args": ["--error-mode", "on_with_trace"]
    }
  }
}
```

### Project-Specific vs. Global Configuration

**Global configuration** (all projects):
- Claude: Use `--scope user` (or omit, it's default)
- Codex: Edit `~/.codex/config.toml`

**Project-specific** (one project):
- Claude: Use `--scope local`
- Codex: Create `.codex/config.toml` in project root

## Next Steps

- **[CLI Usage](CLI_USAGE.md)** - Alternative to MCP for direct queries
- **[Examples](EXAMPLES.md)** - Example prompts and workflows
- **[Troubleshooting](TROUBLESHOOTING.md)** - Detailed troubleshooting guide
