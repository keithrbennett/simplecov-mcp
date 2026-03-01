# Migrating to v5.0

[Back to Migration Guides](README.md)

This document describes the breaking changes introduced in version 5.0.0.

## Table of Contents

- [Removed `version` Subcommand](#removed-version-subcommand)
- [Simplified `--version` Output](#simplified---version-output)
- [Single-Letter Subcommand Abbreviations](#single-letter-subcommand-abbreviations)

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
