# Examples and Recipes

[Back to main README](../README.md)

Practical examples for common tasks with simplecov-mcp. Examples are organized by skill level and use case.

> For brevity, these examples use `smcp`, an alias to the demo fixture with partial coverage:
> `alias smcp='simplecov-mcp --root docs/fixtures/demo_project'`
> Swap `smcp` for `simplecov-mcp` to run against your own project and resultset.

## Table of Contents

- [Quick Start Examples](#quick-start-examples)
- [CLI Examples](#cli-examples)
- [Ruby Library Examples](#ruby-library-examples)
- [AI Assistant Prompts](#ai-assistant-prompts)
- [CI/CD Integration](#cicd-integration)
- [Advanced Usage](#advanced-usage)

## Quick Start Examples

### View All Coverage

```bash
# Default: show all files, worst coverage first
smcp

# Show files with best coverage first
smcp list --sort-order descending

# Export to JSON for processing
smcp list --json > coverage-report.json
```

### Check Specific File

```bash
# Quick summary
smcp summary app/models/order.rb

# See which lines aren't covered
smcp uncovered app/controllers/orders_controller.rb

# View uncovered code with context
smcp uncovered app/controllers/orders_controller.rb --source=uncovered --source-context 3
```

### Find Coverage Gaps

```bash
# Files with worst coverage
smcp list | head -10

# Only show files below 80%
smcp list --json | jq '.files[] | select(.percentage < 95)'

# Ruby alternative:
smcp list --json | ruby -r json -e '
  JSON.parse($stdin.read)["files"].select { |f| f["percentage"] < 95 }.each do |f|
    puts JSON.pretty_generate(f)
  end
'

# Rexe alternative:
smcp list --json | rexe -ij -mb -oJ 'self["files"].select { |f| f["percentage"] < 95 }'

# Check specific directory
smcp list --tracked-globs "lib/payments/**/*.rb"
```

## CLI Examples

### Coverage Analysis

**Detailed investigation:**
```bash
# See detailed hit counts
smcp detailed lib/api/client.rb

# Show full source with coverage markers
smcp summary lib/api/client.rb --source=full

# Focus on uncovered areas only
smcp uncovered lib/payments/refund_service.rb --source=uncovered --source-context 5
```

### Working with JSON Output

In addition to the benefit of JSON encoding being human readable, it can be used in single line commands to fetch and compute values using `jq`, Ruby's JSON library, or `rexe`.
Here are some examples:

**Parse and filter:**
```bash
# Files below threshold
smcp list --json | jq '.files[] | select(.percentage < 95) | {file, coverage: .percentage}'

# Ruby alternative:
smcp list --json | ruby -r json -e '
  JSON.parse($stdin.read)["files"].select { |f| f["percentage"] < 95 }.each do |f|
    puts JSON.pretty_generate({file: f["file"], coverage: f["percentage"]})
  end
'

# Rexe alternative:
smcp list --json | rexe -ij -mb -oJ '
  self["files"].select { |f| f["percentage"] < 95 }.map do |f|
    {file: f["file"], coverage: f["percentage"]}
  end
'

# Count total uncovered lines
smcp total --json | jq '.lines.uncovered'

# Ruby alternative:
smcp total --json | ruby -r json -e '
  puts JSON.parse($stdin.read)["lines"]["uncovered"]
'

# Rexe alternative:
smcp total --json | rexe -ij -mb -op 'self["lines"]["uncovered"]'

# Group by directory (full path)
smcp list --json |
  jq '.files
      | map(. + {dir: (.file | split("/") | .[0:-1] | join("/"))})
      | sort_by(.dir)
      | group_by(.dir)
      | map({dir: .[0].dir, avg: (map(.percentage) | add / length)})'

# Ruby alternative:
smcp list --json | ruby -r json -e '
  grouped = JSON.parse($stdin.read)["files"]
    .map { |f| f.merge("dir" => File.dirname(f["file"])) }
    .group_by { |f| f["dir"] }
    .map { |dir, files|
      avg = files.sum { |f| f["percentage"] } / files.size
      {dir: dir, avg: avg}
    }
  puts JSON.pretty_generate(grouped)
'

# Rexe alternative:
smcp list --json | rexe -ij -mb -oJ '
  self["files"]
    .map { |f| f.merge("dir" => File.dirname(f["file"])) }
    .group_by { |f| f["dir"] }
    .map { |dir, files|
      avg = files.sum { |f| f["percentage"] } / files.size
      {dir: dir, avg: avg}
    }
'
```

**Generate reports:**
```bash
# Create markdown table
echo "| Coverage | File |" > report.md
echo "|----------|------|" >> report.md
smcp list --json | jq -r '.files[] | "| \(.percentage)% | \(.file) |"' >> report.md

# Ruby alternative:
smcp list --json | ruby -r json -e '
  JSON.parse($stdin.read)["files"].each do |f|
    puts "| #{f["percentage"]}% | #{f["file"]} |"
  end
' >> report.md

# Rexe alternative:
smcp list --json | rexe -ij -mb '
  self["files"].each { |f| puts "| #{f["percentage"]}% | #{f["file"]} |" }
' >> report.md

# Export for spreadsheet
smcp list --json | jq -r '.files[] | [.file, .percentage] | @csv' > coverage.csv

# Ruby alternative:
smcp list --json | ruby -r json -r csv -e '
  JSON.parse($stdin.read)["files"].each do |f|
    puts CSV.generate_line([f["file"], f["percentage"]]).chomp
  end
' > coverage.csv

# Rexe alternative:
smcp list --json | rexe -r csv -ij -mb '
  self["files"].each { |f| puts CSV.generate_line([f["file"], f["percentage"]]).chomp }
' > coverage.csv
```

## Ruby Library Examples

### Basic Usage

```ruby
require "simplecov_mcp"

root = "docs/fixtures/demo_project"
model = SimpleCovMcp::CoverageModel.new(root: root)

# Project totals
totals = model.project_totals
puts "Total files: #{totals['files']['total']}"
puts "Average coverage: #{totals['percentage']}%"

# Check specific file
summary = model.summary_for("app/models/order.rb")
puts "Coverage: #{summary['summary']['percentage']}%"

# Find uncovered lines
uncovered = model.uncovered_for("lib/payments/refund_service.rb")
puts "Uncovered lines: #{uncovered['uncovered'].join(', ')}"
```

### Filtering and Analysis

```ruby
require "simplecov_mcp"

root = "docs/fixtures/demo_project"
model = SimpleCovMcp::CoverageModel.new(root: root)
all_files = model.all_files

# Find files below threshold
THRESHOLD = 80.0
low_coverage = all_files.select { |f| f['percentage'] < THRESHOLD }

if low_coverage.any?
  puts "Files below #{THRESHOLD}%:"
  low_coverage.each do |file|
    puts "  #{file['file']}: #{file['percentage']}%"
  end
end

# Group by directory using totals command logic
dirs = %w[app lib lib/payments lib/ops/jobs].uniq
dirs.each do |dir|
  pattern = File.join(dir, '**/*.rb')
  totals = model.project_totals(tracked_globs: pattern)
  puts "#{dir}: #{totals['percentage'].round(2)}% (#{totals['files']['total']} files)"
end
```

### Custom Formatting

```ruby
require "simplecov_mcp"
require "pathname"

root = "docs/fixtures/demo_project"
model = SimpleCovMcp::CoverageModel.new(root: root)
all_files = model.all_files

# Filter to lib/payments (coverage data stores absolute paths)
lib_root = File.expand_path("lib/payments", File.expand_path(root, Dir.pwd))
lib_files = all_files.select { |f| f['file'].start_with?(lib_root) }

# Generate custom table
table = model.format_table(lib_files, sort_order: :ascending)
puts table

# Or create your own format
lib_files.each do |file|
  status = file['percentage'] >= 90 ? '✓' : '⚠'
  relative_path = Pathname.new(file['file']).relative_path_from(Pathname.pwd)
  puts "#{status} #{relative_path}: #{file['percentage']}%"
end
```

## AI Assistant Prompts

### Coverage Analysis

```
Using simplecov-mcp, show me a table of all files sorted by coverage percentage.
```

```
Using simplecov-mcp, find the 10 files with the lowest coverage and create a markdown report with:
1. File path
2. Current coverage %
3. Number of uncovered lines
```

```
Using simplecov-mcp, analyze the lib/payments/ directory and identify which files should be prioritized for additional testing based on coverage gaps and file complexity.
```

### Finding Specific Issues

```
Using simplecov-mcp, show me the uncovered lines in app/controllers/orders_controller.rb with 5 lines of context around each uncovered block.
```

```
Using simplecov-mcp, find all files in lib/payments/ with less than 80% coverage and list the specific uncovered line numbers for each.
```

### Test Generation

```
Using simplecov-mcp, identify the uncovered lines in lib/ops/jobs/report_job.rb and write RSpec tests to cover them.
```

```
Using simplecov-mcp, analyze coverage gaps in the app/controllers/ directory and generate a test plan prioritizing:
1. Public API methods
2. Error handling paths
3. Edge cases
```

### Reporting

```
Using simplecov-mcp, create a coverage report showing:
- Overall project coverage percentage
- Top 5 files with worst coverage
- Recommended next steps to improve coverage

Format as markdown.
```

## Test Run Integration

### Display Low Coverage Files After RSpec

Add this to your `spec/spec_helper.rb` to automatically report files below a coverage threshold after each test run:

```ruby
require 'simplecov'
SimpleCov.start do
  enable_coverage :branch
  add_filter %r{^/spec/}
  track_files 'lib/**/*.rb'  # Ensures new/untested files show up with 0%
end

# Report lowest coverage files at the end of the test run
SimpleCov.at_exit do
  SimpleCov.result.format!
  require 'simplecov_mcp'
  report = SimpleCovMcp::CoverageReporter.report(threshold: 80, count: 5)
  puts report if report
end
```

This produces output like:

```
Lowest coverage files (< 80%):
    0.0%  lib/myapp/config_parser.rb
   19.3%  lib/myapp/formatters/source_formatter.rb
   24.0%  lib/myapp/model.rb
   26.0%  lib/myapp/cli.rb
   45.2%  lib/myapp/commands/base.rb
```

**Parameters:**
- `threshold:` - Coverage percentage below which files are included (default: 80)
- `count:` - Maximum number of files to show (default: 5)

**Returns:** Formatted string, or `nil` if no files are below the threshold.

## CI/CD Integration

### GitHub Actions

**Fail on low coverage:**
```yaml
name: Coverage Check

on: [push, pull_request]

jobs:
  coverage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.3
          bundler-cache: true

      - name: Run tests
        run: bundle exec rspec

      - name: Install simplecov-mcp
        run: gem install simplecov-mcp

      - name: Check coverage threshold
        run: |
          smcp list --json > coverage.json
          BELOW_THRESHOLD=$(jq '[.files[] | select(.percentage < 80)] | length' coverage.json)

          # Ruby alternative:
          # BELOW_THRESHOLD=$(ruby -r json -e '
          #   puts JSON.parse(File.read("coverage.json"))["files"].count { |f| f["percentage"] < 80 }
          # ')

          # Rexe alternative:
          # BELOW_THRESHOLD=$(rexe -f coverage.json -op 'self["files"].count { |f| f["percentage"] < 80 }')

          if [ "$BELOW_THRESHOLD" -gt 0 ]; then
            echo "❌ $BELOW_THRESHOLD files below 80% coverage"
            jq -r '.files[] | select(.percentage < 80) | "\(.file): \(.percentage)%"' coverage.json

            # Ruby alternative:
            # ruby -r json -e '
            #   JSON.parse(File.read("coverage.json"))["files"].select { |f| f["percentage"] < 80 }.each do |f|
            #     puts "#{f["file"]}: #{f["percentage"]}%"
            #   end
            # '

            # Rexe alternative:
            # rexe -f coverage.json '
            #   self["files"].select { |f| f["percentage"] < 80 }.each do |f|
            #     puts "#{f["file"]}: #{f["percentage"]}%"
            #   end
            # '

            exit 1
          fi
          echo "✓ All files meet coverage threshold"

      - name: Upload coverage report
        uses: actions/upload-artifact@v3
        with:
          name: coverage-report
          path: coverage.json
```

**Check for stale coverage:**
```yaml
      - name: Verify coverage is fresh
        run: simplecov-mcp --stale error || exit 1
```

### GitLab CI

```yaml
test:
  image: ruby:3.3
  before_script:
    - gem install simplecov-mcp
  script:
    - bundle exec rspec
    - simplecov-mcp --stale error
  artifacts:
    paths:
      - coverage/
    reports:
      coverage_report:
        coverage_format: simplecov
        path: coverage/.resultset.json
```

### Custom Success Predicate

```ruby
# coverage_policy.rb
->(model) do
  all_files = model.all_files

  # Must have at least 80% average coverage
  totals = model.project_totals
  return false if totals['percentage'] < 80.0

  # No files below 60%
  return false if all_files.any? { |f| f['percentage'] < 60.0 }

  # lib/ files must average 90%
  lib_totals = model.project_totals(tracked_globs: ['lib/**/*.rb'])
  return false if lib_totals['percentage'] < 90.0

  true
end
```

```bash
# Use in CI
smcp --success-predicate coverage_policy.rb
```

## Advanced Usage

### Directory-Level Analysis

```ruby
require "simplecov_mcp"

root = "docs/fixtures/demo_project"
model = SimpleCovMcp::CoverageModel.new(root: root)
all_files = model.all_files

# Calculate coverage by directory (uses the same data as `simplecov-mcp total`)
patterns = %w[
  app/**/*.rb
  lib/payments/**/*.rb
  lib/ops/jobs/**/*.rb
]

results = patterns.map do |pattern|
  totals = model.project_totals(tracked_globs: pattern)

  {
    directory: pattern,
    files: totals['files']['total'],
    coverage: totals['percentage'].round(2),
    covered: totals['lines']['covered'],
    total: totals['lines']['total']
  }
end

# Sort by coverage ascending
results.sort_by { |r| r[:coverage] }.each do |r|
  puts "#{r[:directory]}: #{r[:coverage]}% (#{r[:files]} files)"
end
```

### Coverage Delta Tracking

```ruby
require "simplecov_mcp"
require "json"

# Save current coverage
root = "docs/fixtures/demo_project"
model = SimpleCovMcp::CoverageModel.new(root: root)
current = model.all_files

File.write("coverage_baseline.json", JSON.pretty_generate(current))

# Later, compare with baseline
baseline = JSON.parse(File.read("coverage_baseline.json"))

current.each do |file|
  baseline_file = baseline.find { |f| f['file'] == file['file'] }
  next unless baseline_file

  delta = file['percentage'] - baseline_file['percentage']
  if delta.abs > 0.1  # Changed by more than 0.1%
    symbol = delta > 0 ? '↑' : '↓'
    puts "#{symbol} #{file['file']}: #{baseline_file['percentage']}% → #{file['percentage']}%"
  end
end
```

### Integration with Code Review

```ruby
# pr_coverage_check.rb
require "simplecov_mcp"
require "json"

model = SimpleCovMcp::CoverageModel.new

# Get changed files from PR (example using git)
changed_files = `git diff --name-only origin/main`.split("\n")
changed_files.select! { |f| f.end_with?('.rb') }

puts "## Coverage Report for Changed Files\n\n"
puts "| File | Coverage | Status |"
puts "|------|----------|--------|"

changed_files.each do |file|
  begin
    summary = model.summary_for(file)
    percentage = summary['summary']['percentage']
    status = percentage >= 80 ? '✅' : '⚠️'
    puts "| #{file} | #{percentage}% | #{status} |"
  rescue
    puts "| #{file} | N/A | ❌ No coverage |"
  end
end
```

## Example Scripts

The [`/examples`](/examples) directory contains runnable scripts:

- **[filter_and_table_demo.rb](../examples/filter_and_table_demo.rb)** - Filter and format coverage data
- **[success_predicates/](/examples/success_predicates/)** - Custom coverage policy examples

## Related Documentation

- [CLI Usage Guide](CLI_USAGE.md) - Complete command reference
- [Library API Guide](LIBRARY_API.md) - Ruby API documentation
- [MCP Integration](MCP_INTEGRATION.md) - AI assistant setup
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues
