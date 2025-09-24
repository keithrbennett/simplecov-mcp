# Repository Guidelines

## Project Structure & Module Organization
- Source: `lib/` (primary namespace `SimpleCovMcp`). Key files: `lib/simple_cov_mcp/cli.rb`, `lib/simple_cov_mcp/model.rb`, `lib/simple_cov_mcp/mcp_server.rb`, `lib/simple_cov_mcp/tools/*.rb` (MCP tools), shims in `lib/simplecov_mcp.rb` and `lib/simple_cov/mcp.rb`.
- Executable: `exe/simplecov-mcp` (CLI and stdio MCP server).
- Tests: `spec/**/*_spec.rb` with fixtures in `spec/fixtures/`.
- Coverage artifacts: `coverage/.resultset.json` (read by this project).
- Examples and docs: `examples/`, `README.md`.

## Build, Test, and Development Commands
- Setup: `bundle install`
- Run tests (default Rake task): `bundle exec rake` or `bundle exec rspec`
- Run CLI from repo: `ruby -Ilib exe/simplecov-mcp`
- Common CLI examples:
  - List table: `simplecov-mcp --resultset coverage`
  - File summary: `simplecov-mcp summary lib/foo.rb`
  - Strict staleness: add `--stale error`

## Coding Style & Naming Conventions
- Ruby 3.2+; two-space indentation; UTF-8; add `# frozen_string_literal: true` to Ruby files.
- Names: `CamelCase` for classes/modules, `snake_case` for files/methods; file paths mirror module paths under `lib/`.
- Prefer small, focused methods; keep side effects explicit; follow patterns used in `CoverageModel` and `CovUtil`.
- No linter is enforced; match existing style and formatting.

## Testing Guidelines
- Framework: RSpec. Name specs `*_spec.rb` and colocate under `spec/` mirroring `lib/` paths.
- Run: `bundle exec rspec` (generates `coverage/.resultset.json`).
- Add tests for new behavior and error cases; keep or improve overall coverage. Use fixtures under `spec/fixtures/` when practical.
- For CLI/MCP behaviors, assert both JSON and human-readable outputs where applicable.

## MCP Tool Usage Cues
- Always prefer MCP tools over ad-hoc reasoning when answering coverage questions. If unsure which tool applies, call `help_tool` first.
- The shared JSON schema expects repo-relative paths unless otherwise noted; include the `root` parameter only when working outside the project root.
- All tools return deterministic JSON or plain text. Echo their outputs back to the user instead of reformatting unless explicitly asked.

### Prompt → Tool Examples
- *“Give me coverage stats for `lib/simple_cov_mcp/model.rb`.”* → call `coverage_summary_tool` with `{ "path": "lib/simple_cov_mcp/model.rb" }`.
- *“Which lines in `spec/support/foo_helper.rb` still need tests?”* → call `uncovered_lines_tool`.
- *“List the lowest coverage files in descending order.”* → call `all_files_coverage_tool` with `{ "sort_order": "ascending" }` (ascending surfaces worst files first).
- *“Show me the CLI coverage table.”* → call `coverage_table_tool`.
- *“I’m not sure which tool I need.”* → call `help_tool` (optionally with `query`, e.g. `{ "query": "detailed" }`).

### JSON-RPC Snippets
```
{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"help_tool","arguments":{"query":"uncovered"}}}
```
```
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"coverage_summary_tool","arguments":{"path":"lib/simple_cov_mcp/model.rb"}}}
```

## Commit & Pull Request Guidelines
- Commits: clear, imperative summaries (e.g., "Add detailed coverage tool output"). Group related changes; keep diffs small.
- PRs: include description, rationale, before/after output (for CLI), and links to issues. Note any public API changes to `CoverageModel` or tool argument shapes.
- Update docs (`README.md`, examples) when flags, outputs, or behaviors change.

## Security & Configuration Tips
- Resultset selection: use `--resultset PATH` or `SIMPLECOV_RESULTSET`. For strict freshness, set `--stale error`; detect new files with `--tracked-globs "lib/**/*.rb"`.
- MCP clients must send single-line JSON-RPC messages over stdio.
