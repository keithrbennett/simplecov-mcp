# CLI Fallback for LLMs

When the MCP server integration isn't working or available, LLMs can use the `simplecov-mcp` CLI directly with the `-fJ` flag to get the same coverage data that the MCP tools provide.

## Overview

The `simplecov-mcp` CLI provides all the same functionality as the MCP tools:
- JSON output via `-fJ` flag for machine-readable responses
- Same coverage data: summaries, uncovered lines, detailed per-line data, project-wide tables
- Same configuration options: custom resultset paths, staleness checking, etc.

## Sample Prompt for Users

If MCP isn't working, provide this prompt to your LLM:

```
The simplecov-mcp MCP server isn't available. Please use the simplecov-mcp CLI
instead with the -fJ flag for pretty-printed JSON output.

To discover available commands and options:
  simplecov-mcp --help

All commands support -fJ for structured, pretty-printed output.

For detailed documentation, see:
- README.md in the gem root
- docs/user/ directory (CLI_USAGE.md, EXAMPLES.md, etc.)
```

## Related Documentation

- [CLI Usage Guide](CLI_USAGE.md) - Complete CLI reference
- [MCP Integration](MCP_INTEGRATION.md) - MCP server setup
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues
