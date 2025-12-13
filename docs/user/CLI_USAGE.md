# CLI Usage Guide

[Back to main README](../README.md)

Complete reference for using cov-loupe from the command line.

> Docs use `clp` as a shortcut pointing at the demo fixture with partial coverage:
> `alias clp='cov-loupe -R docs/fixtures/demo_project'`  # -R = --root
> Replace `clp` with `cov-loupe` to run commands against your own project.

## Table of Contents

- [Quick Reference](#quick-reference)
- [Subcommands](#subcommands)
- [Global Options](#global-options)
- [Output Formats](#output-formats)
- [Environment Variables](#environment-variables)
- [Examples](#examples)

## Quick Reference

```sh
# Show coverage table for all files
clp
clp list

# Check specific file
clp summary app/models/order.rb

# Find uncovered lines
clp uncovered app/models/order.rb

# Get detailed per-line coverage
clp detailed app/models/order.rb

# Get raw SimpleCov data
clp raw app/models/order.rb

# Get project totals
clp totals
clp -fJ totals

# Show version
clp version

# Get help
clp -h  # -h = --help
```

## Subcommands

### `list`

Show coverage summary for all files (default subcommand).

```sh
clp list
clp -o d list  # -o = --sort-order, d = descending
clp -fJ list           
```

Default sort order is descending (highest coverage first) so the lowest-coverage files stay visible at the bottom of the scrollback.

**Options:**

| Short   | Long                     | Description                                           |
|---------|--------------------------|-------------------------------------------------------|
| `-o`    | `--sort-order`           | Sort by coverage percentage (ascending or descending) |
| `-g`    | `--tracked-globs`        | Filter to specific file patterns                      |
| `-S`    | `--raise-on-stale`       | Raise error if coverage is stale (default false)      |
| `-fJ`   | `--format pretty-json`   | Output as pretty-printed JSON                         |
| `-fj`   | `--format json`          | Output as single-line JSON                            |
| `-f y`  | `--format yaml`          | Output as YAML                                        |
| `-f ap` | `--format awesome_print` | Output using AwesomePrint                             |

**Output (table format):**
```
┌────────────────────────────────────────┬──────────┬───────────┬─────────┬───────┐
│ File                                   │        % │   Covered │   Total │ Stale │
├────────────────────────────────────────┼──────────┼───────────┼─────────┼───────┤
│ lib/payments/refund_service.rb         │   60.00% │         3 │       5 │       │
│ app/controllers/orders_controller.rb   │   70.00% │         7 │      10 │       │
│ lib/ops/jobs/report_job.rb             │   80.00% │         4 │       5 │       │
│ lib/payments/processor.rb              │   80.00% │         4 │       5 │       │
│ app/models/order.rb                    │   85.71% │         6 │       7 │       │
│ lib/api/client.rb                      │   88.89% │         8 │       9 │       │
│ app/models/user.rb                     │  100.00% │         6 │       6 │       │
└────────────────────────────────────────┴──────────┴───────────┴─────────┴───────┘
Files: total 7, ok 7, stale 0
```

**Stale indicators:** M (missing file), T (timestamp mismatch), L (line count mismatch)

### `summary <path>`

Show covered/total/percentage for a specific file.

```sh
clp summary app/models/order.rb
clp summary app/models/order.rb -fJ
clp summary app/models/order.rb -s full  # -s = --source
```

**Arguments:**
- `<path>` - File path (relative to project root or absolute)

**Options:**

| Short | Long             | Description                                |
|-------|------------------|--------------------------------------------|
| `-fJ` | `--format pretty-json` | Output as pretty-printed JSON         |
| `-fj` | `--format json`        | Output as single-line JSON            |
| `-f y` | `--format yaml`        | Output as YAML                        |
| `-f ap` | `--format awesome_print` | Output using AwesomePrint         |
| `-s`  | `--source MODE`  | Include source code (full or uncovered)    |

**Output (default format):**
```
  85.71%       6/7       app/models/order.rb
```

**Output (JSON format):**
```json
{
  "file": "app/models/order.rb",
  "summary": {
    "covered": 6,
    "total": 7,
    "percentage": 85.71
  },
  "stale": false
}
```

### `uncovered <path>`

Show uncovered line numbers for a specific file.

```sh
clp uncovered app/controllers/orders_controller.rb
clp uncovered app/controllers/orders_controller.rb -s uncovered  # -s = --source
clp uncovered app/controllers/orders_controller.rb -s uncovered -c 3  # -c = --context-lines
```

**Arguments:**
- `<path>` - File path (relative to project root or absolute)

**Options:**

| Short   | Long                     | Description                                          |
|---------|--------------------------|------------------------------------------------------|
| `-s`    | `--source uncovered`     | Show uncovered lines with context                    |
| `-c`    | `--context-lines N`      | Lines of context around uncovered lines (default: 2) |
| `-C`    | `--color [BOOLEAN]`      | Enable (`true`)/disable (`false`) syntax coloring    |
| `-fJ`   | `--format pretty-json`   | Output as pretty-printed JSON                        |
| `-fj`   | `--format json`          | Output as single-line JSON                           |
| `-f y`  | `--format yaml`          | Output as YAML                                       |
| `-f ap` | `--format awesome_print` | Output using AwesomePrint                            |

**Output (default format):**
```
File:            app/controllers/orders_controller.rb
Uncovered lines: 14, 15, 20
Summary:         70.0%      7/10
```

**Output (with source):**
```
File:            app/controllers/orders_controller.rb
Uncovered lines: 14, 15, 20
Summary:         70.0%      7/10

  Line     | Source
  ------+-----------------------------------------------------------
    14  · |       def show(id)
    15  · |         @repo.find(id)
    16  ✓ |       end
    17    |
    18  ✓ |       def cancel(id)
    19  ✓ |         order = @repo.find(id)
    20  · |         return :missing unless order
```

**Legend:**
- `✓` - Line is covered
- `·` - Line is not covered
- ` ` - Line is not executable (comments, blank lines)

### `detailed <path>`

Show per-line coverage with hit counts.

```sh
clp detailed app/models/order.rb
clp detailed app/models/order.rb -fJ
clp detailed app/models/order.rb -s full  # -s = --source
```

**Arguments:**
- `<path>` - File path (relative to project root or absolute)

**Options:**

| Short   | Long                     | Description                   |
|---------|--------------------------|-------------------------------|
| `-fJ`   | `--format pretty-json`   | Output as pretty-printed JSON |
| `-fj`   | `--format json`          | Output as single-line JSON    |
| `-f y`  | `--format yaml`          | Output as YAML                |
| `-f ap` | `--format awesome_print` | Output using AwesomePrint     |
| `-s`    | `--source MODE`          | Include source code           |

**Output (default format):**
```
File: app/models/order.rb
  Line    Hits  Covered
 -----    ----  -------
     6       1    yes
     7       1    yes
     8       1    yes
    11       1    yes
    12       1    yes
    15       1    yes
    16       0     no
```

**Output (JSON format):**
```json
{
  "file": "app/models/order.rb",
  "lines": [
    { "line": 6, "hits": 1, "covered": true },
    { "line": 7, "hits": 1, "covered": true },
    { "line": 8, "hits": 1, "covered": true },
    { "line": 11, "hits": 1, "covered": true },
    { "line": 12, "hits": 1, "covered": true },
    { "line": 15, "hits": 1, "covered": true },
    { "line": 16, "hits": 0, "covered": false }
  ],
  "summary": {
    "covered": 6,
    "total": 7,
    "percentage": 85.71
  },
  "stale": false
}
```

### `raw <path>`

Show the raw SimpleCov lines array.

```sh
clp raw app/models/order.rb
clp raw app/models/order.rb -fJ
```

**Arguments:**
- `<path>` - File path (relative to project root or absolute)

**Output (default format):**
```
File: app/models/order.rb
[nil, nil, nil, nil, nil, 1, 1, 1, nil, nil, 1, 1, nil, nil, 1, 0, nil, nil, nil, nil]
```

**Output (JSON format):**
```json
{
  "file": "app/models/order.rb",
  "lines": [null, null, null, null, null, 1, 1, 1, null, null, 1, 1, null, null, 1, 0, null, null, null, null],
  "stale": false
}
```

**Array explanation:**
- Integer (e.g., `1`, `5`) - Number of times line was executed
- `0` - Line is executable but was not executed
- `null` - Line is not executable (comment, blank line)

### `totals`

Show aggregated totals for all tracked files.

```sh
clp totals
clp -fJ totals
clp -g "lib/ops/jobs/*.rb" totals  # -g = --tracked-globs
```

**Output (default format):**
```
Lines: total 47       covered 38       uncovered 9
Average coverage:  80.85% across 7 files (ok: 7, stale: 0)
```

**Output (JSON format):**
```json
{
  "lines": { "total": 47, "covered": 38, "uncovered": 9 },
  "percentage": 80.85,
  "files": { "total": 7, "ok": 7, "stale": 0 }
}
```

**Notes:**
- Respects `-g` / `--tracked-globs` when you only want to aggregate a subset of files.
- Honors `-S` / `--raise-on-stale` to raise if coverage data is out of date.

### `version`

Show version information.

```sh
clp version
clp -fJ version
```

**Output:**
```
CovLoupe version 1.0.0
```

## Global Options

These options work with all subcommands.

### `-r, --resultset PATH`

Path to the `.resultset.json` file or a directory containing it.

For a detailed explanation of how to configure the resultset location, including the default search path, environment variables, and MCP configuration, see the [Configuring the Resultset](../README.md#configuring-the-resultset) section in the main README.

### `-R, --root PATH`

Project root directory (default: current directory).

```sh
clp -R /path/to/project  # -R = --root
```

### `-fJ`

Output as pretty-printed JSON instead of human-readable format.

```sh
clp summary lib/api/client.rb -fJ
```

Useful for:
- Parsing in scripts
- Integration with other tools
- Machine consumption

### `-o, --sort-order ORDER`

Sort order for `list` subcommand.

**Values:**
- `descending`, `d` - Highest coverage first (default)
- `ascending`, `a` - Lowest coverage first

```sh
clp -o d list  # d = descending (default)
clp -o a list  # a = ascending
```

### `-s, --source MODE`

Include source code in output.

**Modes:**

| Short | Long        | Description                                         |
|-------|-------------|-----------------------------------------------------|
| `f`   | `full`      | Show all source lines                               |
| `u`   | `uncovered` | Show only uncovered lines with context              |

```sh
# Show full source
clp -s full summary lib/api/client.rb      # -s = --source
clp -s f summary lib/api/client.rb         # f = full

# Show only uncovered lines
clp -s u uncovered lib/api/client.rb       # u = uncovered
```

### `-c, --context-lines N`

Number of context lines around uncovered code (for `-s uncovered` / `--source uncovered`). Must be a non-negative integer.

```sh
clp -s u -c 3 uncovered lib/api/client.rb  # -s u = uncovered, -c = --context-lines
```

**Default:** 2 lines

### Boolean Flags (`--color` / `-C`, `--raise-on-stale`)

These options accept explicit `[BOOLEAN]` values. A bare flag sets the value to `true`. Recognized literals:

| true   | false   |
|--------|---------|
| `yes`  | `no`    |
| `y`    | `n`     |
| `true` | `false` |
| `t`    | `f`     |
| `on`   | `off`   |
| `+`    | `-`     |
| `1`    | `0`     |

```sh
clp --color false           # disable color
clp --raise-on-stale yes    # enforce stale coverage failures
```

### `-C, --color [BOOLEAN]`

Enable or disable ANSI color codes in source output.

```sh
clp uncovered lib/api/client.rb -s uncovered --color
clp uncovered lib/api/client.rb -s uncovered -C false
```

**Default:** Colors enabled if output is a TTY

### `-S, --raise-on-stale [BOOLEAN]`

Raise error if coverage is stale. Default is `false` (only report staleness in output).

*   Use `--raise-on-stale` or `-S` to enable (set to `true`).
*   Use `--raise-on-stale false` to explicitly disable (set to `false`).

```sh
# Enable raising an error if coverage is stale
clp -S              # Short form
clp --raise-on-stale

# Explicitly disable raising an error (useful to override COV_LOUPE_OPTS)
clp --raise-on-stale false
```

**Staleness conditions:**
- **M** (Missing): Source file no longer exists on disk
- **T** (Timestamp): Source file modified after coverage was generated
- **L** (Length): Source file line count differs from coverage data
- Tracked files missing from coverage (with --tracked-globs)

### `-g, --tracked-globs PATTERNS`

Comma-separated glob patterns for files that should be tracked.

```sh
clp -g "lib/payments/**/*.rb,lib/ops/jobs/**/*.rb" list  # -g = --tracked-globs
```

Used with `-S` / `--raise-on-stale` to detect new files not yet in coverage and to filter the `list`/`totals` subcommands.

### `-l, --log-file PATH`

Log file location. Use 'stdout' or 'stderr' to log to standard streams.

```sh
clp -l /var/log/simplecov.log  # -l = --log-file
clp -l stdout                   # Log to standard output
clp -l stderr                   # Log to standard error
```

**Default:** `./cov_loupe.log`

### `--error-mode MODE`

Error handling verbosity.

**Modes:**

| Short | Long    | Description                                        |
|-------|---------|----------------------------------------------------|
|       | `off`   | Silent (no error logging)                          |
| `l`   | `log`   | Log errors without stack traces (default)          |
| `d`   | `debug` | Log errors with full stack traces                  |

```sh
clp --error-mode debug summary lib/api/client.rb
```

### `-F, --force-mode MODE`

Force execution mode explicitly: `cli`, `mcp`, or `auto` (default detection). Use `cli` when you want table/JSON output even if stdin is non-TTY; use `mcp` when your client allocates a TTY but you need the MCP server. The old `--force-cli` flag was removed in 4.0.0; use `--force-mode cli` instead.

```sh
clp -F cli list          # force CLI output
clp --force-mode mcp      # force MCP server even on a TTY client
```

### `validate` Subcommand

Validate coverage against custom policies for CI/CD enforcement.

> **⚠️ SECURITY WARNING**
>
> Validation predicates execute as **arbitrary Ruby code with full system privileges**. They have unrestricted access
> to file system, network, system commands, and environment variables.
>
> **Only use predicate files from trusted sources.**
> Review predicates before use, especially in CI/CD environments.

The predicate must be a callable (lambda, proc, or object with `#call` method) that receives a `CoverageModel` and returns `true` or `false`.

**Predicate return values:**
- `true` - Coverage meets your criteria (CLI exits with code 0)
- `false` - Coverage fails your criteria (CLI exits with code 1)
- Exception raised - Predicate error (CLI exits with code 2)

**File mode (most common):**
```sh
# Use example predicate
clp validate examples/success_predicates/all_files_above_threshold_predicate.rb

# In CI/CD
bundle exec cov-loupe validate coverage_policy.rb
```

**String mode (inline code):**
```sh
# Simple inline validation
clp validate -i '->(m) { m.list.all? { |f| f["percentage"] >= 80 } }'

# With global options
clp -r coverage validate -i '->(m) { m.list.size > 0 }'
```

**Example predicate file:**
```ruby
# coverage_policy.rb
->(model) do
  model.list.all? { |f| f['percentage'] >= 80 }
end
```

See [examples/success_predicates/](../../examples/success_predicates/) for more examples.

## Output Formats

### Table Format

Default for `list` subcommand. Uses Unicode box-drawing characters.

```
┌──────────────────────────────────┬──────────┬───────────┬─────────┬───────┐
│ File                             │        % │   Covered │   Total │ Stale │
├──────────────────────────────────┼──────────┼───────────┼─────────┼───────┤
│ lib/payments/refund_service.rb   │   60.00% │         3 │       5 │       │
└──────────────────────────────────┴──────────┴───────────┴─────────┴───────┘
```

### JSON Format

Machine-readable output. Paths are relative to project root.

```json
{
  "file": "app/models/order.rb",
  "summary": {
    "covered": 6,
    "total": 7,
    "percentage": 85.71
  },
  "stale": false
}
```

**Staleness values:**
- `false` - Coverage data is current
- `"M"` - File missing (no longer exists on disk)
- `"T"` - Timestamp mismatch (file modified after coverage)
- `"L"` - Length mismatch (line count differs)

### Source Display

With `--source` flag, shows annotated source code:

```
  Line     | Source
  ------+-----------------------------------------------------------
     1  ✓ | class User
     2  · |   def initialize  # Not covered
     3  ✓ |     # ...
```

## Environment Variables

### `COV_LOUPE_OPTS`

Default command-line options applied to all invocations.

**Format:** Shell-style string containing any valid CLI options

```sh
export COV_LOUPE_OPTS="--resultset coverage -fJ"
clp summary lib/api/client.rb  # Automatically uses options above
```

**Precedence:** Command-line arguments override environment options

```sh
# Environment sets -fJ; explicit CLI options still take precedence
export COV_LOUPE_OPTS="-fJ"
clp summary lib/api/client.rb  # Uses JSON (from env)
clp summary lib/api/client.rb -f table  # Explicit override to table format
```

**Examples:**
```sh
# Default resultset location
export COV_LOUPE_OPTS="-r build/coverage"

# Enable detailed error logging
export COV_LOUPE_OPTS="--error-mode debug"

# Paths with spaces
export COV_LOUPE_OPTS='-r "/path with spaces/coverage"'

# Multiple options
export COV_LOUPE_OPTS="-r coverage -S -fJ"
```



## Examples

### Basic Coverage Check

```sh
# Show all files sorted by lowest coverage first
clp

# Find the 5 files with worst coverage
clp list | head -10
```

### Detailed File Investigation

```sh
# Check a specific file
clp summary lib/payments/refund_service.rb

# See which lines aren't covered
clp uncovered lib/payments/refund_service.rb

# View uncovered code in context
clp uncovered lib/payments/refund_service.rb -s uncovered -c 3

# Get detailed hit counts
clp detailed lib/payments/refund_service.rb
```

### JSON Output for Scripts

```sh
# Get JSON for parsing
clp -fJ list > coverage.json

# Extract files below threshold
clp -fJ list | jq '.files[] | select(.percentage < 80)'

# Ruby alternative:
clp -fJ list | ruby -r json -e '
  JSON.parse($stdin.read)["files"].select { |f| f["percentage"] < 80 }.each do |f|
    puts JSON.pretty_generate(f)
  end
'

# Rexe alternative:
clp -fJ list | rexe -ij -mb -oJ 'self["files"].select { |f| f["percentage"] < 80 }'

# Count files below 80% coverage
clp -fJ list | jq '[.files[] | select(.percentage < 80)] | length'

# Ruby alternative:
clp -fJ list | ruby -r json -e '
  puts JSON.parse($stdin.read)["files"].count { |f| f["percentage"] < 80 }
'

# Rexe alternative:
clp -fJ list | rexe -ij -mb -op 'self["files"].count { |f| f["percentage"] < 80 }'
```

### Filtering and Sorting

```sh
# Show only lib/ files
clp -g "lib/**/*.rb" list

# Show files sorted by highest coverage
clp -o d list

# Check specific directory
clp -g "lib/payments/**/*.rb" list
```



### Staleness Checking

```sh
# Check if coverage is stale (for CI/CD)
clp -S

# Check with specific file patterns
clp -S -g "lib/payments/**/*.rb,lib/ops/jobs/**/*.rb" list

# See which files are stale (don't error)
clp list  # Stale files marked with !
```

### Source Code Display

```sh
# Show full source with coverage markers
clp summary lib/api/client.rb -s full

# Show only uncovered lines with context
clp uncovered lib/api/client.rb -s uncovered

# More context around uncovered code
clp uncovered lib/api/client.rb -s uncovered -c 5

# Without colors (for logging)
clp uncovered lib/api/client.rb -s full --color false
```

### CI/CD Integration

```sh
# Fail build if coverage is stale
clp -S || exit 1

# Generate JSON report for artifact
clp -fJ list > artifacts/coverage-report.json

# Check specific directory in monorepo
clp -R services/api -r services/api/coverage  # -R = --root, -r = --resultset
```

### Debugging

```sh
# Verbose error output
clp --error-mode debug summary lib/api/client.rb

# Custom log file (--log-file or -l)
clp -l /tmp/simplecov-debug.log summary lib/api/client.rb

# Check what resultset is being used
clp --error-mode debug 2>&1 | grep resultset
```

## Exit Codes

- `0` - Success
- `1` - Error (file not found, coverage data missing, stale coverage with `-S` / `--raise-on-stale`, etc.)

## Next Steps

- **[Library API](LIBRARY_API.md)** - Use in Ruby code
- **[Examples](EXAMPLES.md)** - More usage examples and recipes
- **[Troubleshooting](TROUBLESHOOTING.md)** - Common issues and solutions
