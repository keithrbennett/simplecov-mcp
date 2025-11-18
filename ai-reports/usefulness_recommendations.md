# SimpleCov MCP — Usefulness & Convenience Recommendations

Date: 2025-09-20
Author: Codex AI

This report reviews the current capabilities and suggests focused enhancements to improve usefulness, ergonomics, and integration surface for both CLI and MCP users.

## Summary of Current Strengths

- Dual-surface design: robust CLI and MCP tools backed by a well-factored `CoverageModel`.
- Clear CLI UX with table/JSON modes, source snippets, and staleness checks.
- Solid error-handling abstraction with friendly messages and server-mode logging.
- MCP tool suite covers common needs (file summaries, uncovered lines, detailed, repo list, help, version).
- Recent improvement: JSON returned as `resource` (application/json) avoids content-type coercion bugs.

## High-Impact Additions

- Threshold enforcement
  - CLI: `--fail-under PCT` to exit nonzero when any file or overall min < PCT.
  - MCP: new tool `min_coverage_tool(threshold: Float, scope: "overall|per_file")` returning pass/fail and offenders.

- Diff/PR-focused coverage
  - New MCP tool + CLI flag to limit outputs to changed files (detect via `git diff --name-only <base>` or env like `BASE_SHA`).
  - Outputs: per-file summaries, uncovered lines for changed files, and a single “diff coverage %” metric.

- Grouping and summaries
  - CLI: `--group-by dir[:levels]` to aggregate by top-level dirs or N path segments; show per-group % and counts.
  - MCP: `group_summary_tool(groups: ["lib/**", "spec/**"])` returning group rollups.

- Focus views
  - Top N worst files: `simplecov-mcp list --top 20` and MCP `top_files_tool(limit: 20, order: "ascending|descending")`.
  - Hotspots by uncovered count: list files ranked by uncovered lines, not percentage.

- Config file support
  - Read `.simplecov-mcp.yml` for defaults (resultset, sort order, groupings, thresholds, tracked_globs) with env/CLI overrides.

## Developer/Automation Convenience

- Machine-readable outputs
  - CLI: `--format json|ndjson|table` (ndjson helpful for streaming large sets).
  - Add `--out FILE` to write JSON to a path (avoids shell redirection in CI).

- Standard formats
  - Exporters: JUnit XML (per-file as testcases), SARIF (uncovered lines as results), GitHub Actions annotations.
  - MCP: tools returning `resource_link` with `data:` URIs or file URIs for large payloads.

- CI integration helpers
  - Auto-detect CI (GitHub, GitLab, Circle) for baseline SHAs; print friendly hints when data is missing.
  - Fail-fast guidance: if stale/error flags trip, suggest `--stale off` or re-run tests.

## Coverage Analysis Enhancements

- New insights
  - “Most critical misses” heuristic: rank uncovered lines by simple risk signals (files under `lib/`, public API files, lines near conditionals).
  - “Simplest wins” heuristic: short functions with uncovered lines, or files < N lines.

- Project-level stats
  - Overall min/median/mean %; distribution buckets (e.g., files in 0–50%, 50–80%, 80–100%).
  - Time-based regression guard: record last run’s min % in a cache file and warn on drop.

## CLI UX Improvements

- Quality-of-life flags
  - `--filter INCLUDE_GLOB[,..]` and `--exclude EXCLUDE_GLOB[,..]` to narrow `list` and related views.
  - `--no-color` already exists; add `--plain` to force ASCII table borders.
  - `--columns file,percentage,covered,total,stale` to customize table columns; add `--sort by=percentage|file|covered`.

- Source rendering polish
  - `--source=uncovered` already supports context; add `--source-max-lines N` to bound output in CI logs.
  - Show a legend and totals for uncovered snippets.

## MCP Tooling Improvements

- Structured tool catalog
  - Extend `help_tool` to return argument schemas and versioned tool metadata (adds `schema` key with JSON Schema for each tool).
  - Add a `ping_tool` and `capabilities_tool` for client readiness checks and content-type negotiation.

- Large payload strategies
  - Support streaming via multiple content items (chunking), or `resource_link` pointing to a temp file when results exceed a threshold.

## Model/Performance

- Coverage cache
  - Memoize parsed resultset across tool calls within a server session; expose a `reload` command for manual refresh.

- Multi-resultset support
  - SimpleCov can write multiple profiles; optionally merge or select by profile name/command name.

## Cross-Platform & Pathing

- Windows paths
  - Normalize separators and drive letters; ensure `relative_path_from` behavior is consistent on Windows.

- Security/Privacy controls
  - Options to redact absolute paths in machine outputs by default (already relativized in CLI) and expose a `--absolute-paths` opt-in.

## Documentation & Examples

- MCP client snippets
  - Provide minimal client snippets for popular environments (Node, Python) showing how to parse `resource` JSON.

- Recipes
  - “Fail CI under 90% on changed files” recipe using diff mode + threshold.
  - “Generate a PR comment with worst files” using JSON output and a templater.

## Testing Enhancements

- Expand CLI/mode-selection tests in `lib/simple_cov_mcp.rb` (TTY vs piped modes).
- Add tests for newly proposed tools/flags (top, filter/exclude, group summaries).
- Add snapshot-style tests for table rendering with `--plain` borders.

## Suggested Implementation Order

1) Quick wins (1–2 days)
   - `--fail-under` (CLI) and `top_files_tool` (MCP).
   - `--filter/--exclude` for `list`.
   - Config file `.simplecov-mcp.yml` read + merge with CLI/env.

2) PR/diff coverage (2–3 days)
   - Git integration + `diff_coverage_tool` and CLI `--diff-base`/`--changed-only`.

3) Grouping and exporters (2–4 days)
   - `--group-by` and group summaries (CLI + MCP).
   - JUnit/SARIF exporters; GitHub annotations option.

4) Streaming/large-output handling (as needed)
   - Chunked MCP responses or `resource_link` for large JSON.

5) Docs and examples (ongoing)
   - Update README with new flags/tools, add examples in `examples/`.

## Risks & Mitigations

- Backward compatibility: keep existing tool names/outputs stable; add new tools/flags rather than changing semantics.
- Client variance: maintain `resource` JSON by default and document parsing; provide `text` fallbacks only for human-centric outputs.
- CI variability: detect missing VCS/CI context and provide actionable guidance rather than failing hard.

---

This plan adds value for local workflows, CI enforcement, and MCP-based automation while staying incremental and low-risk.
