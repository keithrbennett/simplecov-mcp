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
- Run CLI from repo: `ruby -Ilib exe/simplecov-mcp --cli`
- Common CLI examples:
  - List table: `simplecov-mcp --cli --resultset coverage`
  - File summary: `simplecov-mcp --cli summary lib/foo.rb`
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

## Commit & Pull Request Guidelines
- Commits: clear, imperative summaries (e.g., "Add detailed coverage tool output"). Group related changes; keep diffs small.
- PRs: include description, rationale, before/after output (for CLI), and links to issues. Note any public API changes to `CoverageModel` or tool argument shapes.
- Update docs (`README.md`, examples) when flags, outputs, or behaviors change.

## Security & Configuration Tips
- Resultset selection: use `--resultset PATH` or `SIMPLECOV_RESULTSET`. For strict freshness, set `--stale error`; detect new files with `--tracked-globs "lib/**/*.rb"`.
- MCP clients must send single-line JSON-RPC messages over stdio.

