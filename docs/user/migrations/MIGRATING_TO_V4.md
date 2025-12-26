# V4.0 Breaking Changes Guide

[Back to main README](../../index.md)

This document describes the breaking changes introduced in version 4.0.0. These changes affect the CLI flags for mode selection and staleness checks, as well as a method rename in the Ruby API.

---

## CLI Changes

### ⚠️ MCP Mode Now Requires Explicit `-m/--mode mcp` Flag

**BREAKING**: Automatic mode detection has been removed. 
The `-m/--mode mcp` flag is now **required** to run cov-loupe as an MCP server.

#### Previous Behavior (v3.x)
- cov-loupe automatically detected MCP mode based on TTY/stdin status
- `--force-mode` could override detection (values: `cli`, `mcp`, `auto`)

#### New Behavior (v4.x)
- **No automatic detection** - mode defaults to `cli`
- `-m mcp` or `--mode mcp` is **required** for MCP server mode
- Accepted values: `cli` (default) or `mcp`

#### Migration for MCP Users

**If you use cov-loupe as an MCP server, you MUST update your configuration:**

1. **Remove the old entry** (see [MCP Integration Guide - Setup by Client](../MCP_INTEGRATION.md#setup-by-client)
for removal commands with proper `--scope` options)
2. **Add the new entry with `-m mcp` flag:**

```sh
# Claude Code
claude mcp add cov-loupe cov-loupe -- -m mcp

# Codex
codex mcp add cov-loupe cov-loupe -m mcp

# Gemini
gemini mcp add cov-loupe cov-loupe -- -m mcp
```

**Without `-m mcp` or `--mode mcp`, the server will run in CLI mode and hang waiting for subcommands.**

#### Migration for CLI Users

CLI users are unaffected. The default mode is `cli`, so no changes are needed. However:
- `--force-cli` removed → use `-m cli` or `--mode cli` if you need to be explicit (rare)
- `--force-mode` removed → use `-m/--mode` instead

### Unified Stale Coverage Enforcement

The staleness checking logic has been unified into a single flag that raises an error if *any* staleness is detected.

*   **Old**: `--staleness` / `check_stale` (inconsistent behavior)
*   **New**: `--raise-on-stale` (boolean)

#### Behavior
*   **`--raise-on-stale true` (or `raise_on_stale: true`)**: The command will exit with an error code if any file in the result set is stale or if the project totals are stale.
*   **Default (false)**: Staleness is reported in the output (e.g., status `M`, `T`, `L`), but the command returns success (unless other errors occur).

#### Migration
*   If you relied on previous flags to enforce staleness checks, switch to `--raise-on-stale true` or `-S true`.

**IMPORTANT:** As of v4.0.0, boolean flags now require explicit values for consistency.

### `--raise-on-stale` / `-S` - Explicit Value Required
*   **Old (no longer works)**: `--raise-on-stale`, `-S`
*   **New (required)**: `--raise-on-stale true`, `-S true`, `--raise-on-stale=yes`, etc.

### `--color` / `-C` - Explicit Value Required
*   **Old (no longer works)**: `--color`, `-C`
*   **New (required)**: `--color true`, `-C true`, `--color=on`, etc.

These changes improve consistency between short and long flag forms and eliminate ambiguous behavior where long-form bare flags would fail but short-form bare flags would succeed.

## Ruby API Changes

### CoverageLineResolver Now Requires `root:`

**Breaking Change**: `CovLoupe::Resolvers::CoverageLineResolver` now requires a `root:` keyword argument, and `CovLoupe::Resolvers::ResolverHelpers.lookup_lines` / `create_coverage_resolver` now require `root:` as well.

#### Migration
```ruby
# Old
resolver = CovLoupe::Resolvers::CoverageLineResolver.new(cov_data)
lines = CovLoupe::Resolvers::ResolverHelpers.lookup_lines(cov_data, abs_path)

# New
resolver = CovLoupe::Resolvers::CoverageLineResolver.new(cov_data, root: root)
lines = CovLoupe::Resolvers::ResolverHelpers.lookup_lines(cov_data, abs_path, root: root)
```

### Method Renamed

*   **Old**: `CoverageModel#all_files_coverage`
*   **New**: `CoverageModel#list`

### Return Type Changed: `list` Now Returns a Hash

**Breaking Change**: `CoverageModel#list` now returns a **hash** containing comprehensive staleness information instead of just an array of file data.

#### Old Behavior (v3.x)
```ruby
model = CovLoupe::CoverageModel.new(root: '.')
files = model.list  # Returns array directly

# Filter and use the array
low_coverage = files.select { |f| f['percentage'] < 80 }
model.format_table(files)
```

#### New Behavior (v4.x)
```ruby
model = CovLoupe::CoverageModel.new(root: '.')
result = model.list  # Returns hash with multiple keys

# Access the files array
files = result['files']

# Filter and use the array
low_coverage = files.select { |f| f['percentage'] < 80 }
model.format_table(files)

# Access new staleness information
result['skipped_files']          # Files that raised errors during processing
result['missing_tracked_files']  # Files from tracked_globs not in coverage
result['newer_files']             # Files modified after coverage was generated
result['deleted_files']           # Files in coverage that no longer exist
```

#### Migration Steps

**Option 1: Quick Fix (Extract files array)**
```ruby
# Old
files = model.list

# New
files = model.list['files']
```

**Option 2: Leverage New Staleness Data**
```ruby
result = model.list

# Use the files array as before
files = result['files']
low_coverage = files.select { |f| f['percentage'] < 80 }

# Now you can also:
if result['skipped_files'].any?
  warn "Warning: #{result['skipped_files'].size} files were skipped due to errors"
  result['skipped_files'].each do |skip|
    warn "  #{skip['file']}: #{skip['error']}"
  end
end

if result['newer_files'].any?
  warn "Warning: #{result['newer_files'].size} files are newer than coverage data"
end
```

#### Impact on `format_table`

The `format_table` method still accepts an array of file hashes (not the full hash from `list`):

```ruby
# Correct
files = model.list['files']
table = model.format_table(files)

# Also correct (passing nil gets all files)
table = model.format_table(nil)

# Incorrect - do not pass the full hash
result = model.list
table = model.format_table(result)  # This will fail
```

### Logger Initialization Changed

The `CovLoupe::Logger` class has updated its `initialize` signature.

*   **Old**: `initialize(target:, mcp_mode: false)`
*   **New**: `initialize(target:, mode: :library)` # or :cli or :mcp

#### Migration

If you are manually instantiating `CovLoupe::Logger`:

```ruby
# Old
logger = CovLoupe::Logger.new(target: 'cov_loupe.log', mcp_mode: true)
logger = CovLoupe::Logger.new(target: 'cov_loupe.log', mcp_mode: false)

# New
logger = CovLoupe::Logger.new(target: 'cov_loupe.log', mode: :mcp)
logger = CovLoupe::Logger.new(target: 'cov_loupe.log', mode: :cli)     # or :library
```

## Deleted Files Now Raise `FileNotFoundError`

**Breaking Change**: Querying a file that has been deleted (but still exists in the coverage resultset) now raises `FileNotFoundError` instead of returning stale coverage data.

### Previous Behavior (v3.x)
```ruby
# File lib/foo.rb was deleted after running tests
model = CovLoupe::CoverageModel.new(root: '.')
result = model.summary_for('lib/foo.rb')
# => { 'file' => '/path/to/lib/foo.rb', 'summary' => { 'covered' => 4, 'total' => 6, 'percentage' => 66.67 } }
# Returns stale coverage data with no error
```

```sh
# CLI would return coverage percentage and exit 0
$ cov-loupe summary lib/foo.rb
lib/foo.rb: 66.67% (4/6)
$ echo $?
0
```

### New Behavior (v4.x)
```ruby
# File lib/foo.rb was deleted after running tests
model = CovLoupe::CoverageModel.new(root: '.')
result = model.summary_for('lib/foo.rb')
# => raises CovLoupe::FileNotFoundError: "File not found: lib/foo.rb"
```

```sh
# CLI raises error and exits 1
$ cov-loupe summary lib/foo.rb
Error: File not found: lib/foo.rb
$ echo $?
1
```

### Rationale

Deleted files represent **stale data** that:
1. Misleads coverage metrics and statistics
2. Violates the API contract (docstring already promised `FileNotFoundError`)
3. Should be treated the same as other staleness issues

If a file no longer exists, its coverage data is no longer meaningful. The new behavior ensures you don't accidentally include deleted file coverage in your metrics.

### Impact

This affects:
- `model.summary_for(path)` - All single-file query methods
- `model.raw_for(path)`
- `model.uncovered_for(path)`
- `model.detailed_for(path)`
- CLI commands: `summary`, `raw`, `uncovered`, `detailed`
- MCP tools: `coverage_summary_tool`, `coverage_raw_tool`, etc.

### Migration

**If you expect deleted files to raise errors** (recommended):
- No action needed. This is the correct behavior.

**If you relied on getting coverage for deleted files**:
- This was incorrect behavior. Update your workflow to:
  1. Re-run tests after file deletions to get fresh coverage, OR
  2. Use the `list` command to see deleted files in the `deleted_files` array without querying them directly

**Example: Checking for deleted files**
```ruby
model = CovLoupe::CoverageModel.new(root: '.')
result = model.list

if result['deleted_files'].any?
  puts "Warning: Coverage data exists for deleted files:"
  result['deleted_files'].each { |f| puts "  - #{f}" }
end
```

---

## Removed Branch-Only Coverage Support

**Breaking Change**: The automatic synthesis of line coverage data from SimpleCov branch-only coverage results has been removed.

### Rationale
The logic required to maintain this feature was complex and prone to edge cases, particularly regarding staleness detection and line-count mismatches. Additionally, branch-only coverage is a rarely used configuration in the SimpleCov ecosystem.

### Impact
If your project is configured to track **only** branch coverage in SimpleCov (e.g., `enable_coverage :branch` without also tracking lines), `cov-loupe` will no longer be able to process your coverage data and will raise a `CorruptCoverageDataError`.

### How to Migrate
Most users do not need to take any action. Line coverage is enabled by default in SimpleCov.

If you have `enable_coverage :branch` in your configuration, your `.resultset.json` contains both `lines` and `branches` data. **This is fully supported.** `cov-loupe` will read and report the `lines` coverage as usual.

The change in v4.0 is simply that `cov-loupe` no longer looks at the `branches` data at all. Previously, if `lines` data was missing (a rare edge case), `cov-loupe` would attempt to calculate line coverage by summing up branch hits. This fallback logic has been removed.

---

## Getting Help

If you encounter issues migrating to v4.0:

1.  Check the [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) guide.
2.  Review the [CLI_USAGE.md](../CLI_USAGE.md) for complete CLI reference.
3.  Open an issue at https://github.com/keithrbennett/cov-loupe/issues.
