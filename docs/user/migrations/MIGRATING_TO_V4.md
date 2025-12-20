# V4.0 Breaking Changes Guide

[Back to main README](../../index.md)

This document describes the breaking changes introduced in version 4.0.0. These changes affect the CLI flags for mode selection and staleness checks, as well as a method rename in the Ruby API.

---

## CLI Changes

### Mode Flag Renamed & Expanded

The `--force-cli` flag has been removed and replaced with a more flexible `--force-mode` option.

*   **Old**: `--force-cli` (boolean)
*   **New**: `--force-mode` (or `-F`) taking values `cli`, `mcp`, or the default `auto`.

#### Migration
*   Replace `--force-cli` with `--force-mode cli` (or `-F cli`).
*   Use `--force-mode mcp` if you need to force MCP mode even when a TTY is detected (e.g., when running inside an AI tool that provides a TTY).

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

---

## Getting Help

If you encounter issues migrating to v4.0:

1.  Check the [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) guide.
2.  Review the [CLI_USAGE.md](../CLI_USAGE.md) for complete CLI reference.
3.  Open an issue at https://github.com/keithrbennett/cov-loupe/issues.
