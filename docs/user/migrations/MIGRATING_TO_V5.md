# Migrating to v5.0

[Back to Migration Guides](README.md)

This document describes the breaking changes introduced in version 5.0.0.

## Table of Contents

- [MCP Tool Names Renamed](#mcp-tool-names-renamed)
- [Removed `version` Subcommand](#removed-version-subcommand)
- [Simplified `--version` Output](#simplified---version-output)
- [Single-Letter Subcommand Abbreviations](#single-letter-subcommand-abbreviations)

---

## MCP Tool Names Renamed

All MCP tools that operate on a **single file** are now prefixed with `file_`, and tools that
operate on the **whole project** are prefixed with `project_`. `help_tool` and `version_tool` are
unchanged.

| v4.x name | v5.0 name |
|---|---|
| `coverage_summary_tool` | `file_coverage_summary_tool` |
| `coverage_detailed_tool` | `file_coverage_detailed_tool` |
| `coverage_raw_tool` | `file_coverage_raw_tool` |
| `uncovered_lines_tool` | `file_uncovered_lines_tool` |
| `list_tool` | `project_coverage_list_tool` |
| `coverage_totals_tool` | `project_coverage_totals_tool` |
| `coverage_table_tool` | `project_coverage_table_tool` |
| `validate_tool` | `project_validate_tool` |

Update any MCP client configurations, tool-call strings in prompts, or direct JSON-RPC requests
that reference the old names.

---

## Removed `version` Subcommand

The `version` subcommand has been removed. Any scripts calling `cov-loupe version` must be updated.

**Before (v4.x):**
```sh
cov-loupe version
cov-loupe --format json version
```

**After (v5.0):**
```sh
cov-loupe --version   # or: cov-loupe -v
```

---

## Simplified `--version` Output

`-v`/`--version` now prints only the bare version string and exits immediately. The former table output (with `Gem Root` and `Documentation` fields) and JSON format option are gone.

**Before (v4.x):**
```
┌───────────────┬────────────────────────────────────────┐
│ Version       │ 4.1.0                                  │
│ Gem Root      │ /path/to/gem                           │
│ Documentation │ README.md and docs/user/**/*.md …      │
└───────────────┴────────────────────────────────────────┘
```

**After (v5.0):**
```
5.0.0
```

If you need the gem root path, use `cov-loupe --path-for docs-local` to locate the local documentation, or inspect the gem installation with `gem contents cov-loupe`.

---

## Single-Letter Subcommand Abbreviations

All CLI subcommands can now be abbreviated to their first letter for convenience.

**Before (v4.x):**
```sh
cov-loupe list
cov-loupe summary lib/foo.rb
cov-loupe uncovered lib/foo.rb
cov-loupe validate -i "model.list.all?"
```

**After (v5.0):**
```sh
cov-loupe l
cov-loupe s lib/foo.rb
cov-loupe u lib/foo.rb
cov-loupe v -i "model.list.all?"
```

Available abbreviations: `l` (list), `s` (summary), `r` (raw), `u` (uncovered), `d` (detailed), `t` (totals), `v` (validate).
