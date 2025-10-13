# Examples and Recipes

Practical examples for common tasks with simplecov-mcp. Examples are organized by skill level and use case.

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
simplecov-mcp

# Show files with best coverage first
simplecov-mcp list --sort-order descending

# Export to JSON for processing
simplecov-mcp list --json > coverage-report.json
```

### Check Specific File

```bash
# Quick summary
simplecov-mcp summary lib/my_class.rb

# See which lines aren't covered
simplecov-mcp uncovered lib/my_class.rb

# View uncovered code with context
simplecov-mcp uncovered lib/my_class.rb --source=uncovered --source-context 3
```

### Find Coverage Gaps

```bash
# Files with worst coverage
simplecov-mcp list | head -10

# Only show files below 80%
simplecov-mcp list --json | jq '.files[] | select(.percentage < 80)'

# Check specific directory
simplecov-mcp list --tracked-globs "lib/services/**/*.rb"
```

## CLI Examples

### Coverage Analysis

**Find files needing attention:**
```bash
# Show only lib/ files
simplecov-mcp list --tracked-globs "lib/**/*.rb"

# Get uncovered line counts
simplecov-mcp list --json | jq '.files[] | {file: .file, uncovered: (.total - .covered)}'
```

**Detailed investigation:**
```bash
# See detailed hit counts
simplecov-mcp detailed lib/auth_service.rb

# Show full source with coverage markers
simplecov-mcp summary lib/auth_service.rb --source=full

# Focus on uncovered areas only
simplecov-mcp uncovered lib/auth_service.rb --source=uncovered --source-context 5
```

### Working with JSON Output

**Parse and filter:**
```bash
# Files below threshold
simplecov-mcp list --json | jq '.files[] | select(.percentage < 90) | {file, coverage: .percentage}'

# Count total uncovered lines
simplecov-mcp list --json | jq '[.files[] | (.total - .covered)] | add'

# Group by directory
simplecov-mcp list --json | jq 'group_by(.file | split("/")[0]) | map({dir: .[0].file | split("/")[0], avg: (map(.percentage) | add / length)})'
```

**Generate reports:**
```bash
# Create markdown table
echo "| File | Coverage |" > report.md
echo "|------|----------|" >> report.md
simplecov-mcp list --json | jq -r '.files[] | "| \(.file) | \(.percentage)% |"' >> report.md

# Export for spreadsheet
simplecov-mcp list --json | jq -r '.files[] | [.file, .percentage] | @csv' > coverage.csv
```

## Ruby Library Examples

### Basic Usage

```ruby
require "simplecov_mcp"

model = SimpleCovMcp::CoverageModel.new

# Get all files with coverage
files = model.all_files
puts "Total files: #{files.length}"
puts "Average coverage: #{files.sum { |f| f['percentage'] } / files.length}%"

# Check specific file
summary = model.summary_for("lib/auth_service.rb")
puts "Coverage: #{summary['summary']['pct']}%"

# Find uncovered lines
uncovered = model.uncovered_for("lib/auth_service.rb")
puts "Uncovered lines: #{uncovered['uncovered'].join(', ')}"
```

### Filtering and Analysis

```ruby
require "simplecov_mcp"

model = SimpleCovMcp::CoverageModel.new
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

# Group by directory
by_dir = all_files.group_by { |f| File.dirname(f['file']) }
by_dir.each do |dir, files|
  avg = files.sum { |f| f['percentage'] } / files.length
  puts "#{dir}: #{avg.round(2)}% (#{files.length} files)"
end
```

### Custom Formatting

```ruby
require "simplecov_mcp"

model = SimpleCovMcp::CoverageModel.new
all_files = model.all_files

# Filter to specific directory
lib_files = all_files.select { |f| f['file'].start_with?('lib/') }

# Generate custom table
table = model.format_table(lib_files, sort_order: :ascending)
puts table

# Or create your own format
lib_files.each do |file|
  status = file['percentage'] >= 90 ? '✓' : '⚠'
  puts "#{status} #{file['file']}: #{file['percentage']}%"
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
Using simplecov-mcp, analyze the lib/services/ directory and identify which files should be prioritized for additional testing based on coverage gaps and file complexity.
```

### Finding Specific Issues

```
Using simplecov-mcp, show me the uncovered lines in lib/auth_service.rb with 5 lines of context around each uncovered block.
```

```
Using simplecov-mcp, find all files in lib/models/ with less than 80% coverage and list the specific uncovered line numbers for each.
```

### Test Generation

```
Using simplecov-mcp, identify the uncovered lines in lib/payment_processor.rb and write RSpec tests to cover them.
```

```
Using simplecov-mcp, analyze coverage gaps in the lib/api/ directory and generate a test plan prioritizing:
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
          simplecov-mcp list --json > coverage.json
          BELOW_THRESHOLD=$(jq '[.files[] | select(.percentage < 80)] | length' coverage.json)
          if [ "$BELOW_THRESHOLD" -gt 0 ]; then
            echo "❌ $BELOW_THRESHOLD files below 80% coverage"
            jq -r '.files[] | select(.percentage < 80) | "\(.file): \(.percentage)%"' coverage.json
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
  avg_coverage = all_files.sum { |f| f['percentage'] } / all_files.length
  return false if avg_coverage < 80.0

  # No files below 60%
  return false if all_files.any? { |f| f['percentage'] < 60.0 }

  # lib/ files must average 90%
  lib_files = all_files.select { |f| f['file'].start_with?('lib/') }
  lib_avg = lib_files.sum { |f| f['percentage'] } / lib_files.length
  return false if lib_avg < 90.0

  true
end
```

```bash
# Use in CI
simplecov-mcp --success-predicate coverage_policy.rb
```

## Advanced Usage

### Directory-Level Analysis

```ruby
require "simplecov_mcp"

model = SimpleCovMcp::CoverageModel.new
all_files = model.all_files

# Calculate coverage by directory
by_directory = all_files.group_by { |f| f['file'].split('/')[0..1].join('/') }

results = by_directory.map do |dir, files|
  total_lines = files.sum { |f| f['total'] }
  covered_lines = files.sum { |f| f['covered'] }
  percentage = (covered_lines.to_f / total_lines * 100).round(2)

  {
    directory: dir,
    files: files.length,
    coverage: percentage,
    covered: covered_lines,
    total: total_lines
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
model = SimpleCovMcp::CoverageModel.new
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
    pct = summary['summary']['pct']
    status = pct >= 80 ? '✅' : '⚠️'
    puts "| #{file} | #{pct}% | #{status} |"
  rescue
    puts "| #{file} | N/A | ❌ No coverage |"
  end
end
```

## Example Scripts

The [`/examples`](/examples) directory contains runnable scripts:

- **[filter_and_table_demo.rb](/examples/filter_and_table_demo.rb)** - Filter and format coverage data
- **[success_predicates/](/examples/success_predicates/)** - Custom coverage policy examples

## Related Documentation

- [CLI Usage Guide](CLI_USAGE.md) - Complete command reference
- [Library API Guide](LIBRARY_API.md) - Ruby API documentation
- [MCP Integration](MCP_INTEGRATION.md) - AI assistant setup
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues
