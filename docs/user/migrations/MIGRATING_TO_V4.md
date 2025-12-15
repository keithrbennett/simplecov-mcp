# V4.0 Breaking Changes Guide

[Back to main README](../../README.md)

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

#### Migration
*   Update any Ruby scripts or integrations that call `all_files_coverage` to call `list` instead. The return value and behavior remain the same.

---

## Getting Help

If you encounter issues migrating to v4.0:

1.  Check the [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) guide.
2.  Review the [CLI_USAGE.md](../CLI_USAGE.md) for complete CLI reference.
3.  Open an issue at https://github.com/keithrbennett/cov-loupe/issues.
