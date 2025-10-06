# Library API Guide (Ruby)

Use this gem programmatically to inspect coverage without running the CLI or MCP server. The primary entry point is `SimpleCovMcp::CoverageModel`.

## Basics

```ruby
require "simplecov_mcp"

# Defaults (omit args; shown here with comments):
# - root: "."
# - resultset: resolved from common paths under root
# - staleness: "off" (no stale checks)
# - tracked_globs: nil (no project-level file-set checks)
model = SimpleCovMcp::CoverageModel.new

# Custom configuration (non-default values):
model = SimpleCovMcp::CoverageModel.new(
  root: "/path/to/project",        # non-default project root
  resultset: "build/coverage",      # file or directory containing .resultset.json
  staleness: "error",               # enable stale checks (raise on stale)
  tracked_globs: ["lib/**/*.rb"]    # for 'all_files' staleness: flag new/missing files
)

# List all files with coverage summary, sorted ascending by % (default)
files = model.all_files
# => [ { 'file' => '/abs/path/lib/foo.rb', 'covered' => 12, 'total' => 14, 'percentage' => 85.71, 'stale' => false }, ... ]

# Per-file summaries
summary = model.summary_for("lib/foo.rb")
# => { 'file' => '/abs/.../lib/foo.rb', 'summary' => {'covered'=>12, 'total'=>14, 'pct'=>85.71}, 'stale' => false }

raw = model.raw_for("lib/foo.rb")
# => { 'file' => '/abs/.../lib/foo.rb', 'lines' => [nil, 1, 0, 3, ...], 'stale' => false }

uncovered = model.uncovered_for("lib/foo.rb")
# => { 'file' => '/abs/.../lib/foo.rb', 'uncovered' => [5, 9, 12], 'summary' => { ... }, 'stale' => false }

detailed = model.detailed_for("lib/foo.rb")
# => { 'file' => '/abs/.../lib/foo.rb', 'lines' => [{'line' => 1, 'hits' => 1, 'covered' => true}, ...], 'summary' => { ... }, 'stale' => false }
```

## Formatting Tables

```ruby
# Generate formatted table string (same as CLI output)
table = model.format_table
# => returns formatted table string with borders, headers, and summary counts

# Custom table with specific rows and sort order
custom_rows = [
  { 'file' => '/abs/.../lib/foo.rb', 'covered' => 12, 'total' => 14, 'percentage' => 85.71, 'stale' => false },
  { 'file' => '/abs/.../lib/bar.rb', 'covered' => 8, 'total' => 10, 'percentage' => 80.0, 'stale' => true }
]
custom_table = model.format_table(custom_rows, sort_order: :descending)
# => formatted table with the provided rows in descending order
```

## Filtering and Analysis Examples

```ruby
# Filter files by directory (e.g., only show files in lib/)
all_files_data = model.all_files
lib_files = all_files_data.select { |file| file['file'].include?('/lib/') }
lib_files_table = model.format_table(lib_files, sort_order: :ascending)
# => formatted table showing only files from lib/ directory

# Filter by pattern (e.g., only show test files)
test_files = all_files_data.select { |file| file['file'].include?('_spec.rb') || file['file'].include?('_test.rb') }
test_files_table = model.format_table(test_files, sort_order: :descending)
# => formatted table showing only test/spec files, sorted by coverage
```

For more advanced filtering examples including staleness analysis and CI/CD integration, see the complete example script at [examples/filter_and_table_demo.rb](/examples/filter_and_table_demo.rb).

## Staleness Values

All single-file methods (`summary_for`, `raw_for`, `uncovered_for`, `detailed_for`) and `all_files` include a `'stale'` field with one of these values:

- `false` - Coverage data is current
- `'M'` - **Missing**: File no longer exists on disk
- `'T'` - **Timestamp**: File modified more recently than coverage data
- `'L'` - **Length**: Source file line count differs from coverage data

When `staleness: 'error'` mode is enabled in `CoverageModel.new`, stale files will raise `SimpleCovMcp::CoverageDataStaleError` exceptions.

## Public API Stability

Consider the following public and stable under SemVer:
- `SimpleCovMcp::CoverageModel.new(root:, resultset:, staleness: 'off', tracked_globs: nil)`
- `#raw_for(path)`, `#summary_for(path)`, `#uncovered_for(path)`, `#detailed_for(path)`, `#all_files(sort_order:)`, `#format_table(rows: nil, sort_order:, check_stale:, tracked_globs:)`
- Return shapes shown in the examples (keys and value types). For `all_files`, each row also includes `'stale' => true|false`.
- `#format_table` returns a formatted table string with Unicode borders and summary counts.

**Note:**
- CLI (`SimpleCovMcp.run(argv)`) and MCP tools remain stable but are separate surfaces.
- Internal helpers under `SimpleCovMcp::CovUtil` may change; prefer `CoverageModel` unless you need low-level access.
