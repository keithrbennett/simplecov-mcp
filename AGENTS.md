# AGENTS.md – Codex Cloud Guide

## Mission
- Pull accurate coverage data and project facts for users by driving SimpleCov MCP tools instead of free-form guesses.
- Keep workflow transparent: explain what you did, why it matters, and what the user should consider next.
- Leave the repository tidy; only touch files that advance the request.

## Environment & Execution
- Run commands through the Codex CLI harness: always call `shell` with `['bash','-lc', '<command>']` and set `workdir` (avoid `cd` chains).
- Prefer `rg`/`rg --files` for searches; switch only if ripgrep is unavailable.
- Sandbox: workspace write access; network is restricted. Request escalation (`with_escalated_permissions` + short justification) only when indispensable.
- Approval mode is `on-request`: retry failed-but-needed commands with escalation rather than asking the user manually.
- Planning tool: skip for trivial chores; otherwise create a multi-step plan and keep it updated as you work (max one `in_progress` step).
- Stop immediately and ask the user if the repo contains unexpected changes you did not make.

## Repository Snapshot
- Ruby gem exposing a SimpleCov coverage CLI (`exe/simplecov-mcp`) and MCP server; library lives under `lib/simple_cov_mcp/`.
- Key files: `lib/simple_cov_mcp/cli.rb`, `model.rb`, `mcp_server.rb`, and tool implementations in `lib/simple_cov_mcp/tools/*.rb`; shims in `lib/simplecov_mcp.rb` and `lib/simple_cov/mcp.rb`.
- Tests: RSpec under `spec/` with fixtures in `spec/fixtures/`; running tests produces `coverage/.resultset.json` consumed by the tools.
- Useful commands:
  - `scripts/setup_codex_cloud.sh [--skip-tests]` – bootstrap dependencies (installs gems, runs tests by default)
  - `bundle install` – install dependencies
  - `bundle exec rspec` – run rspec (currently not working in Codex for macOS)
  - `ruby -Ilib exe/simplecov-mcp ...` – run CLI or MCP server directly
  - `simplecov-mcp --resultset coverage` – table view of coverage data

## Coding & Testing Guidelines
- Target Ruby >= 3.2; use two-space indentation and `# frozen_string_literal: true` in Ruby files.
- Match existing style and patterns (see `CoverageModel` and `CovUtil` helpers). Comments should clarify non-obvious logic only.
- Never undo or overwrite user changes outside your scope; integrate with them instead.
- When adding behavior, couple it with tests; keep or raise coverage. Specs belong in `spec/**/*_spec.rb` mirroring the lib path.
- Validate meaningful changes with `bundle exec rspec` when feasible; note skipped verification in your summary if you cannot run it.

## MCP Tool Playbook
- Always select an MCP tool over ad-hoc reasoning for coverage data. Unsure which one fits? Call `help_tool` (optionally with a `query`).
- Go-to mappings:
  - File summary → `coverage_summary_tool` (`{ "path": "lib/simple_cov_mcp/model.rb" }`)
  - Per-line detail → `coverage_detailed_tool`
  - Uncovered lines → `uncovered_lines_tool`
  - Raw SimpleCov array → `coverage_raw_tool`
  - Repository list/table → `all_files_coverage_tool` (use `sort_order` / `tracked_globs` as needed)
  - Human-readable table text → `coverage_table_tool`
  - Version check → `version_tool`
- Responses return deterministic JSON/text; surface the tool output directly unless the user asks for interpretation.

## Response Expectations
- Be concise and collaborative. Lead with the change/insight; follow with necessary detail.
- Reference files with inline clickable paths (e.g., `lib/simple_cov_mcp/model.rb:42`). Avoid ranges and external URIs.
- Summaries use plain bullets (`-`). Offer next steps only when they flow naturally (tests, commits, builds, validation).
- Do not dump entire files; mention paths. Keep tone factual, note open questions, and highlight testing gaps.

## Troubleshooting Notes
- Coverage lookup order: explicit `--resultset`, then `.resultset.json`, `coverage/.resultset.json`, `tmp/.resultset.json`.
- `SIMPLECOV_MCP_OPTS` can set default CLI flags (command-line arguments still win).
- CLI vs MCP mode auto-detects based on TTY; use `--force-cli` if you need to bypass MCP auto start during manual runs.
