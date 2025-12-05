# Library API Guide

[Back to main README](../README.md)

Use this gem programmatically to inspect coverage without running the CLI or MCP server. The primary entry point is `SimpleCovMcp::CoverageModel`.

## Table of Contents

- [Quick Start](#quick-start)
- [Method Reference](#method-reference)
- [Return Types](#return-types)
- [Error Handling](#error-handling)
- [Advanced Recipes](#advanced-recipes)
- [API Stability](#api-stability)

## Quick Start

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

# List all files with coverage summary
files = model.all_files
# Per-file queries
summary = model.summary_for("lib/foo.rb")
uncovered = model.uncovered_for("lib/foo.rb")
detailed = model.detailed_for("lib/foo.rb")
raw = model.raw_for("lib/foo.rb")
```

## Method Reference

### `all_files(sort_order: :descending)`

Returns coverage summary for all files in the resultset.

**Parameters:**
- `sort_order` (Symbol, optional): `:descending` (default) or `:ascending` by coverage percentage

**Returns:** `Array<Hash>` - See [all_files return type](#all_files)

**Example:**
```ruby
files = model.all_files
# => [ { 'file' => '/abs/path/lib/foo.rb', 'covered' => 12, 'total' => 14, 'percentage' => 85.71, 'stale' => false }, ... ]

# Get worst coverage first
worst_files = model.all_files(sort_order: :ascending).first(10)
```

### `summary_for(path)`

Returns coverage summary for a specific file.

**Parameters:**
- `path` (String): File path (absolute, relative to root, or basename)

**Returns:** `Hash` - See [summary_for return type](#summary_for)

**Raises:** `SimpleCovMcp::FileError` if file not in coverage data

**Example:**
```ruby
summary = model.summary_for("lib/foo.rb")
# => { 'file' => '/abs/.../lib/foo.rb', 'summary' => {'covered'=>12, 'total'=>14, 'percentage'=>85.71}, 'stale' => false }
```

### `uncovered_for(path)`

Returns list of uncovered line numbers for a specific file.

**Parameters:**
- `path` (String): File path (absolute, relative to root, or basename)

**Returns:** `Hash` - See [uncovered_for return type](#uncovered_for)

**Raises:** `SimpleCovMcp::FileError` if file not in coverage data

**Example:**
```ruby
uncovered = model.uncovered_for("lib/foo.rb")
# => { 'file' => '/abs/.../lib/foo.rb', 'uncovered' => [5, 9, 12], 'summary' => { ... }, 'stale' => false }
```

### `detailed_for(path)`

Returns per-line coverage details with hit counts.

**Parameters:**
- `path` (String): File path (absolute, relative to root, or basename)

**Returns:** `Hash` - See [detailed_for return type](#detailed_for)

**Raises:** `SimpleCovMcp::FileError` if file not in coverage data

**Example:**
```ruby
detailed = model.detailed_for("lib/foo.rb")
# => { 'file' => '/abs/.../lib/foo.rb', 'lines' => [{'line' => 1, 'hits' => 1, 'covered' => true}, ...], 'summary' => { ... }, 'stale' => false }
```

### `raw_for(path)`

Returns raw SimpleCov lines array for a specific file.

**Parameters:**
- `path` (String): File path (absolute, relative to root, or basename)

**Returns:** `Hash` - See [raw_for return type](#raw_for)

**Raises:** `SimpleCovMcp::FileError` if file not in coverage data

**Example:**
```ruby
raw = model.raw_for("lib/foo.rb")
# => { 'file' => '/abs/.../lib/foo.rb', 'lines' => [nil, 1, 0, 3, ...], 'stale' => false }
```

### `format_table(rows = nil, sort_order: :descending)`

Generates formatted ASCII table string.

**Parameters:**
- `rows` (Array<Hash>, optional): Custom row data; defaults to `all_files`
- `sort_order` (Symbol, optional): `:descending` (default) or `:ascending`

**Returns:** `String` - Formatted table with Unicode borders

**Example:**
```ruby
# Default: all files
table = model.format_table
puts table

# Custom rows
lib_files = model.all_files.select { |f| f['file'].include?('/lib/') }
lib_table = model.format_table(lib_files, sort_order: :descending)
puts lib_table
```

### `project_totals(tracked_globs: nil)`

Returns aggregated coverage totals across all files.

**Parameters:**
- `tracked_globs` (Array<String> or String, optional): Glob patterns to filter files

**Returns:** `Hash` - See [project_totals return type](#project_totals)

**Example:**
```ruby
totals = model.project_totals
# => { 'lines' => { 'total' => 123, 'covered' => 100, 'uncovered' => 23 }, 'percentage' => 81.3, 'files' => { 'total' => 5, 'ok' => 4, 'stale' => 1 } }

# Filter to specific directory
lib_totals = model.project_totals(tracked_globs: 'lib/**/*.rb')
```

### `relativize(data)`

Converts absolute file paths in coverage data to relative paths from project root.

**Parameters:**
- `data` (Hash or Array<Hash>): Coverage data with absolute file paths

**Returns:** `Hash` or `Array<Hash>` - Same structure with relative paths

**Example:**
```ruby
summary = model.summary_for('lib/simplecov_mcp/model.rb')
# => { 'file' => '/home/user/project/lib/simplecov_mcp/model.rb', ... }

relative_summary = model.relativize(summary)
# => { 'file' => 'lib/simplecov_mcp/model.rb', ... }

# Works with arrays too
files = model.all_files
relative_files = model.relativize(files)
```

## Return Types

### `all_files`

Returns `Array<Hash>` where each hash contains:

```ruby
{
  'file' => String,       # Absolute file path
  'covered' => Integer,   # Number of covered lines
  'total' => Integer,     # Total relevant lines
  'percentage' => Float,  # Coverage percentage (0.00-100.00)
  'stale' => false | String  # Staleness indicator: false, 'M', 'T', or 'L'
}
```

### `summary_for`

Returns `Hash`:

```ruby
{
  'file' => String,       # Absolute file path
  'summary' => {
    'covered' => Integer, # Number of covered lines
    'total' => Integer,   # Total relevant lines
    'percentage' => Float        # Coverage percentage (0.00-100.00)
  }
}
```

### `uncovered_for`

Returns `Hash`:

```ruby
{
  'file' => String,       # Absolute file path
  'uncovered' => Array<Integer>,  # Line numbers that are not covered
  'summary' => {
    'covered' => Integer,
    'total' => Integer,
    'percentage' => Float
  }
}
```

### `detailed_for`

Returns `Hash`:

```ruby
{
  'file' => String,       # Absolute file path
  'lines' => Array<Hash>, # Per-line coverage details
  'summary' => {
    'covered' => Integer,
    'total' => Integer,
    'percentage' => Float
  }
}
```

Each element in `lines` array:
```ruby
{
  'line' => Integer,    # Line number (1-indexed)
  'hits' => Integer,    # Execution count (0 means not covered)
  'covered' => Boolean  # true if hits > 0
}
```

### `raw_for`

Returns `Hash`:

```ruby
{
  'file' => String,              # Absolute file path
  'lines' => Array<Integer | nil>   # SimpleCov lines array (nil = irrelevant, 0 = uncovered, >0 = hit count)
}
```

### `project_totals`

Returns `Hash`:

```ruby
{
  'lines' => {
    'total' => Integer,      # Total relevant lines across all files
    'covered' => Integer,    # Total covered lines
    'uncovered' => Integer   # Total uncovered lines
  },
  'percentage' => Float,     # Overall coverage percentage
  'files' => {
    'total' => Integer,      # Total number of files
    'ok' => Integer,         # Files with fresh coverage
    'stale' => Integer       # Files with stale coverage
  }
}
```

## Error Handling

### Exception Types

The library raises these custom exceptions:

- **`SimpleCovMcp::ResultsetNotFoundError`** - Coverage data file not found
- **`SimpleCovMcp::FileError`** - Requested file not in coverage data
- **`SimpleCovMcp::CoverageDataStaleError`** - Coverage data is stale (only when `staleness: 'error'`)
- **`SimpleCovMcp::CoverageDataError`** - Invalid coverage data format or structure

All exceptions inherit from `SimpleCovMcp::Error`.

### Basic Error Handling

```ruby
require "simplecov_mcp"

begin
  model = SimpleCovMcp::CoverageModel.new
  summary = model.summary_for("lib/foo.rb")
  puts "Coverage: #{summary['summary']['percentage']}%"
rescue SimpleCovMcp::FileError => e
  puts "File not in coverage data: #{e.message}"
rescue SimpleCovMcp::ResultsetNotFoundError => e
  puts "Coverage data not found: #{e.message}"
  puts "Run your tests first: bundle exec rspec"
rescue SimpleCovMcp::Error => e
  puts "Coverage error: #{e.message}"
end
```

### Handling Stale Coverage

```ruby
# Option 1: Check staleness without raising
model = SimpleCovMcp::CoverageModel.new(staleness: "off")
files = model.all_files

stale_files = files.select { |f| f['stale'] }
if stale_files.any?
  puts "Warning: #{stale_files.length} files have stale coverage"
  stale_files.each do |f|
    puts "  #{f['file']}: #{f['stale']}"
  end
end

# Option 2: Raise on staleness
begin
  model = SimpleCovMcp::CoverageModel.new(staleness: "error")
  files = model.all_files
rescue SimpleCovMcp::CoverageDataStaleError => e
  puts "Stale coverage detected: #{e.message}"
  puts "Re-run tests: bundle exec rspec"
  exit 1
end
```

### Graceful Degradation

```ruby
# Try multiple file paths
def find_coverage(model, possible_paths)
  possible_paths.each do |path|
    begin
      return model.summary_for(path)
    rescue SimpleCovMcp::FileError
      next
    end
  end
  nil
end

summary = find_coverage(model, [
  "lib/services/auth_service.rb",
  "app/services/auth_service.rb",
  "services/auth_service.rb"
])

if summary
  puts "Coverage: #{summary['summary']['percentage']}%"
else
  puts "File not found in coverage data"
end
```

## Advanced Recipes

### Batch File Analysis

```ruby
require "simplecov_mcp"

model = SimpleCovMcp::CoverageModel.new

# Analyze multiple files efficiently
files_to_check = [
  "lib/auth_service.rb",
  "lib/payment_processor.rb",
  "lib/user_manager.rb"
]

results = files_to_check.map do |path|
  begin
    summary = model.summary_for(path)
    {
      file: path,
      coverage: summary['summary']['percentage'],
      status: summary['summary']['percentage'] >= 80 ? :ok : :low
    }
  rescue SimpleCovMcp::FileError
    {
      file: path,
      coverage: nil,
      status: :missing
    }
  end
end

# Report
results.each do |r|
  status_icon = { ok: '✓', low: '⚠', missing: '✗' }[r[:status]]
  puts "#{status_icon} #{r[:file]}: #{r[:coverage] || 'N/A'}%"
end
```

### Coverage Threshold Validation

```ruby
require "simplecov_mcp"

class CoverageValidator
  THRESHOLDS = {
    'lib/' => 90.0,      # Core library needs 90%+
    'app/' => 80.0,      # Application code needs 80%+
    'spec/' => 70.0,     # Test helpers need 70%+
  }

  def initialize(model)
    @model = model
  end

  def validate!
    files = @model.all_files
    failures = []

    files.each do |file|
      threshold = threshold_for(file['file'])
      next unless threshold

      if file['percentage'] < threshold
        failures << {
          file: file['file'],
          actual: file['percentage'],
          required: threshold,
          gap: threshold - file['percentage']
        }
      end
    end

    if failures.any?
      puts "❌ #{failures.length} files below coverage threshold:"
      failures.sort_by { |f| -f[:gap] }.each do |f|
        puts "  #{f[:file]}: #{f[:actual]}% (need #{f[:required]}%)"
      end
      exit 1
    else
      puts "✓ All files meet coverage thresholds"
    end
  end

  private

  def threshold_for(path)
    THRESHOLDS.each do |prefix, threshold|
      return threshold if path.include?(prefix)
    end
    nil
  end
end

model = SimpleCovMcp::CoverageModel.new
validator = CoverageValidator.new(model)
validator.validate!
```

### Directory-Level Aggregation

```ruby
require "simplecov_mcp"

model = SimpleCovMcp::CoverageModel.new

# Calculate coverage by directory using the totals API
patterns = %w[lib/simplecov_mcp/tools/**/*.rb lib/simplecov_mcp/commands/**/*.rb lib/simplecov_mcp/presenters/**/*.rb]

directory_stats = patterns.map do |pattern|
  totals = model.project_totals(tracked_globs: pattern)

  {
    directory: pattern,
    files: totals['files']['total'],
    coverage: totals['percentage'].round(2),
    covered: totals['lines']['covered'],
    total: totals['lines']['total']
  }
end

# Display sorted by coverage
directory_stats.sort_by { |s| s[:coverage] }.each do |stat|
  puts "#{stat[:directory]}: #{stat[:coverage]}% (#{stat[:files]} files)"
end
```

### Coverage Delta Tracking

```ruby
require "simplecov_mcp"
require "json"

class CoverageDeltaTracker
  def initialize(baseline_path: "coverage_baseline.json")
    @baseline_path = baseline_path
    @model = SimpleCovMcp::CoverageModel.new
  end

  def save_baseline
    current = @model.all_files
    File.write(@baseline_path, JSON.pretty_generate(current))
    puts "Saved coverage baseline (#{current.length} files)"
  end

  def compare
    unless File.exist?(@baseline_path)
      puts "No baseline found. Run save_baseline first."
      return
    end

    baseline = JSON.parse(File.read(@baseline_path))
    current = @model.all_files

    improved = []
    regressed = []

    current.each do |file|
      baseline_file = baseline.find { |f| f['file'] == file['file'] }
      next unless baseline_file

      delta = file['percentage'] - baseline_file['percentage']

      if delta > 0.1
        improved << {
          file: file['file'],
          before: baseline_file['percentage'],
          after: file['percentage'],
          delta: delta
        }
      elsif delta < -0.1
        regressed << {
          file: file['file'],
          before: baseline_file['percentage'],
          after: file['percentage'],
          delta: delta
        }
      end
    end

    if improved.any?
      puts "\n✓ Coverage Improvements:"
      improved.sort_by { |f| -f[:delta] }.each do |f|
        puts "  #{f[:file]}: #{f[:before]}% → #{f[:after]}% (+#{f[:delta].round(2)}%)"
      end
    end

    if regressed.any?
      puts "\n⚠ Coverage Regressions:"
      regressed.sort_by { |f| f[:delta] }.each do |f|
        puts "  #{f[:file]}: #{f[:before]}% → #{f[:after]}% (#{f[:delta].round(2)}%)"
      end
    end

    if improved.empty? && regressed.empty?
      puts "No significant coverage changes"
    end
  end
end

# Usage
tracker = CoverageDeltaTracker.new
tracker.save_baseline  # Run before making changes
# ... make code changes and re-run tests ...
tracker.compare        # See what changed
```

### Custom Reporting

```ruby
require "simplecov_mcp"

class CoverageReporter
  def initialize(model)
    @model = model
  end

  def generate_markdown_report(output_path)
    files = @model.all_files
    totals = @model.project_totals

    File.open(output_path, 'w') do |f|
      f.puts "# Coverage Report"
      f.puts
      f.puts "Generated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
      f.puts

      # Overall stats
      overall_percentage = totals['percentage']
      total_lines = totals['lines']['total']
      covered_lines = totals['lines']['covered']
      total_files = totals['files']['total']

      f.puts "## Overall Coverage: #{overall_percentage}%"
      f.puts
      f.puts "- Total Files: #{total_files}"
      f.puts "- Total Lines: #{total_lines}"
      f.puts "- Covered Lines: #{covered_lines}"
      f.puts

      # Files below threshold
      threshold = 80.0
      low_coverage = files.select { |file| file['percentage'] < threshold }

      if low_coverage.any?
        f.puts "## Files Below #{threshold}% Coverage"
        f.puts
        f.puts "| File | Coverage | Missing Lines |"
        f.puts "|------|----------|---------------|"

        low_coverage.sort_by { |file| file['percentage'] }.each do |file|
          uncovered = @model.uncovered_for(file['file'])
          missing_count = uncovered['uncovered'].length
          f.puts "| #{file['file']} | #{file['percentage']}% | #{missing_count} |"
        end
        f.puts
      end

      # Top performers
      f.puts "## Top 10 Best Covered Files"
      f.puts
      f.puts "| File | Coverage |"
      f.puts "|------|----------|"

      files.sort_by { |file| -file['percentage'] }.take(10).each do |file|
        f.puts "| #{file['file']} | #{file['percentage']}% |"
      end
    end

    puts "Report saved to #{output_path}"
  end
end

model = SimpleCovMcp::CoverageModel.new
reporter = CoverageReporter.new(model)
reporter.generate_markdown_report("coverage_report.md")
```

## Staleness Detection

The `all_files` method returns a `'stale'` field for each file with one of these values:

- `false` - Coverage data is current
- `'M'` - **Missing**: File no longer exists on disk
- `'T'` - **Timestamp**: File modified more recently than coverage data
- `'L'` - **Length**: Source file line count differs from coverage data

**Note:** Per-file methods (`summary_for`, `uncovered_for`, `detailed_for`, `raw_for`) do not include staleness information in their return values. To check staleness for individual files, use `all_files` and filter the results.

When `staleness: 'error'` mode is enabled in `CoverageModel.new`, the model will raise `SimpleCovMcp::CoverageDataStaleError` exceptions when stale files are detected during method calls.

## API Stability

Consider the following public and stable under SemVer:
- `SimpleCovMcp::CoverageModel.new(root:, resultset:, staleness: 'off', tracked_globs: nil)`
- `#raw_for(path)`, `#summary_for(path)`, `#uncovered_for(path)`, `#detailed_for(path)`, `#all_files(sort_order:)`, `#format_table(rows: nil, sort_order:, check_stale:, tracked_globs:)`
- Return shapes shown in the [Return Types](#return-types) section
- Exception types documented in [Error Handling](#error-handling)

**Note:**
- CLI (`SimpleCovMcp.run(argv)`) and MCP tools remain stable but are separate surfaces
- Internal helpers under `SimpleCovMcp::CovUtil` may change; prefer `CoverageModel` unless you need low-level access

## Related Documentation

- [Examples](EXAMPLES.md) - Practical cookbook-style examples
- [CLI Usage](CLI_USAGE.md) - Command-line interface reference
- [Error Handling](ERROR_HANDLING.md) - Detailed error handling documentation
- [MCP Integration](MCP_INTEGRATION.md) - AI assistant integration
