# MCP Integration Guide

[Back to main README](../README.md)

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
- **simplecov gem >= 0.21** - Needed when a resultset contains multiple suites (loaded lazily)
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

> **Multi-suite note:** If the resultset contains several suites (e.g., `RSpec` and `Cucumber`), simplecov-mcp lazily loads the `simplecov` gem and merges them before answering coverage queries. Staleness checks currently use the newest suite’s timestamp, so treat multi-suite freshness warnings as advisory until per-file timestamps are introduced.
>
> Only suites stored in a *single* `.resultset.json` are merged automatically. If your test runs produce multiple resultset files, merge them (e.g., via `SimpleCov::ResultMerger.merge_and_store`) and point simplecov-mcp at the combined file.

> Multifile support may be added in a future version (post an issue if you want this).

### 5. Test the MCP Server

```sh
# Test manually
echo '''{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"version_tool","arguments":{}}}''' | simplecov-mcp
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
simplecov-mcp summary lib/simplecov_mcp/cli.rb
```

**Configuration (for when bug is fixed):**

Using the Claude CLI tool:

```sh
# Basic setup (if simplecov-mcp is in default PATH)
claude mcp add simplecov-mcp simplecov-mcp

# With rbenv/asdf (use absolute path)
claude mcp add simplecov-mcp /Users/yourname/.rbenv/shims/simplecov-mcp

# With RVM wrapper (recommended for stability)
rvm wrapper ruby-3.3.8 simplecov-mcp simplecov-mcp
claude mcp add simplecov-mcp /Users/yourname/.rvm/wrappers/ruby-3.3.8/simplecov-mcp

# For user-wide configuration (default is local)
claude mcp add --scope user simplecov-mcp simplecov-mcp

# For project-specific configuration
claude mcp add --scope project simplecov-mcp simplecov-mcp
```

**Verify configuration:**
```sh
# List configured MCP servers
claude mcp list

# Get server details
claude mcp get simplecov-mcp

# Remove if needed
claude mcp remove simplecov-mcp
```

**Important Notes:**
- Default scope is `local` (current project)
- Use `--scope user` for global config, `--scope project` for project-specific
- The executable path is tied to Ruby version with version managers
- If you change Ruby versions, remove and re-add the configuration

### Cursor / Codex

Using the Codex CLI:

```sh
# Basic setup (if simplecov-mcp is in default PATH)
codex mcp add simplecov-mcp --command simplecov-mcp

# With rbenv/asdf (use absolute path)
codex mcp add simplecov-mcp --command /Users/yourname/.rbenv/shims/simplecov-mcp

# With RVM wrapper (recommended for stability)
rvm wrapper ruby-3.3.8 simplecov-mcp simplecov-mcp
codex mcp add simplecov-mcp --command /Users/yourname/.rvm/wrappers/ruby-3.3.8/simplecov-mcp

# List configured servers
codex mcp list

# Show server details
codex mcp get simplecov-mcp

# Remove if needed
codex mcp remove simplecov-mcp
```

**Find your executable path:**
```sh
which simplecov-mcp
```

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
        "SIMPLECOV_MCP_OPTS": "--resultset coverage"
      }
    }
  }
}
```

**Environment variables you can set:**

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

### JSON Response Format

For tools that return structured data, `simplecov-mcp` serializes the data as a JSON string and returns it inside a `text` part of the MCP response.

**Example:**
```json
{
  "type": "text",
  "text": "{"coverage_summary":{"covered":10,"total":20,"pct":50.0}}"
}
```

**Reasoning:**
While returning JSON in a `resource` part with `mimeType: "application/json"` is more semantically correct, major MCP clients (including Google's Gemini and Anthropic's Claude) were found to not support this format, causing validation errors. They expect a `resource` part to contain a `uri`.

To ensure maximum compatibility, the decision was made to use a simple `text` part. This is a pragmatic compromise that has proven to be reliable across different clients.

**Further Reading:**
This decision was informed by discussions with multiple AI models. For more details, see these conversations:
- [Perplexity AI Discussion](https://www.perplexity.ai/search/title-resolving-a-model-contex-IfpFWU1FR5WQXQ8HcQctyg#0)
- [ChatGPT Discussion](https://chatgpt.com/share/68e4d7e1-cad4-800f-80c2-58b33bfc31cb)

### Common Parameters

All file-specific tools accept these parameters:

- `path` (required for file tools) - File path (relative or absolute)
- `root` (optional) - Project root directory (default: `.`)
- `resultset` (optional) - Path to the `.resultset.json` file. See [Configuring the Resultset](../README.md#configuring-the-resultset) for details.
- `stale` (optional) - Staleness mode: `"off"` (default) or `"error"`
- `error_mode` (optional) - Error handling: `"off"`, `"on"` (default), `"trace"`

### Tool Details

#### Per-File Tools

These tools analyze individual files. All require `path` parameter.

**`coverage_summary_tool`** - Covered/total/percentage summary
```json
{"file": "...", "summary": {"covered": 12, "total": 14, "pct": 85.71}, "stale": false}
```

**`uncovered_lines_tool`** - List uncovered line numbers
```json
{"file": "...", "uncovered": [5, 9, 12], "summary": {...}, "stale": false}
```

**`coverage_detailed_tool`** - Per-line hit counts
```json
{"file": "...", "lines": [{"line": 1, "hits": 1, "covered": true}, ...], "summary": {...}, "stale": false}
```

**`coverage_raw_tool`** - Raw SimpleCov lines array
```json
{"file": "...", "lines": [1, 0, null, 5, 2, null, 1], "stale": false}
```

#### Project-Wide Tools

**`all_files_coverage_tool`** - Coverage for all files
- Parameters: `sort_order` (`ascending`|`descending`), `tracked_globs` (array)
- Returns: `{"files": [...], "counts": {"total": N, "ok": N, "stale": N}}`

**`coverage_table_tool`** - Formatted ASCII table
- Parameters: `sort_order` (`ascending`|`descending`)
- Returns: Plain text table

#### Utility Tools

**`help_tool`** - Tool discovery (optional `query` parameter)
**`version_tool`** - Version information

## Example Prompts for AI Assistants

### Coverage Analysis

```
Using simplecov-mcp, show me a table of all files and their coverage percentages.
```

```
Using simplecov-mcp, find files with less than 80% coverage and tell me which ones to prioritize.
```

```
Using simplecov-mcp, analyze the coverage for lib/simplecov_mcp/tools/ and suggest improvements.
```

### Finding Coverage Gaps

```
Using simplecov-mcp, show me the uncovered lines in lib/simplecov_mcp/base_tool.rb and explain what they do.
```

```
Using simplecov-mcp, find the most important uncovered code in lib/simplecov_mcp/tools/coverage_detailed_tool.rb.
```

### Test Generation

```
Using simplecov-mcp, find uncovered lines in lib/simplecov_mcp/staleness_checker.rb and write RSpec tests for them.
```

```
Using simplecov-mcp, analyze coverage gaps in lib/simplecov_mcp/tools/ and generate test cases.
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
echo '''{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"version_tool","arguments":{}}}''' | simplecov-mcp

# Test summary tool
echo '''{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"coverage_summary_tool","arguments":{"path":"lib/simplecov_mcp/model.rb"}}}''' | simplecov-mcp

# Test help tool
echo '''{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"help_tool","arguments":{}}}''' | simplecov-mcp
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

The MCP server logs to `simplecov_mcp.log` in the current directory by default.

```sh
# Watch logs in real-time
tail -f simplecov_mcp.log

# View recent errors
grep ERROR simplecov_mcp.log | tail -20
```

**Configure custom log location** when adding the server:

```sh
# Claude Code
claude mcp add simplecov-mcp simplecov-mcp --log-file /var/log/simplecov.log

# Codex
codex mcp add simplecov-mcp --command simplecov-mcp --args "--log-file" --args "/var/log/simplecov.log"

# Log to stderr (Claude)
claude mcp add simplecov-mcp simplecov-mcp --log-file stderr
```

**Note:** Logging to `stdout` is not permitted in MCP mode.

## Troubleshooting

### CLI Fallback

**Important:** If the MCP server doesn't work, use CLI commands with `--json` for structured output:

```sh
simplecov-mcp summary lib/file.rb --json      # coverage_summary_tool
simplecov-mcp uncovered lib/file.rb --json    # uncovered_lines_tool
simplecov-mcp detailed lib/file.rb --json     # coverage_detailed_tool
simplecov-mcp list --json                      # all_files_coverage_tool
simplecov-mcp version --json                   # version_tool
```

See [CLI Usage](CLI_USAGE.md) for complete documentation.

### Common Issues

**Server Won't Start**
```sh
which simplecov-mcp                            # Verify executable exists
ruby -v                                         # Check Ruby >= 3.2
simplecov-mcp version                          # Test basic functionality
```

**Path Issues with Version Managers**
```sh
which simplecov-mcp                            # Use this absolute path in MCP config
# RVM: Create wrapper for stability
rvm wrapper ruby-3.3.8 simplecov-mcp simplecov-mcp
```

**Tools Not Appearing**
1. Restart AI assistant after config changes
2. Check logs: `tail -f simplecov_mcp.log`
3. Try explicit tool names in prompts
4. Verify MCP server status in assistant

**JSON-RPC Parse Errors**
- Ensure JSON is on a single line (no newlines)
- Test manually: `echo '{"jsonrpc":"2.0",...}' | simplecov-mcp`

## Advanced Configuration

### Enable Debug Logging

For troubleshooting, add error mode when configuring the server:

```sh
# Claude Code
claude mcp add simplecov-mcp simplecov-mcp --error-mode trace

# Codex
codex mcp add simplecov-mcp --command simplecov-mcp --args "--error-mode" --args "trace"

# Gemini
gemini mcp add simplecov-mcp "$(which simplecov-mcp) --error-mode trace"
```

### Project-Specific vs. Global Configuration

**Global configuration** (all projects):
- Claude: `claude mcp add --scope user simplecov-mcp ...`
- Codex: `codex mcp add` (uses global config by default)
- Gemini: `gemini mcp add` (uses global config)

**Project-specific** (one project):
- Claude: `claude mcp add --scope project simplecov-mcp ...` (default is `local`)
- Codex/Gemini: Create `.codex/config.toml` or `.gemini/config.toml` in project root (manual)

## Next Steps

- **[CLI Usage](CLI_USAGE.md)** - Alternative to MCP for direct queries
- **[Examples](EXAMPLES.md)** - Example prompts and workflows
- **[Troubleshooting](TROUBLESHOOTING.md)** - Detailed troubleshooting guide
