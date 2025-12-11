# MCP Integration Guide

[Back to main README](../README.md)

## Table of Contents

- [Setup by Client](#setup-by-client)
- [Available MCP Tools](#available-mcp-tools)
- [Testing Your Setup](#testing-your-setup)
- [Troubleshooting](#troubleshooting)

## Setup by Client

For the `mcp add` commands, the last argument is the executable path.
If the executable cannot be correctly found in the path, then you can specify the full path.

Ruby version managers may modify the path to include the current version's executable directory.
If you change Ruby versions, you may need to restart your AI agent to inherit the new path.
Alternatively, remove and re-add the MCP server with an absolute path to the executable.

### Claude Code

```sh
# Add the MCP server; equivalent to ...--scope local...
claude mcp add cov-loupe cov-loupe

# For user-wide configuration
claude mcp add --scope user cov-loupe cov-loupe

# For project-specific configuration.
claude mcp add --scope project cov-loupe cov-loupe

# List configured MCP servers
claude mcp list

# Get server details
claude mcp get cov-loupe

# Remove if needed
claude mcp remove cov-loupe
```

### Codex

Using the Codex CLI:

```sh
# Add the MCP server
codex mcp add cov-loupe cov-loupe

# List configured servers
codex mcp list

# Show server details
codex mcp get cov-loupe

# Remove if needed
codex mcp remove cov-loupe
```

### Gemini

Using the Gemini CLI:

```sh
# Add the MCP server
gemini mcp add cov-loupe cov-loupe

# List configured servers
gemini mcp list

# Remove if needed
gemini mcp remove cov-loupe
```


**Environment variables you can set:**

- `COV_LOUPE_OPTS` - Default CLI options (though less useful for MCP mode)

## Available MCP Tools (Functions)

### Tool Catalog

cov-loupe exposes 10 MCP tools:

| Tool | Purpose | Key Parameters |
|------|---------|----------------|
| `coverage_summary_tool` | File coverage summary | `path` |
| `coverage_detailed_tool` | Per-line coverage | `path` |
| `coverage_raw_tool` | Raw SimpleCov array | `path` |
| `uncovered_lines_tool` | List uncovered lines | `path` |
| `all_files_coverage_tool` | Project-wide coverage | `sort_order`, `tracked_globs` |
| `coverage_totals_tool` | Aggregated line totals | `tracked_globs` |
| `coverage_table_tool` | Formatted coverage table | `sort_order` |
| `validate_tool` | Validate coverage policies | `code` or `file` |
| `help_tool` | Tool discovery | (none) |
| `version_tool` | Version information | (none) |

### JSON Response Format

For tools that return structured data, `cov-loupe` serializes the data as a JSON string and returns it inside a `text` part of the MCP response.

**Example:**
```json
{
  "type": "text",
  "text": "{"coverage_summary":{"covered":10,"total":20,"percentage":50.0}}"
}
```

**Reasoning:**
While returning JSON in a `resource` part with `mimeType: "application/json"` is more semantically correct, major MCP clients (including Google's Gemini and Anthropic's Claude) were found to not support this format, causing validation errors. They expect a `resource` part to contain a `uri`.

To ensure maximum compatibility, the decision was made to use a simple `text` part. This is a pragmatic compromise that has proven to be reliable across different clients.

**Further Reading:**
This decision was informed by discussions with multiple AI models. For more details, see these conversations:
- [Perplexity AI Discussion](https://www.perplexity.ai/search/title-resolving-a-model-contex-IfpFWU1FR5WQXQ8HcQctyg#0)
- [ChatGPT Discussion](https://chatgpt.com/share/68e4d7e1-cad4-800f-80c2-58b33bfc31cb)

### CLI Options in MCP Mode

When the MCP server starts, you can pass CLI options via the startup command. These options become the default config for MCP tools. **Per-request JSON parameters still win over CLI defaults.**

| CLI Option | Affects MCP Server? | JSON Parameter | Notes |
|------------|-------------------|----------------|-------|
| `-R`, `--root` | ✅ Default | `root` | Request param overrides; CLI sets default |
| `-r`, `--resultset` | ✅ Default | `resultset` | Request param overrides; CLI sets default |
| `-S`, `--raise-on-stale` | ✅ Default | `raise_on_stale` | Request param overrides; CLI sets default (`false` or `true`) |
| `-g`, `--tracked-globs` | ✅ Default | `tracked_globs` | Request param overrides; CLI sets default (array) |
| `--error-mode` | ✅ Yes | `error_mode` | Sets server-wide error handling; can override per tool |
| `-l`, `--log-file` | ✅ Yes | N/A | Sets server log location (cannot override per tool) |
| `-f`, `--format` | ❌ No | N/A | CLI-only presentation flag (not used by MCP) |
| `-o`, `--sort-order` | ❌ No | `sort_order` | CLI flag ignored in MCP; pass per tool call (`\"ascending\"` or `\"descending\"`) |
| `-s`, `--source` | ❌ No | N/A | CLI-only presentation flag (not used by MCP) |
| `-c`, `--context-lines` | ❌ No | N/A | CLI-only presentation flag (not used by MCP) |
| `--color`, `--no-color` | ❌ No | N/A | CLI-only presentation flag (not used by MCP) |
| `--force-cli` | N/A | N/A | Forces CLI mode (prevents MCP mode) |

**Key Takeaways:**
- **Server-level options** (`--error-mode`, `--log-file`): Set once when server starts, apply to all tool calls
- **Tool-level options** (`root`, `resultset`, `staleness`, `tracked_globs`): CLI args provide defaults; per-tool JSON params override when provided
- **CLI-only options** (`--format`, `--source`, etc.): Not applicable to MCP mode

**Precedence for MCP tool config:** `JSON request param` > `CLI args used to start MCP` (including `COV_LOUPE_OPTS`) > built-in defaults (`root: '.'`, `raise_on_stale: false`, `resultset: nil`, `tracked_globs: nil`).

CLI-only presentation flags (`-f/--format`, `-s/--source`, `-c/--context-lines`, `--color/--no-color`, and CLI `-o/--sort-order` defaults) never flow into MCP. Pass `sort_order` explicitly in each tool request when you need non-default ordering.

### Common Parameters

All file-specific tools accept these parameters in the JSON request:

- `path` (required for file tools) - File path (relative or absolute)
- `root` (optional) - Project root directory (default: `.`)
- `resultset` (optional) - Path to the `.resultset.json` file. See [Configuring the Resultset](../README.md#configuring-the-resultset) for details.
- `raise_on_stale` (optional) - Raise error on staleness: `false` (default) or `true`
- `error_mode` (optional) - Error handling: `"off"`, `"log"` (default), `"debug"` (overrides server-level setting)

### Tool Details

#### Per-File Tools

These tools analyze individual files. All require `path` parameter.

**`coverage_summary_tool`** - Covered/total/percentage summary
```json
{"file": "...", "summary": {"covered": 12, "total": 14, "percentage": 85.71}, "stale": false}
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

**`coverage_totals_tool`** - Aggregated line totals
- Parameters: `tracked_globs` (array), `raise_on_stale`
- Returns: `{"lines":{"total":N,"covered":N,"uncovered":N},"percentage":Float,"files":{"total":N,"ok":N,"stale":N}}`

**`coverage_table_tool`** - Formatted ASCII table
- Parameters: `sort_order` (`ascending`|`descending`)
- Returns: Plain text table

#### Policy Validation Tools

**`validate_tool`** - Validate coverage against custom policies
- Parameters: Either `code` (Ruby string) OR `file` (path to Ruby file), plus optional `root`, `resultset`, `raise_on_stale`, `error_mode`
- Returns: `{"result": Boolean}` where `true` means policy passed, `false` means failed
- Security Warning: Predicates execute as arbitrary Ruby code with full system privileges. Only use predicate files from trusted sources.
- Examples:
  - Check if all files have at least 80% coverage: `{"code": "->(m) { m.all_files.all? { |f| f['percentage'] >= 80 } }"}`
  - Run coverage policy from file: `{"file": "coverage_policy.rb"}`

#### Utility Tools

**`help_tool`** - Tool discovery
**`version_tool`** - Version information

## Example Prompts for AI Assistants

(Hopefully, your AI agent will not need you to explicilty specify "Using cov-loupe",
but this is included here because we have seen cases where it does not know to use cov-loupe.)
### Coverage Analysis

```
Using cov-loupe, show me a table of all files and their coverage percentages.
```

```
Using cov-loupe, find files with less than 80% coverage and tell me which ones to prioritize.
```

```
Using cov-loupe, analyze the coverage for lib/cov_loupe/tools/ and suggest improvements.
```

### Finding Coverage Gaps

```
Using cov-loupe, show me the uncovered lines in lib/cov_loupe/base_tool.rb and explain what they do.
```

```
Using cov-loupe, find the most important uncovered code in lib/cov_loupe/tools/coverage_detailed_tool.rb.
```

### Test Generation

```
Using cov-loupe, find uncovered lines in lib/cov_loupe/staleness_checker.rb and write *meaningful* RSpec tests for them.
```

```
Using cov-loupe, analyze coverage gaps in lib/cov_loupe/tools/ and generate test cases.
```

### Coverage Reporting

```
Using cov-loupe, create a markdown report of:
- Files with worst coverage
- Most critical coverage gaps
- Recommended action items
```

## Testing Your Setup

### Manual Testing via Command Line

Test the MCP server responds to JSON-RPC:

```sh
# Test version tool (simplest, no parameters needed)
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"version_tool","arguments":{}}}' | cov-loupe

# Test help tool (no parameters needed)
echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"help_tool","arguments":{}}}' | cov-loupe

# Test summary tool (requires root parameter since -R flag doesn't work in MCP mode)
echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"coverage_summary_tool","arguments":{"path":"lib/cov_loupe/model.rb","root":"."}}}' | cov-loupe

# Test with a project-specific root
echo '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"coverage_summary_tool","arguments":{"path":"app/models/order.rb","root":"docs/fixtures/demo_project"}}}' | cov-loupe
```

**Important Notes:**
- JSON-RPC messages must be on a single line. Multi-line JSON will cause parse errors.
- CLI flags like `-R` do NOT affect MCP tool calls—you must pass `root` in the JSON `arguments` object.
- The `root` parameter is optional and defaults to `.` (current directory).

### Testing in AI Assistant

Once configured, try these prompts in your AI assistant:

1. **Basic connectivity:**
   ```
   Using cov-loupe, show me the version.
   ```

2. **List tools:**
   ```
   Using cov-loupe, what tools are available?
   ```

3. **Simple query:**
   ```
   Using cov-loupe, show me all files with coverage.
   ```

If these work, your setup is correct!

### Checking Logs

The MCP server logs to `cov_loupe.log` in the current directory by default.

```sh
# Watch logs in real-time
tail -f cov_loupe.log

# View recent errors
grep ERROR cov_loupe.log | tail -20
```

To override the default log file location, specify the `--log-file` (or `-l`) argument wherever and however you configure your MCP server. For example, to log to a different file path, include `-l /path/to/logfile.log` in your server configuration. To log to standard error, use `-l stderr`.

**Note:** Logging to `stdout` is not permitted in MCP mode.

## Troubleshooting

### CLI Fallback

**Important:** If the MCP server doesn't work, you can use the CLI directly with the `-fJ` (output in JSON format) flag.

See the **[CLI Fallback for LLMs Guide](CLI_FALLBACK_FOR_LLMS.md)** for:
- Complete command reference and MCP tool mappings
- Sample prompt to give your LLM
- JSON output examples
- Tips for using CLI as an MCP alternative

### Common Issues

**Server Won't Start**
```sh
which cov-loupe     # Verify executable exists
ruby -v             # Check Ruby >= 3.2
cov-loupe version   # Test basic functionality
```


**Tools Not Appearing**
1. Restart AI assistant after config changes
2. Check logs: `tail -f cov_loupe.log`
3. Try explicit tool names in prompts
4. Verify MCP server status in assistant

**JSON-RPC Parse Errors**
- Ensure JSON is on a single line (no newlines)
- Test manually: `echo '{"jsonrpc":"2.0",...}' | cov-loupe`

## Advanced Configuration

### Enable Debug Logging

For troubleshooting, add error mode when configuring the server:

```sh
# Claude Code
claude mcp add cov-loupe cov-loupe -- --error-mode debug

# Codex
codex mcp add cov-loupe cov-loupe --error-mode debug  

# Gemini
gemini mcp add cov-loupe cov-loupe --error-mode debug
```

## Next Steps

- **[CLI Fallback for LLMs](CLI_FALLBACK_FOR_LLMS.md)** - Using CLI when MCP isn't available
- **[CLI Usage](CLI_USAGE.md)** - Complete CLI reference
- **[Examples](EXAMPLES.md)** - Example prompts and workflows
- **[Troubleshooting](TROUBLESHOOTING.md)** - Detailed troubleshooting guide
