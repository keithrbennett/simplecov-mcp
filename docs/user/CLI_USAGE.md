# CLI Usage Guide

[Back to main README](../README.md)

Complete reference for using simplecov-mcp from the command line.

> Docs use `smcp` as a shortcut pointing at the demo fixture with partial coverage:
> `alias smcp='simplecov-mcp --root docs/fixtures/demo_project'`
> Replace `smcp` with `simplecov-mcp` to run commands against your own project.

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
smcp
smcp list

# Check specific file
smcp summary app/models/order.rb

# Find uncovered lines
smcp uncovered app/models/order.rb

# Get detailed per-line coverage
smcp detailed app/models/order.rb

# Get raw SimpleCov data
smcp raw app/models/order.rb

# Get project totals
smcp totals
smcp -j totals  # -j = --json

# Show version
smcp version

# Get help
smcp -h  # -h = --help
```

## Subcommands

### `list`

Show coverage summary for all files (default subcommand).

```sh
smcp list
smcp -o d list  # -o = --sort-order, d = descending
smcp -j list             # -j = --json
```

**Options:**

| Short | Long              | Description                                           |
|-------|-------------------|-------------------------------------------------------|
| `-o`  | `--sort-order`    | Sort by coverage percentage (ascending or descending) |
| `-g`  | `--tracked-globs` | Filter to specific file patterns                      |
| `-S`  | `--staleness`     | Staleness checking mode (off or error)                |
| `-j`  | `--json`          | Output as JSON                                        |

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
smcp summary app/models/order.rb
smcp summary app/models/order.rb --json
smcp summary app/models/order.rb --source full
```

**Arguments:**
- `<path>` - File path (relative to project root or absolute)

**Options:**

| Short | Long             | Description                                |
|-------|------------------|--------------------------------------------|
| `-j`  | `--json`         | Output as JSON                             |
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
smcp uncovered app/controllers/orders_controller.rb
smcp uncovered app/controllers/orders_controller.rb --source uncovered
smcp uncovered app/controllers/orders_controller.rb --source uncovered --context-lines 3
```

**Arguments:**
- `<path>` - File path (relative to project root or absolute)

**Options:**

| Short | Long                  | Description                                           |
|-------|-----------------------|-------------------------------------------------------|
| `-s`  | `--source uncovered`  | Show uncovered lines with context                     |
| `-c`  | `--context-lines N`   | Lines of context around uncovered lines (default: 2)  |
|       | `--color`             | Enable syntax coloring                                |
|       | `--no-color`          | Disable syntax coloring                               |
| `-j`  | `--json`              | Output as JSON                                        |

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
smcp detailed app/models/order.rb
smcp detailed app/models/order.rb --json
smcp detailed app/models/order.rb --source full
```

**Arguments:**
- `<path>` - File path (relative to project root or absolute)

**Options:**

| Short | Long            | Description         |
|-------|-----------------|---------------------|
| `-j`  | `--json`        | Output as JSON      |
| `-s`  | `--source MODE` | Include source code |

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
smcp raw app/models/order.rb
smcp raw app/models/order.rb --json
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
smcp totals
smcp -j totals
smcp -g "lib/ops/jobs/*.rb" totals  # -g = --tracked-globs
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
- Respects `--tracked-globs` when you only want to aggregate a subset of files.
- Honors `--staleness error` to raise if coverage data is out of date.

### `version`

Show version information.

```sh
smcp version
smcp -j version
```

**Output:**
```
SimpleCovMcp version 1.0.0
```

## Global Options

These options work with all subcommands.

### `-r, --resultset PATH`

Path to the `.resultset.json` file or a directory containing it.

For a detailed explanation of how to configure the resultset location, including the default search path, environment variables, and MCP configuration, see the [Configuring the Resultset](../README.md#configuring-the-resultset) section in the main README.

### `-R, --root PATH`

Project root directory (default: current directory).

```sh
smcp --root /path/to/project
```

### `-j, --json`

Output as JSON instead of human-readable format.

```sh
smcp summary lib/api/client.rb --json
```

Useful for:
- Parsing in scripts
- Integration with other tools
- Machine consumption

### `-o, --sort-order ORDER`

Sort order for `list` subcommand.

**Values:**
- `ascending`, `a` - Lowest coverage first (default)
- `descending`, `d` - Highest coverage first

```sh
smcp -o a list  # a = ascending
smcp -o d list  # d = descending
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
smcp -s full summary lib/api/client.rb      # -s = --source
smcp -s f summary lib/api/client.rb         # f = full

# Show only uncovered lines
smcp -s u uncovered lib/api/client.rb       # u = uncovered
```

### `-c, --context-lines N`

Number of context lines around uncovered code (for `--source uncovered`).

```sh
smcp -s u -c 3 uncovered lib/api/client.rb  # -s u = uncovered, -c = --context-lines
```

**Default:** 2 lines

### `--color` / `--no-color`

Enable or disable ANSI color codes in source output.

```sh
smcp uncovered lib/api/client.rb --source --color
smcp uncovered lib/api/client.rb --source --no-color
```

**Default:** Colors enabled if output is a TTY

### `-S, --staleness MODE`

Staleness checking mode.

**Modes:**

| Short | Long    | Description                                              |
|-------|---------|----------------------------------------------------------|
| `o`   | `off`   | Detect and mark stale files, but don't raise error (default) |
| `e`   | `error` | Detect stale files and raise error                       |

```sh
# Exit with error if coverage is stale
smcp --staleness error
smcp -S e  # Short form
```

**Staleness conditions:**
- **M** (Missing): Source file no longer exists on disk
- **T** (Timestamp): Source file modified after coverage was generated
- **L** (Length): Source file line count differs from coverage data
- Tracked files missing from coverage (with --tracked-globs)

### `-g, --tracked-globs PATTERNS`

Comma-separated glob patterns for files that should be tracked.

```sh
smcp -g "lib/payments/**/*.rb,lib/ops/jobs/**/*.rb" list  # -g = --tracked-globs
```

Used with `--staleness error` to detect new files not yet in coverage and to filter the `list`/`totals` subcommands.

### `-l, --log-file PATH`

Log file location. Use 'stdout' or 'stderr' to log to standard streams.

```sh
smcp -l /var/log/simplecov.log  # -l = --log-file
smcp -l stdout                   # Log to standard output
smcp -l stderr                   # Log to standard error
```

**Default:** `./simplecov_mcp.log`

### `--error-mode MODE`

Error handling verbosity.

**Modes:**

| Short | Long    | Description                                        |
|-------|---------|----------------------------------------------------|
|       | `off`   | Silent (no error logging)                          |
| `l`   | `log`   | Log errors without stack traces (default)          |
| `d`   | `debug` | Log errors with full stack traces                  |

```sh
smcp --error-mode debug summary lib/api/client.rb
```

### `--force-cli`

Force CLI mode even when stdin is piped or when the process is running in a non-interactive shell (CI, Codex, etc.). Without it, the executable may fall back to MCP server mode.

```sh
smcp --force-cli list
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
smcp validate examples/success_predicates/all_files_above_threshold_predicate.rb

# In CI/CD
bundle exec simplecov-mcp validate coverage_policy.rb
```

**String mode (inline code):**
```sh
# Simple inline validation
smcp validate -i '->(m) { m.all_files.all? { |f| f["percentage"] >= 80 } }'

# With global options
smcp --resultset coverage validate -i '->(m) { m.all_files.size > 0 }'
```

**Example predicate file:**
```ruby
# coverage_policy.rb
->(model) do
  model.all_files.all? { |f| f['percentage'] >= 80 }
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

### `SIMPLECOV_MCP_OPTS`

Default command-line options applied to all invocations.

**Format:** Shell-style string containing any valid CLI options

```sh
export SIMPLECOV_MCP_OPTS="--resultset coverage --json"
smcp summary lib/api/client.rb  # Automatically uses options above
```

**Precedence:** Command-line arguments override environment options

```sh
# Environment sets --json, but --no-json on command line wins
export SIMPLECOV_MCP_OPTS="--json"
smcp summary lib/api/client.rb  # Uses JSON (from env)
smcp summary lib/api/client.rb --json  # Explicit, same result
```

**Examples:**
```sh
# Default resultset location
export SIMPLECOV_MCP_OPTS="--resultset build/coverage"

# Enable detailed error logging
export SIMPLECOV_MCP_OPTS="--error-mode debug"

# Paths with spaces
export SIMPLECOV_MCP_OPTS='--resultset "/path with spaces/coverage"'

# Multiple options
export SIMPLECOV_MCP_OPTS="--resultset coverage --staleness error --json"
```



## Examples

### Basic Coverage Check

```sh
# Show all files sorted by lowest coverage first
smcp

# Find the 5 files with worst coverage
smcp list | head -10
```

### Detailed File Investigation

```sh
# Check a specific file
smcp summary lib/payments/refund_service.rb

# See which lines aren't covered
smcp uncovered lib/payments/refund_service.rb

# View uncovered code in context
smcp uncovered lib/payments/refund_service.rb --source uncovered --context-lines 3

# Get detailed hit counts
smcp detailed lib/payments/refund_service.rb
```

### JSON Output for Scripts

```sh
# Get JSON for parsing
smcp -j list > coverage.json

# Extract files below threshold
smcp -j list | jq '.files[] | select(.percentage < 80)'

# Ruby alternative:
smcp -j list | ruby -r json -e '
  JSON.parse($stdin.read)["files"].select { |f| f["percentage"] < 80 }.each do |f|
    puts JSON.pretty_generate(f)
  end
'

# Rexe alternative:
smcp -j list | rexe -ij -mb -oJ 'self["files"].select { |f| f["percentage"] < 80 }'

# Count files below 80% coverage
smcp -j list | jq '[.files[] | select(.percentage < 80)] | length'

# Ruby alternative:
smcp -j list | ruby -r json -e '
  puts JSON.parse($stdin.read)["files"].count { |f| f["percentage"] < 80 }
'

# Rexe alternative:
smcp -j list | rexe -ij -mb -op 'self["files"].count { |f| f["percentage"] < 80 }'
```

### Filtering and Sorting

```sh
# Show only lib/ files
smcp -g "lib/**/*.rb" list

# Show files sorted by highest coverage
smcp -o d list

# Check specific directory
smcp -g "lib/payments/**/*.rb" list
```



### Staleness Checking

```sh
# Check if coverage is stale (for CI/CD)
smcp --staleness error

# Check with specific file patterns
smcp --staleness error -g "lib/payments/**/*.rb,lib/ops/jobs/**/*.rb" list

# See which files are stale (don't error)
smcp list  # Stale files marked with !
```

### Source Code Display

```sh
# Show full source with coverage markers
smcp summary lib/api/client.rb --source full

# Show only uncovered lines with context
smcp uncovered lib/api/client.rb --source uncovered

# More context around uncovered code
smcp uncovered lib/api/client.rb --source uncovered --context-lines 5

# Without colors (for logging)
smcp uncovered lib/api/client.rb --source full --no-color
```

### CI/CD Integration

```sh
# Fail build if coverage is stale
smcp --staleness error || exit 1

# Generate JSON report for artifact
smcp -j list > artifacts/coverage-report.json

# Check specific directory in monorepo
smcp -R services/api -r services/api/coverage  # -R = --root, -r = --resultset
```

### Debugging

```sh
# Verbose error output
smcp --error-mode debug summary lib/api/client.rb

# Custom log file
smcp --log-file /tmp/simplecov-debug.log summary lib/api/client.rb

# Check what resultset is being used
smcp --error-mode debug 2>&1 | grep resultset
```

## Exit Codes

- `0` - Success
- `1` - Error (file not found, coverage data missing, stale coverage with `--staleness error`, etc.)

## Next Steps

- **[Library API](LIBRARY_API.md)** - Use in Ruby code
- **[Examples](EXAMPLES.md)** - More usage examples and recipes
- **[Troubleshooting](TROUBLESHOOTING.md)** - Common issues and solutions
