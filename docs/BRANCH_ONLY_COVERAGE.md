# Branch-Only Coverage Handling

SimpleCov can collect *line* coverage, *branch* coverage, or both. Projects that
enable the `:branch` mode without `:line` produce a `.resultset.json` where the
per-file entries contain a `branches` hash while the legacy `lines` array is
`null`. This document explains that format and why SimpleCov MCP synthesizes a
line array on the fly so downstream consumers continue to work.

## SimpleCov branch payloads

Each resultset groups coverage by absolute (or project-relative) path. A branch
only entry looks like:

```json
{
  "lib/example.rb": {
    "lines": null,
    "branches": {
      "[:if, 0, 12, 4, 20, 29]": {
        "[:then, 1, 13, 6, 13, 18]": 4,
        "[:else, 2, 15, 6, 15, 16]": 0
      }
    }
  }
}
```

Key observations:

- The outer hash key is either a stringified Ruby array or the raw array itself:
  `[:if, branch_id, line, column, end_line, end_column]`. Array structure:
  - index 0: branch type (`:if`, `:case`, `:unless`, etc.)
  - index 1: internal branch identifier
  - **index 2: line where the branch starts** (the field we care about for coverage)
  - index 3: column where the branch starts
  - index 4: line where the branch expression ends
  - index 5: column where the branch expression ends
- SimpleCov reuses a single branch tuple for all recorded runs.
- The nested hash contains targets (`[:then, …]`, `[:else, …]`, `[:when, …]`, etc.)
  Each target tuple mirrors the same shape—branch type at index 0, an internal
  identifier at 1, then the start/end positions for that branch leg.
  The integer value is the execution count for that branch leg. SimpleCov MCP
  sums these counts per line when synthesizing fallback line data.

## Synthesizing line coverage

SimpleCov MCP exposes APIs and CLI tooling built around line-oriented coverage.
To support branch-only projects, we reconstruct a minimal line array by summing
branch hits per line. The resolver:

1. Normalizes branch tuples, whether they arrive as arrays or strings.
2. Extracts the line token (element `2`) and converts it to an integer.
3. Aggregates hit counts across all branch targets for that line.
4. Builds a dense array up to the highest line seen. Each populated slot stores
   the total branch hits recorded for that line. Slots remain `nil` when a line
   never appeared in the branch data.

This produces the familiar SimpleCov shape (array index → line number - 1), so
utilities like `summary`, `uncovered`, and staleness checks keep working.

## Code map

Relevant implementation points:

- `lib/simplecov_mcp/resolvers/coverage_line_resolver.rb` — entry point that
  synthesizes the array when `lines` is missing.
- Specs covering branch-only behaviour live in
  `spec/resolvers/coverage_line_resolver_spec.rb` and
  `spec/simplecov_mcp_model_spec.rb`.
- Fixture data resides at
  `spec/fixtures/branch_only_project/coverage/.resultset.json`.

Implementation notes:

- The resolver must return `nil` when a path fails to match. `CovUtil.lookup_lines`
  tries alternate keys (absolute, project-relative, cwd-stripped). Returning
  `nil` allows those attempts to continue, ultimately raising the expected
  `FileError` only after every variant is exhausted.
- SimpleCov may evolve the branch tuple format. When that happens, extend
  `extract_line_number` to recognize the new shape and refresh this document so
  future maintainers understand which forms are supported.
