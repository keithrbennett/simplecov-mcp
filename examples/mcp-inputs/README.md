## MCP JSON inputs

JSON‑RPC requests to send to the MCP server over stdio.

Each file is one line of JSON (NDJSON‑ready), so you can run them as‑is.

From repo root:
```sh
exe/simplecov-mcp < examples/mcp-inputs/coverage_summary.json
exe/simplecov-mcp < examples/mcp-inputs/uncovered_lines.json
```

If installed globally and on PATH:
```sh
simplecov-mcp < examples/mcp-inputs/coverage_summary.json
```

These inputs target the demo project at `examples/fixtures/demo_project`.

## Formatting tips (jq and rexe)

- Pretty‑print an input file:
```sh
jq . examples/mcp-inputs/coverage_summary.json
```
or with rexe:
```sh
rexe -f examples/mcp-inputs/coverage_summary.json -oJ
```

- Pretty‑print the MCP server's JSON responses (NDJSON):
```sh
exe/simplecov-mcp < examples/mcp-inputs/coverage_summary.json | jq .
```
or with rexe:
```sh
exe/simplecov-mcp < examples/mcp-inputs/coverage_summary.json | rexe -ml -ij -oJ
```

- Compact JSON to one line:
```sh
jq -c . examples/mcp-inputs/coverage_summary.json
```
or with rexe:
```sh
rexe -f examples/mcp-inputs/coverage_summary.json -oj
```
