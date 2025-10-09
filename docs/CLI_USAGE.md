# CLI Usage Guide

Complete reference for using simplecov-mcp from the command line.

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
simplecov-mcp
simplecov-mcp list

# Check specific file
simplecov-mcp summary lib/simplecov_mcp/model.rb

# Find uncovered lines
simplecov-mcp uncovered lib/simplecov_mcp/model.rb

# Get detailed per-line coverage
simplecov-mcp detailed lib/simplecov_mcp/model.rb

# Get raw SimpleCov data
simplecov-mcp raw lib/simplecov_mcp/model.rb

# Show version
simplecov-mcp version

# Get help
simplecov-mcp --help
```

## Subcommands

### `list`

Show coverage summary for all files (default subcommand).

```sh
simplecov-mcp list
simplecov-mcp list --sort-order descending
simplecov-mcp list --json
```

**Options:**
- `--sort-order` - Sort by coverage percentage (ascending or descending)
- `--tracked-globs` - Filter to specific file patterns
- `--stale` - Check for stale coverage
- `--json` - Output as JSON

**Output (table format):**
```
┌──────────────────────────────────────────────────────────┬──────────┬──────────┬────────┬───────┐
│ File                                                     │        % │  Covered │  Total │ Stale │
├──────────────────────────────────────────────────────────┼──────────┼──────────┼────────┼───────┤
│ lib/simplecov_mcp/tools/coverage_summary_tool.rb        │    85.71 │       12 │     14 │       │
│ lib/services/auth.rb                                     │    92.31 │       12 │     13 │   !   │
│ lib/controllers/api.rb                                   │   100.00 │        8 │      8 │       │
└──────────────────────────────────────────────────────────┴──────────┴──────────┴────────┴───────┘
Files: total 3, ok 2, stale 1
```

### `summary <path>`

Show covered/total/percentage for a specific file.

```sh
simplecov-mcp summary lib/simplecov_mcp/model.rb
simplecov-mcp summary lib/simplecov_mcp/model.rb --json
simplecov-mcp summary lib/simplecov_mcp/model.rb --source
```

**Arguments:**
- `<path>` - File path (relative to project root or absolute)

**Options:**
- `--json` - Output as JSON
- `--source[=MODE]` - Include source code (full or uncovered)

**Output (default format):**
```
  85.71%      12/14      lib/simplecov_mcp/model.rb
```

**Output (JSON format):**
```json
{
  "file": "lib/simplecov_mcp/model.rb",
  "summary": {
    "covered": 12,
    "total": 14,
    "pct": 85.71
  },
  "stale": false
}
```

### `uncovered <path>`

Show uncovered line numbers for a specific file.

```sh
simplecov-mcp uncovered lib/simplecov_mcp/model.rb
simplecov-mcp uncovered lib/simplecov_mcp/model.rb --source=uncovered
simplecov-mcp uncovered lib/simplecov_mcp/model.rb --source=uncovered --source-context 3
```

**Arguments:**
- `<path>` - File path (relative to project root or absolute)

**Options:**
- `--source=uncovered` - Show uncovered lines with context
- `--source-context N` - Lines of context around uncovered lines (default: 2)
- `--color` / `--no-color` - Enable/disable syntax coloring
- `--json` - Output as JSON

**Output (default format):**
```
File:            lib/simplecov_mcp/model.rb
Uncovered lines: 5, 9, 12, 18, 23
Summary:        85.71%     12/14
```

**Output (with source):**
```
File:            lib/simplecov_mcp/model.rb
Uncovered lines: 5, 9, 12
Summary:        85.71%     12/14

  Line     | Source
  ------+-----------------------------------------------------------
     3  ✓ | def initialize(name)
     4  ✓ |   @name = name
     5  · |   @validated = false  # Uncovered
     6  ✓ | end
     7    |
     8  ✓ | def validate
     9  · |   return if @validated  # Uncovered
    10  ✓ |   # ...
```

**Legend:**
- `✓` - Line is covered
- `·` - Line is not covered
- ` ` - Line is not executable (comments, blank lines)

### `detailed <path>`

Show per-line coverage with hit counts.

```sh
simplecov-mcp detailed lib/simplecov_mcp/model.rb
simplecov-mcp detailed lib/simplecov_mcp/model.rb --json
simplecov-mcp detailed lib/simplecov_mcp/model.rb --source
```

**Arguments:**
- `<path>` - File path (relative to project root or absolute)

**Options:**
- `--json` - Output as JSON
- `--source` - Include source code

**Output (default format):**
```
File: lib/simplecov_mcp/model.rb
  Line  Hits  Covered
  -----  ----  -------
     1     1  yes
     2     0  no
     3     1  yes
     4     5  yes
```

**Output (JSON format):**
```json
{
  "file": "lib/simplecov_mcp/model.rb",
  "lines": [
    { "line": 1, "hits": 1, "covered": true },
    { "line": 2, "hits": 0, "covered": false },
    { "line": 4, "hits": 5, "covered": true }
  ],
  "summary": {
    "covered": 2,
    "total": 3,
    "pct": 66.67
  },
  "stale": false
}
```

### `raw <path>`

Show the raw SimpleCov lines array.

```sh
simplecov-mcp raw lib/simplecov_mcp/model.rb
simplecov-mcp raw lib/simplecov_mcp/model.rb --json
```

**Arguments:**
- `<path>` - File path (relative to project root or absolute)

**Output (default format):**
```
File: lib/simplecov_mcp/model.rb
[1, 0, nil, 5, 2, nil, 1]
```

**Output (JSON format):**
```json
{
  "file": "lib/simplecov_mcp/model.rb",
  "lines": [1, 0, null, 5, 2, null, 1],
  "stale": false
}
```

**Array explanation:**
- Integer (e.g., `1`, `5`) - Number of times line was executed
- `0` - Line is executable but was not executed
- `null` - Line is not executable (comment, blank line)

### `version`

Show version information.

```sh
simplecov-mcp version
simplecov-mcp version --json
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
simplecov-mcp --root /path/to/project
```

### `-j, --json`

Output as JSON instead of human-readable format.

```sh
simplecov-mcp summary lib/simplecov_mcp/cli.rb --json
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
simplecov-mcp list --sort-order ascending
simplecov-mcp list --sort-order d  # Short form
```

### `-s, --source[=MODE]`

Include source code in output.

**Modes:**
- `full`, `f` - Show all source lines (default if no MODE given)
- `uncovered`, `u` - Show only uncovered lines with context

```sh
# Show full source
simplecov-mcp summary lib/simplecov_mcp/cli.rb --source
simplecov-mcp summary lib/simplecov_mcp/cli.rb --source=full

# Show only uncovered lines
simplecov-mcp uncovered lib/simplecov_mcp/cli.rb --source=uncovered
simplecov-mcp uncovered lib/simplecov_mcp/cli.rb -s=u  # Short form
```

### `-c, --source-context N`

Number of context lines around uncovered code (for `--source=uncovered`).

```sh
simplecov-mcp uncovered lib/simplecov_mcp/cli.rb --source=uncovered --source-context 3
```

**Default:** 2 lines

### `--color` / `--no-color`

Enable or disable ANSI color codes in source output.

```sh
simplecov-mcp uncovered lib/simplecov_mcp/cli.rb --source --color
simplecov-mcp uncovered lib/simplecov_mcp/cli.rb --source --no-color
```

**Default:** Colors enabled if output is a TTY

### `-S, --stale MODE`

Staleness checking mode.

**Modes:**
- `off`, `o` - No staleness checking (default)
- `error`, `e` - Raise error if coverage is stale

```sh
# Exit with error if coverage is stale
simplecov-mcp --stale error
simplecov-mcp -S e  # Short form
```

**Staleness conditions:**
- **M** (Missing): Source file no longer exists on disk
- **T** (Timestamp): Source file modified after coverage was generated
- **L** (Length): Source file line count differs from coverage data
- Tracked files missing from coverage (with --tracked-globs)

### `-g, --tracked-globs PATTERNS`

Comma-separated glob patterns for files that should be tracked.

```sh
simplecov-mcp list --tracked-globs "lib/**/*.rb,app/**/*.rb"
```

Used with `--stale error` to detect new files not yet in coverage.

### `-l, --log-file PATH`

Log file location. Use 'stdout' or 'stderr' to log to standard streams.

```sh
simplecov-mcp --log-file /var/log/simplecov.log
simplecov-mcp --log-file stdout # Log to standard output
simplecov-mcp --log-file stderr # Log to standard error
```

**Default:** `./simplecov_mcp.log`

### `--error-mode MODE`

Error handling verbosity.

**Modes:**
- `off` - Silent (no error logging)
- `on` - Log errors without stack traces (default)
- `on_with_trace`, `trace`, `t` - Log errors with full stack traces

```sh
simplecov-mcp --error-mode on_with_trace summary lib/simplecov_mcp/cli.rb
```

### `--force-cli`

Force CLI mode even when stdin is piped or when the process is running in a non-interactive shell (CI, Codex, etc.). Without it, the executable may fall back to MCP server mode.

```sh
SIMPLECOV_MCP_CLI=1 simplecov-mcp list
simplecov-mcp --force-cli list
```

### `--success-predicate FILE`

Run a custom success predicate for CI/CD coverage enforcement.

> **⚠️ SECURITY WARNING**
>
> Success predicates execute as **arbitrary Ruby code with full system privileges**. They have unrestricted access
> to file system, network, system commands, and environment variables.
>
> **Only use predicate files from trusted sources.** 
> Review predicates before use, especially in CI/CD environments.

The predicate file must return a callable (lambda, proc, or object with `#call` method) that receives a `CoverageModel` and returns truthy (success) or falsy (failure).

**Exit codes:**
- `0` - Predicate returned truthy (pass)
- `1` - Predicate returned falsy (fail)
- `2` - Predicate raised an error

**Example usage:**
```sh
# Use example predicate
simplecov-mcp --success-predicate examples/success_predicates/all_files_above_threshold.rb

# In CI/CD
bundle exec simplecov-mcp --success-predicate coverage_policy.rb
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
┌──────────────────────────┬──────────┬──────────┬────────┬───────┐
│ File                     │        % │  Covered │  Total │ Stale │
├──────────────────────────┼──────────┼──────────┼────────┼───────┤
│ lib/simple_cov_mcp.rb    │    85.71 │       12 │     14 │       │
└──────────────────────────┴──────────┴──────────┴────────┴───────┘
```

### JSON Format

Machine-readable output. Paths are relative to project root.

```json
{
  "file": "lib/simplecov_mcp/util.rb",
  "summary": {
    "covered": 12,
    "total": 14,
    "pct": 85.71
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
simplecov-mcp summary lib/simplecov_mcp/cli.rb  # Automatically uses options above
```

**Precedence:** Command-line arguments override environment options

```sh
# Environment sets --json, but --no-json on command line wins
export SIMPLECOV_MCP_OPTS="--json"
simplecov-mcp summary lib/simplecov_mcp/cli.rb  # Uses JSON (from env)
simplecov-mcp summary lib/simplecov_mcp/cli.rb --json  # Explicit, same result
```

**Examples:**
```sh
# Default resultset location
export SIMPLECOV_MCP_OPTS="--resultset build/coverage"

# Enable detailed error logging
export SIMPLECOV_MCP_OPTS="--error-mode trace"

# Paths with spaces
export SIMPLECOV_MCP_OPTS='--resultset "/path with spaces/coverage"'

# Multiple options
export SIMPLECOV_MCP_OPTS="--resultset coverage --stale error --json"
```



## Examples

### Basic Coverage Check

```sh
# Show all files sorted by lowest coverage first
simplecov-mcp

# Find the 5 files with worst coverage
simplecov-mcp list | head -10
```

### Detailed File Investigation

```sh
# Check a specific file
simplecov-mcp summary lib/simplecov_mcp/tools/coverage_summary_tool.rb

# See which lines aren't covered
simplecov-mcp uncovered lib/simplecov_mcp/tools/coverage_summary_tool.rb

# View uncovered code in context
simplecov-mcp uncovered lib/simplecov_mcp/tools/coverage_summary_tool.rb --source=uncovered --source-context 3

# Get detailed hit counts
simplecov-mcp detailed lib/simplecov_mcp/tools/coverage_summary_tool.rb
```

### JSON Output for Scripts

```sh
# Get JSON for parsing
simplecov-mcp list --json > coverage.json

# Extract files below threshold
simplecov-mcp list --json | jq '.files[] | select(.percentage < 80)'

# Count files below 80% coverage
simplecov-mcp list --json | jq '[.files[] | select(.percentage < 80)] | length'
```

### Filtering and Sorting

```sh
# Show only lib/ files
simplecov-mcp list --tracked-globs "lib/**/*.rb"

# Show files sorted by highest coverage
simplecov-mcp list --sort-order descending

# Check specific directory
simplecov-mcp list --tracked-globs "lib/simplecov_mcp/tools/**/*.rb"
```



### Staleness Checking

```sh
# Check if coverage is stale (for CI/CD)
simplecov-mcp --stale error

# Check with specific file patterns
simplecov-mcp list --stale error --tracked-globs "lib/**/*.rb,app/**/*.rb"

# See which files are stale (don't error)
simplecov-mcp list  # Stale files marked with !
```

### Source Code Display

```sh
# Show full source with coverage markers
simplecov-mcp summary lib/simplecov_mcp/cli.rb --source

# Show only uncovered lines with context
simplecov-mcp uncovered lib/simplecov_mcp/cli.rb --source=uncovered

# More context around uncovered code
simplecov-mcp uncovered lib/simplecov_mcp/cli.rb --source=uncovered --source-context 5

# Without colors (for logging)
simplecov-mcp uncovered lib/simplecov_mcp/cli.rb --source --no-color
```

### CI/CD Integration

```sh
# Fail build if coverage is stale
simplecov-mcp --stale error || exit 1

# Generate JSON report for artifact
simplecov-mcp list --json > artifacts/coverage-report.json

# Check specific directory in monorepo
simplecov-mcp --root services/api --resultset services/api/coverage
```

### Debugging

```sh
# Verbose error output
simplecov-mcp --error-mode trace summary lib/simplecov_mcp/cli.rb

# Custom log file
simplecov-mcp --log-file /tmp/simplecov-debug.log summary lib/simplecov_mcp/cli.rb

# Check what resultset is being used
simplecov-mcp --error-mode trace 2>&1 | grep resultset
```

## Exit Codes

- `0` - Success
- `1` - Error (file not found, coverage data missing, stale coverage with `--stale error`, etc.)

## Next Steps

- **[Library API](LIBRARY_API.md)** - Use in Ruby code
- **[Examples](EXAMPLES.md)** - More usage examples and recipes
- **[Troubleshooting](TROUBLESHOOTING.md)** - Common issues and solutions
