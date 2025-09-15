## MCP JSON Inputs

This directory contains example JSON-RPC requests that can be sent to the MCP server over stdio.

Each file contains a single line of JSON (NDJSON-ready), so you can pipe it directly to the executable.

**Target Project:** These inputs are designed to work with the demo project located at `examples/fixtures/demo_project`.

### Running the Examples

From the repository root:

```sh
exe/simplecov-mcp < examples/mcp-inputs/coverage_summary.json
exe/simplecov-mcp < examples/mcp-inputs/uncovered_lines.json
```

If `simplecov-mcp` is installed globally and available on your `PATH`:

```sh
simplecov-mcp < examples/mcp-inputs/coverage_summary.json
```

### Formatting Tips (jq and rexe)

You can use tools like `jq` or `rexe` to format the JSON input and output, which is especially helpful for debugging.

**Pretty-print an input file:**

Using `jq`:
```sh
jq . examples/mcp-inputs/coverage_summary.json
```

Using `rexe`:
```sh
rexe -f examples/mcp-inputs/coverage_summary.json -oJ
```

**Pretty-print the MCP server's JSON response (NDJSON):**

Using `jq`:
```sh
exe/simplecov-mcp < examples/mcp-inputs/coverage_summary.json | jq .
```

Using `rexe`:
```sh
exe/simplecov-mcp < examples/mcp-inputs/coverage_summary.json | rexe -ml -ij -oJ
```
