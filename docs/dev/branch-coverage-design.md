# Branch Coverage Support — Design Document

[Back to Architecture](ARCHITECTURE.md) | [Back to dev docs](README.md)

This document describes the design for adding SimpleCov branch coverage support to cov-loupe. It covers the consumer-facing interfaces (CLI, MCP, Library API) and the internal implementation changes required.

---

## Background

SimpleCov can track branch coverage when `SimpleCov.enable_coverage :branch` is set in the test helper. When enabled, each file entry in `.resultset.json` gains a `branches` key alongside the existing `lines` key:

```json
{
  "RSpec": {
    "coverage": {
      "lib/foo.rb": {
        "lines": [null, 1, 0, null, 2],
        "branches": {
          "[:if, 0, 3, 0, 5, 12]": {
            "[:then, 1, 3, 0, 3, 12]": 2,
            "[:else, 2, 5, 0, 5, 12]": 0
          }
        }
      }
    }
  }
}
```

Each key in the outer `branches` hash identifies a branch point (an AST node serialized to a string: `[:type, id, start_line, start_col, end_line, end_col]`). Each key in the inner hash identifies one arm of that branch point. The value is the hit count (an integer ≥ 0).

Branch coverage is present only when the user has enabled it in their SimpleCov config. cov-loupe must handle both cases gracefully — resultsets with branch data and resultsets without it.

---

## Consumer-Facing Interfaces

### CLI

#### New global flag: `--coverage-type`

```
-C, --coverage-type TYPE    Coverage type to report: lines, branches, or both (default: lines)
```

Short form: `-C`. Accepted values (case-insensitive): `lines` (`l`), `branches` (`b`), `both` (no abbreviation, to avoid ambiguity).

This flag is accepted by all subcommands that produce coverage metrics: `list`, `summary`, `detailed`, `uncovered`, `totals`. It is silently ignored by `raw` (raw output is always lines-only) and `validate`.

#### Subcommand behaviour changes

**`list`**

With `--coverage-type lines` (default): no change to existing output.

With `--coverage-type branches`:

```
File                             % (Branches)   Covered  Total  Stale
lib/cov_loupe/model.rb           87.50%         7        8
lib/cov_loupe/cli.rb             75.00%         6        8
lib/cov_loupe/coverage/...       100.00%        4        4
...
```

With `--coverage-type both`:

```
File                             % (Lines)  L.Cov  L.Tot  % (Branches)  B.Cov  B.Tot  Stale
lib/cov_loupe/model.rb           92.31%     12     13     87.50%         7      8
...
```

If the resultset contains no branch data, branch columns display `N/A` and a one-line note is appended below the table: `Note: no branch coverage data found in resultset.`

**`summary`**

With `--coverage-type lines` (default): no change.

With `--coverage-type branches`:

```
lib/cov_loupe/model.rb — branch coverage
  Covered branches : 7
  Total branches   : 8
  Coverage         : 87.50%
```

With `--coverage-type both`, both line and branch blocks are printed.

**`detailed`**

With `--coverage-type branches`, output lists each branch arm on its own line:

```
lib/cov_loupe/cli.rb
  Line  3  [:if]   then-arm   hits: 2   covered
  Line  3  [:if]   else-arm   hits: 0   NOT COVERED
  Line  9  [:case] when-arm   hits: 5   covered
  ...
```

Branch arms are sorted by start line, then by arm index within a branch point.

With `--coverage-type both`, the existing per-line detail is printed first, followed by a branch-arm section.

**`uncovered`**

With `--coverage-type branches`, prints uncovered branch arm identifiers grouped by branch point:

```
lib/cov_loupe/cli.rb — uncovered branches
  Line 3  [:if]   else-arm
  Line 7  [:if]   else-arm
```

With `--coverage-type both`, uncovered lines are printed first (existing behaviour), then uncovered branches.

**`totals`**

With `--coverage-type branches`:

```
Branch coverage totals
  Covered branches : 45
  Total branches   : 52
  Coverage         : 86.54%
```

With `--coverage-type both`, line totals block is printed first, then branch totals.

#### JSON / YAML / structured output

When `--format json` (or `yaml`, `amazing_print`) is used alongside `--coverage-type branches` or `both`, the structured payload is extended:

```json
{
  "file": "lib/cov_loupe/cli.rb",
  "summary": {
    "lines": { "covered": 38, "total": 42, "percentage": 90.48 },
    "branches": { "covered": 6, "total": 8, "percentage": 75.0 }
  },
  "uncovered_lines": [17, 34],
  "uncovered_branches": [
    { "line": 3, "type": "if", "arm": "else" },
    { "line": 7, "type": "if", "arm": "else" }
  ]
}
```

The `lines` block is always present. The `branches` block is present only when `--coverage-type` includes branches; if the resultset has no branch data it is `null` with an additional `"branch_data_available": false` key at the top level.

---

### MCP Server

#### Changes to existing tools

All per-file tools (`file_coverage_summary`, `file_coverage_detailed`, `file_uncovered_lines`) gain an optional `coverage_type` parameter:

| Parameter | Type | Default | Accepted values |
|---|---|---|---|
| `coverage_type` | string | `"lines"` | `"lines"`, `"branches"`, `"both"` |

Project-level tools (`project_coverage`, `project_coverage_totals`) gain the same parameter.

When `coverage_type` is `"lines"` (or omitted), responses are identical to today — fully backward compatible.

**`file_coverage_summary` with `coverage_type: "branches"`**

```json
{
  "file": "lib/cov_loupe/cli.rb",
  "branch_summary": { "covered": 6, "total": 8, "percentage": 75.0 },
  "stale": false,
  "branch_data_available": true
}
```

**`file_coverage_summary` with `coverage_type: "both"`**

```json
{
  "file": "lib/cov_loupe/cli.rb",
  "summary": { "covered": 38, "total": 42, "percentage": 90.48 },
  "branch_summary": { "covered": 6, "total": 8, "percentage": 75.0 },
  "stale": false,
  "branch_data_available": true
}
```

**`file_coverage_detailed` with `coverage_type: "branches"`**

```json
{
  "file": "lib/cov_loupe/cli.rb",
  "branches": [
    { "line": 3, "type": "if", "arm": "then", "hits": 2, "covered": true },
    { "line": 3, "type": "if", "arm": "else", "hits": 0, "covered": false }
  ],
  "branch_summary": { "covered": 6, "total": 8, "percentage": 75.0 },
  "stale": false
}
```

**`file_uncovered_lines` with `coverage_type: "branches"`**

```json
{
  "file": "lib/cov_loupe/cli.rb",
  "uncovered_branches": [
    { "line": 3, "type": "if", "arm": "else" },
    { "line": 7, "type": "if", "arm": "else" }
  ],
  "branch_summary": { "covered": 6, "total": 8, "percentage": 75.0 },
  "stale": false
}
```

**`project_coverage` with `coverage_type: "both"`**

Each row in the `files` array gains `branch_covered`, `branch_total`, `branch_percentage` fields. Top-level keys `branch_covered_total`, `branch_total_total`, `branch_percentage_total` are also added, alongside the existing line-level aggregates.

**`project_coverage_totals` with `coverage_type: "branches"` or `"both"`**

```json
{
  "lines": { "covered": 120, "total": 133, "percentage": 90.23 },
  "branches": { "covered": 45, "total": 52, "percentage": 86.54 },
  "files": { "total": 12 }
}
```

The `branches` key is omitted (not set to null) when `coverage_type` is `"lines"`.

#### `help` tool

The `help` tool's `TOOL_GUIDE` is updated to document the new `coverage_type` parameter and describe when branch data is available.

#### `project_validate` tool

The Ruby predicate passed to `project_validate` gains access to a `branch_percentage` method on each coverage row (returning `nil` when branch data is unavailable for that file). Example predicate:

```ruby
coverage_percentage >= 90 && (branch_percentage.nil? || branch_percentage >= 80)
```

---

### Library API (`CoverageModel`)

The following new public methods are added to `CoverageModel`:

```ruby
# Branch coverage summary for one file.
# Returns { file:, branch_summary: { covered:, total:, percentage: }, stale: }
# Returns nil for branch_summary when the file has no branch data.
def branch_summary_for(path)

# Per-arm branch detail for one file.
# Returns { file:, branches: [{ line:, type:, arm:, hits:, covered: }], branch_summary: }
def branch_detailed_for(path)

# Uncovered branch arms for one file.
# Returns { file:, uncovered_branches: [{ line:, type:, arm: }], branch_summary: }
def branch_uncovered_for(path)
```

Existing methods (`summary_for`, `detailed_for`, `uncovered_for`, `list`, `project_totals`) are not modified. Callers who want combined line+branch data call both the line and branch methods and merge the results.

---

## Internal Implementation

### Layer overview

```
ResultsetLoader        (no changes)
        │
CoverageLineResolver   ← add BranchResolver alongside it
        │
CoverageCalculator     ← add branch_summary, branch_uncovered,
        │                 branch_detailed, aggregate_branches
CoverageModel          ← add branch_*_for, extend list/project_totals
        │
CLI commands           ← add --coverage-type flag, extend output
MCP tools              ← add coverage_type param, extend responses
```

### 1. Branch data extraction — `BranchResolver`

A new class `CovLoupe::BranchResolver` (in `lib/cov_loupe/resolvers/branch_resolver.rb`) mirrors `CoverageLineResolver` for the `branches` key.

```ruby
# Returns the raw branches hash for the given absolute file path, or nil if
# the entry exists but has no branch data. Raises FileError if the path is
# not found in the coverage map.
def lookup_branches(file_abs)
```

Internal helper:

```ruby
# Returns the branches hash from a coverage entry, or nil if absent.
# Raises CorruptCoverageDataError if branches is present but malformed.
def branches_from_entry(entry)
```

Valid branch data: a Hash whose keys are Strings starting with `"[:"` and whose values are Hashes of String keys to Integer values (hit counts ≥ 0). Any other structure raises `CorruptCoverageDataError`.

`ResolverHelpers` gains a `create_branch_resolver` factory and a `lookup_branches` convenience wrapper, paralleling the existing `lookup_lines`.

### 2. Branch arm parsing — `BranchArmParser`

A small utility class `CovLoupe::BranchArmParser` (in `lib/cov_loupe/coverage/branch_arm_parser.rb`) converts the raw nested-hash structure into a flat array of `BranchArm` value objects.

```ruby
BranchArm = Data.define(:line, :type, :arm_index, :arm_label, :hits)
```

Field notes:
- `line` — Integer, 1-based start line of the branch point (parsed from branch-point key).
- `type` — Symbol, e.g. `:if`, `:case`, `:while` (parsed from first element of branch-point key).
- `arm_index` — Integer, sequential arm index within the branch point (from arm key).
- `arm_label` — String, human-readable label e.g. `"then"`, `"else"`, `"when"`, `"body"` (derived from arm key type element).
- `hits` — Integer, raw hit count.

`BranchArmParser.parse(branches_hash)` returns `Array<BranchArm>` sorted by `line` then `arm_index`. Returns `[]` for a nil or empty input.

### 3. Branch metrics — `CoverageCalculator` extensions

New class methods on `CoverageCalculator`:

```ruby
# Accepts an Array<BranchArm> (from BranchArmParser.parse).
# Returns { covered: Integer, total: Integer, percentage: Float }.
def self.branch_summary(arms)

# Returns an Array<BranchArm> where hits == 0.
def self.branch_uncovered(arms)

# Returns Array<Hash> with per-arm detail suitable for serialisation.
# Each entry: { line:, type:, arm:, hits:, covered: }.
def self.branch_detailed(arms)

# Accepts an Array of branch_summary hashes.
# Returns { covered: Integer, total: Integer, percentage: Float }.
def self.aggregate_branches(summaries)
```

### 4. `CoverageModel` additions

`branch_summary_for`, `branch_detailed_for`, and `branch_uncovered_for` follow the same shape as their line counterparts:

1. Resolve the absolute path using the existing path-resolution strategy.
2. Call `BranchResolver#lookup_branches` to get the raw hash.
3. Parse via `BranchArmParser.parse`.
4. Compute metrics via the new `CoverageCalculator` branch methods.
5. Relativize the file path via `PathRelativizer`.
6. Return the structured result hash.

`list` and `project_totals` gain an internal helper `build_branch_row(coverage_entry)` that returns a branch summary hash (or `nil` if the entry has no branch data). When `coverage_type` includes branches, each row/aggregate is supplemented with this data.

### 5. `CoverageLineResolver` — relax branch-only error

The current `CorruptCoverageDataError` for entries that have `branches` but no `lines` is too strict. This error is retained only for entries that have neither `lines` nor `branches`. An entry with only `branches` (no `lines`) is valid from a branch-coverage perspective; line-coverage queries on such a file return `nil` lines with an informational message rather than an exception.

### 6. CLI changes

**`cli.rb`** — add `--coverage-type` to the global options block. Store in the shared options hash.

**`base_command.rb`** (or each affected command class) — propagate `coverage_type` into model calls.

**`list_command.rb`** — pass `coverage_type` to `model.list`; adjust table formatter call.

**`summary_command.rb`** — conditionally call `branch_summary_for` and/or `summary_for` based on `coverage_type`.

**`detailed_command.rb`** — conditionally call `branch_detailed_for`.

**`uncovered_command.rb`** — conditionally call `branch_uncovered_for`.

**`totals_command.rb`** — conditionally call `project_totals` with branch aggregates.

**`coverage_table_formatter.rb`** — add branch column definitions; columns are appended after existing line columns when coverage type includes branches.

### 7. MCP tool changes

Each affected tool class gains `coverage_type` as an optional string property (default `"lines"`) in its JSON schema. The tool's `call` method dispatches to the appropriate model method(s) and merges the results before passing to `respond_json`.

No new tool classes are required; `coverage_type` is an additive parameter on all existing file and project tools.

### 8. `help_tool.rb`

`TOOL_GUIDE` is updated to:
- Document the `coverage_type` parameter.
- Note that branch data is only available when SimpleCov branch coverage is enabled.
- Provide an example prompt for each coverage type.

---

## Error Handling

| Scenario | Behaviour |
|---|---|
| `coverage_type: "branches"` but resultset has no branch data for any file | Return `branch_data_available: false` in structured output; print informational message to stderr in CLI; no exception. |
| `coverage_type: "branches"` for a specific file that has no branch data | Return `branch_summary: null, branch_data_available: false`; no exception. |
| `branches` key present but malformed (non-integer hit count, wrong nesting, etc.) | Raise `CorruptCoverageDataError` with file path and description. |
| Entry has `branches` but no `lines` and `coverage_type: "lines"` is requested | Return `nil` lines with a warning; do not raise. |
| Entry has `branches` but no `lines` and `coverage_type: "branches"` is requested | Work normally. |

---

## Backward Compatibility

- The default value of `coverage_type` is `"lines"` everywhere. All existing CLI invocations and MCP tool calls produce identical output unless the user explicitly passes `--coverage-type` or `coverage_type`.
- JSON/YAML output schemas are additive only: new keys are added, no existing keys are removed or renamed.
- Library callers using `summary_for`, `detailed_for`, etc. see no change; branch data is available only through the new `branch_*_for` methods.

---

## Testing Plan

1. **Fixtures** — Add a new resultset fixture (`spec/fixtures/project_with_branches/`) containing files with both `lines` and `branches` data, and at least one file with `branches` but no `lines`.

2. **`BranchArmParser`** — Unit tests covering: empty input, single arm, multiple branch points, all recognized arm types (`then`, `else`, `when`, `body`, `else`-of-case), unknown arm type (falls back to raw label), sorting by line then arm index.

3. **`CoverageCalculator` branch methods** — Tests for `branch_summary` (all covered, none covered, mixed), `branch_uncovered` (empty result, multiple), `branch_detailed` (field mapping), `aggregate_branches` (single file, multiple files, zero-total case).

4. **`BranchResolver`** — Tests for: file with branch data, file without branch data (returns nil), file not in coverage map (raises `FileError`), malformed branch data (raises `CorruptCoverageDataError`).

5. **`CoverageModel` branch methods** — Integration-style tests using the fixture resultset.

6. **CLI** — Tests for `--coverage-type branches` and `both` on `list`, `summary`, `detailed`, `uncovered`, `totals`; JSON output shape; `N/A` display when no branch data.

7. **MCP tools** — Tests for `coverage_type` parameter on each affected tool; backward-compat test (omitted parameter produces identical response to today).

---

## Open Questions

1. **`validate` predicate API** — Should `branch_percentage` be available on each row in the predicate context? If yes, what value does it return for files where branch data is absent (`nil` vs raising)?

2. **`raw` subcommand** — Should a `raw --coverage-type branches` mode be added to expose the raw branch hash for a file? Probably yes as a future enhancement, but not required for v1.

3. **Merging across suites** — SimpleCov's `ResultsCombiner` already merges branch data when combining multi-suite resultsets. No additional work is needed in `ResultsetLoader`, but this should be verified with a multi-suite fixture.

4. **Table width** — The `both` table with line and branch columns is wide. Consider a `--compact` flag or automatic column elision for narrow terminals as a follow-on.
