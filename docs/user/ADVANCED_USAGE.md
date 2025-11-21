# Advanced Usage Guide

[Back to main README](../README.md)

## Table of Contents

- [Advanced MCP Integration](#advanced-mcp-integration)
- [Staleness Detection & Validation](#staleness-detection--validation)
- [Advanced Path Resolution](#advanced-path-resolution)
- [Error Handling Strategies](#error-handling-strategies)
- [Custom Ruby Integration](#custom-ruby-integration)
- [CI/CD Integration Patterns](#cicd-integration-patterns)
- [Advanced Filtering & Glob Patterns](#advanced-filtering--glob-patterns)
- [Performance Optimization](#performance-optimization)
- [Custom Output Processing](#custom-output-processing)

---

## Advanced MCP Integration

### MCP Error Handling

The MCP server uses structured error responses:

```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32603,
    "message": "Coverage data not found at coverage/.resultset.json",
    "data": {
      "type": "FileError",
      "context": "MCP tool execution"
    }
  },
  "id": 1
}
```

### MCP Server Logging

The MCP server logs to `simplecov_mcp.log` in the current directory by default.

To override the default log file location, specify the `--log-file` argument wherever and however you configure your MCP server. For example, to log to a different file path, include `--log-file /path/to/logfile.log` in your server configuration. To log to standard error, use `--log-file stderr`.

**Note:** Logging to `stdout` is not permitted in MCP mode.

### Testing MCP Server Manually

Use JSON-RPC over stdin to test the MCP server:

```sh
# Get version
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"version_tool","arguments":{}}}' | simplecov-mcp

# Get file summary
echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"coverage_summary_tool","arguments":{"path":"lib/simplecov_mcp/model.rb"}}}' | simplecov-mcp

# List all files with sorting
echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"all_files_coverage_tool","arguments":{"sort_order":"ascending"}}}' | simplecov-mcp

# Get uncovered lines
echo '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"uncovered_lines_tool","arguments":{"path":"lib/simplecov_mcp/cli.rb"}}}' | simplecov-mcp
```

---

## Staleness Detection & Validation

### Understanding Staleness Modes

Staleness checking prevents using outdated coverage data. Two modes are available:

**Mode: `off` (default)**
- No validation, fastest operation
- Coverage data used as-is
- Stale indicators still computed but don't block operations

**Mode: `error`**
- Strict validation enabled
- Raises errors if coverage is outdated
- Perfect for CI/CD pipelines

### File-Level Staleness

A file is considered stale when any of the following are true:
1. Source file modified after coverage generation
2. Line count differs from coverage array length
3. File exists in coverage but deleted from filesystem

**CLI Usage:**
```sh
# Fail if any file is stale
simplecov-mcp --stale error summary lib/simplecov_mcp/model.rb

# Check specific file staleness
simplecov-mcp summary lib/simplecov_mcp/model.rb --stale error
```

**Ruby API:**
```ruby
model = SimpleCovMcp::CoverageModel.new(
  staleness: 'error'
)

begin
  summary = model.summary_for('lib/simplecov_mcp/model.rb')
rescue SimpleCovMcp::CoverageDataStaleError => e
  puts "File modified after coverage: #{e.file_path}"
  puts "Coverage timestamp: #{e.cov_timestamp}"
  puts "File mtime: #{e.file_mtime}"
  puts "Source lines: #{e.src_len}, Coverage lines: #{e.cov_len}"
end
```

### Project-Level Staleness

Detects system-wide staleness issues:

**Conditions Checked:**
1. **Newer files** - Any tracked file modified after coverage
2. **Missing files** - Tracked files with no coverage data
3. **Deleted files** - Coverage exists for non-existent files

**CLI Usage:**
```sh
# Track specific patterns
simplecov-mcp --stale error \
  --tracked-globs "lib/simplecov_mcp/tools/**/*.rb" \
  --tracked-globs "lib/simplecov_mcp/commands/**/*.rb"

# Combine with JSON output for parsing
simplecov-mcp list --stale error --json > stale-check.json
```

**Ruby API:**
```ruby
model = SimpleCovMcp::CoverageModel.new(
  staleness: 'error',
  tracked_globs: ['lib/simplecov_mcp/tools/**/*.rb', 'lib/simplecov_mcp/commands/**/*.rb']
)

begin
  files = model.all_files(check_stale: true)
rescue SimpleCovMcp::CoverageDataProjectStaleError => e
  puts "Newer files: #{e.newer_files.join(', ')}"
  puts "Missing from coverage: #{e.missing_files.join(', ')}"
  puts "Deleted but in coverage: #{e.deleted_files.join(', ')}"
end
```

### Staleness in CI/CD

Staleness checking is particularly useful in CI/CD pipelines to ensure coverage data is fresh:

```sh
# Run tests to generate coverage
bundle exec rspec

# Validate coverage freshness (fails with exit code 1 if stale)
simplecov-mcp --stale error --tracked-globs "lib/**/*.rb"

# Export validated data for CI artifacts
simplecov-mcp list --json > coverage.json
```

The `--stale error` flag causes the command to exit with a non-zero status when coverage is outdated, making it suitable for pipeline failure conditions.

---

## Advanced Path Resolution

### Multi-Strategy Path Matching

Path resolution order:

1. **Exact absolute path match**
2. **Relative path resolution from root**

```ruby
model = SimpleCovMcp::CoverageModel.new(root: '/project')

model.summary_for('/project/lib/simplecov_mcp/model.rb')  # Absolute
model.summary_for('lib/simplecov_mcp/model.rb')           # Relative
```

### Working with Multiple Projects

```ruby
# Project A
model_a = SimpleCovMcp::CoverageModel.new(
  root: '/projects/service-a',
  resultset: '/projects/service-a/coverage/.resultset.json'
)

# Project B
model_b = SimpleCovMcp::CoverageModel.new(
  root: '/projects/service-b',
  resultset: '/projects/service-b/tmp/coverage/.resultset.json'
)

# Compare coverage
coverage_a = model_a.all_files
coverage_b = model_b.all_files
```




---

## Error Handling Strategies

### Context-Aware Error Handling

**CLI Mode:** user-facing messages, exit codes, optional debug mode

**Library Mode:** typed exceptions with full details

**MCP Server Mode:** JSON-RPC errors logged to file with structured data

### Error Modes

**CLI Error Modes:**
```sh
# Silent mode - minimal output
simplecov-mcp --error-mode off summary lib/simplecov_mcp/model.rb

# Standard mode - user-friendly errors (default)
simplecov-mcp --error-mode on summary lib/simplecov_mcp/model.rb

# Verbose mode - full stack traces
simplecov-mcp --error-mode trace summary lib/simplecov_mcp/model.rb
```

**Ruby API Error Handling:**
```ruby
require 'simplecov_mcp'

begin
  model = SimpleCovMcp::CoverageModel.new(
    root: '/project',
    resultset: '/nonexistent/.resultset.json'
  )
rescue SimpleCovMcp::FileError => e
  # Handle missing resultset
  puts "Coverage file not found: #{e.message}"
rescue SimpleCovMcp::CoverageDataError => e
  # Handle corrupt/invalid coverage data
  puts "Invalid coverage data: #{e.message}"
end
```

### Custom Error Handlers

Provide custom error handlers when embedding the CLI:

```ruby
class CustomErrorHandler
  def handle_error(error, context: nil)
    # Log to custom service
    ErrorTracker.notify(error, context: context)

    # Re-raise or handle gracefully
    raise error
  end
end

cli = SimpleCovMcp::CoverageCLI.new(error_handler: CustomErrorHandler.new)
```

---

## Custom Ruby Integration

### Building Custom Coverage Policies

Use `--success-predicate` to enforce custom coverage policies in CI/CD. Example predicates are in [`examples/success_predicates/`](../../examples/success_predicates/).

> **⚠️ SECURITY WARNING**
>
> Success predicates execute as **arbitrary Ruby code with full system privileges**. They have unrestricted access to:
> - File system operations (read, write, delete)
> - Network operations (HTTP requests, sockets)
> - System commands (via backticks, `system()`, `exec()`, etc.)
> - Environment variables and sensitive data
>
> **Only use predicate files from trusted sources.** Treat them like any other executable code in your project.
> - Never use predicates from untrusted or unknown sources
> - Review predicates before use, especially in CI/CD environments
> - Store predicates in version control with code review
> - Be cautious when copying examples from the internet

**Quick Usage:**
```sh
# All files must be >= 80%
simplecov-mcp --success-predicate examples/success_predicates/all_files_above_threshold_predicate.rb

# Total project coverage >= 85%
simplecov-mcp --success-predicate examples/success_predicates/project_coverage_minimum_predicate.rb

# Custom predicate
simplecov-mcp --success-predicate coverage_policy.rb
```

**Creating a predicate:**
```ruby
# coverage_policy.rb
->(model) do
  # All files must have >= 80% coverage
  model.all_files.all? { |f| f['percentage'] >= 80 }
end
```

**Advanced predicate with reporting:**

```ruby
# coverage_policy.rb
class CoveragePolicy
  def call(model)
    threshold = 80
    low_files = model.all_files.select { |f| f['percentage'] < threshold }

    if low_files.empty?
      puts "✓ All files have >= #{threshold}% coverage"
      true
    else
      warn "✗ Files below #{threshold}%:"
      low_files.each { |f| warn "  #{f['file']}: #{f['percentage']}%" }
      false
    end
  end
end

AllFilesAboveThreshold.new
```

**Exit codes:**
- `0` - Predicate returned truthy (pass)
- `1` - Predicate returned falsy (fail)
- `2` - Predicate raised an error

See [examples/success_predicates/README.md](../../examples/success_predicates/README.md) for more examples.

### Path Relativization

Convert absolute paths to relative for cleaner output:

```ruby
model = SimpleCovMcp::CoverageModel.new(root: '/project')

# Get data with absolute paths
data = model.summary_for('lib/simplecov_mcp/model.rb')
# => { 'file' => '/project/lib/simplecov_mcp/model.rb', ... }

# Relativize paths
relative_data = model.relativize(data)
# => { 'file' => 'lib/simplecov_mcp/model.rb', ... }

# Works with arrays too
files = model.all_files
relative_files = model.relativize(files)
```

---

## CI/CD Integration

The CLI is designed for CI/CD use with features that integrate naturally into pipeline workflows:

### Key Integration Features

- **Exit codes**: Non-zero on failure, making it suitable for pipeline failure conditions
- **JSON output**: `--json` flag for parsing by CI tools and custom processing
- **Staleness checking**: `--stale error` to fail on outdated coverage data
- **Success predicates**: Custom Ruby policies for coverage enforcement

### Basic CI Pattern

```bash
# 1. Run tests to generate coverage
bundle exec rspec

# 2. Validate coverage freshness (fails with exit code 1 if stale)
simplecov-mcp --stale error --tracked-globs "lib/**/*.rb"

# 3. Export data for CI artifacts or further processing
simplecov-mcp list --json > coverage.json
```

### Using Success Predicates

Enforce custom coverage policies with `--success-predicate`:

```bash
# Run tests
bundle exec rspec

# Apply coverage policy (fails with exit code 1 if predicate returns false)
simplecov-mcp --success-predicate coverage_policy.rb
```

Exit codes:
- `0` - Success (coverage meets requirements)
- `1` - Failure (coverage policy not met or stale data detected)
- `2` - Error (invalid predicate or system error)

### Platform-Specific Examples

For platform-specific integration examples (GitHub Actions, GitLab CI, Jenkins, CircleCI, etc.), see community contributions in the [GitHub Discussions](https://github.com/simplecov-ruby/simplecov-mcp/discussions).

---

## Advanced Filtering & Glob Patterns

### Tracked Globs Overview

Tracked globs serve two purposes:
1. **Filter output** - Only show matching files
2. **Validate coverage** - Ensure new files have coverage

### Pattern Syntax

Uses Ruby's `File.fnmatch` with extended glob support:

```sh
# Single directory
--tracked-globs "lib/**/*.rb"

# Multiple patterns
--tracked-globs "lib/simplecov_mcp/tools/**/*.rb" --tracked-globs "lib/simplecov_mcp/commands/**/*.rb"

# Exclude patterns (use CLI filtering)
simplecov-mcp list --json | jq '.files[] | select(.file | test("spec") | not)'

# Complex patterns
--tracked-globs "lib/{models,controllers}/**/*.rb"
--tracked-globs "app/**/concerns/*.rb"
```

### Use Cases

**1. Monitor Subsystem Coverage:**
```sh
# API layer only
simplecov-mcp list --tracked-globs "lib/api/**/*.rb"

# Core business logic
simplecov-mcp list --tracked-globs "lib/domain/**/*.rb"
```

**2. Ensure New Files Have Coverage:**
```sh
# Fail if any tracked file lacks coverage
simplecov-mcp --stale error \
  --tracked-globs "lib/features/**/*.rb"
```

**3. Multi-tier Reporting:**
```sh
# Generate separate reports per layer
for layer in models views controllers; do
  simplecov-mcp list \
    --tracked-globs "app/${layer}/**/*.rb" \
    --json > "coverage-${layer}.json"
done
```

### Ruby API with Globs

```ruby
model = SimpleCovMcp::CoverageModel.new

# Filter files in output
api_files = model.all_files(
  tracked_globs: ['lib/api/**/*.rb']
)

# Multi-pattern filtering
core_files = model.all_files(
  tracked_globs: [
    'lib/core/**/*.rb',
    'lib/domain/**/*.rb'
  ]
)

# Validate specific subsystems
begin
  model.all_files(
    check_stale: true,
    tracked_globs: ['lib/critical/**/*.rb']
  )
rescue SimpleCovMcp::CoverageDataProjectStaleError => e
  # Handle missing coverage for critical files
  puts "Critical files missing coverage:"
  e.missing_files.each { |f| puts "  - #{f}" }
end
```

---

## Performance Optimization

### Minimizing Coverage Reads

The `CoverageModel` reads `.resultset.json` once at initialization:

```ruby
# Good: Single model for multiple queries
model = SimpleCovMcp::CoverageModel.new
files = model.all_files
file1 = model.summary_for('lib/a.rb')
file2 = model.summary_for('lib/b.rb')

# Bad: Re-reads coverage for each operation
model1 = SimpleCovMcp::CoverageModel.new
files = model1.all_files

model2 = SimpleCovMcp::CoverageModel.new
file1 = model2.summary_for('lib/a.rb')
```

### Batch Processing

```ruby
# Process multiple files in one pass
files_to_analyze = ['lib/a.rb', 'lib/b.rb', 'lib/c.rb']
model = SimpleCovMcp::CoverageModel.new

results = files_to_analyze.each_with_object({}) do |file, hash|
  hash[file] = {
    summary: model.summary_for(file),
    uncovered: model.uncovered_for(file)
  }
rescue SimpleCovMcp::FileError
  hash[file] = { error: 'No coverage' }
end
```

### Filtering Early

Use `tracked_globs` to reduce data processing:

```ruby
# Bad: Filter after loading all data
all_files = model.all_files
api_files = all_files.select { |f| f['file'].include?('api') }

# Good: Filter during query
api_files = model.all_files(
  tracked_globs: ['lib/api/**/*.rb']
)
```

### Caching Coverage Models

For long-running processes:

```ruby
class CoverageCache
  def initialize(ttl: 300) # 5 minute cache
    @cache = {}
    @ttl = ttl
  end

  def model_for(root)
    key = root.to_s
    now = Time.now

    if @cache[key] && (now - @cache[key][:time] < @ttl)
      @cache[key][:model]
    else
      @cache[key] = {
        model: SimpleCovMcp::CoverageModel.new(root: root),
        time: now
      }
      @cache[key][:model]
    end
  end
end

cache = CoverageCache.new
model = cache.model_for('/project')
```

---

## Custom Output Processing

### Format Conversion

**CSV Export:**
```ruby
require 'csv'

model = SimpleCovMcp::CoverageModel.new
files = model.all_files

CSV.open('coverage.csv', 'w') do |csv|
  csv << ['File', 'Coverage %', 'Lines Covered', 'Total Lines', 'Stale']
  files.each do |f|
    csv << [
      model.relativize(f)['file'],
      f['percentage'],
      f['covered'],
      f['total'],
      f['stale']
    ]
  end
end
```

**HTML Report:**
```ruby
require 'erb'

template = ERB.new(<<~HTML)
  <html>
    <head><title>Coverage Report</title></head>
    <body>
      <h1>Coverage Report</h1>
      <table>
        <tr>
          <th>File</th><th>Coverage</th><th>Covered</th><th>Total</th>
        </tr>
        <% files.each do |f| %>
          <tr class="<%= f['percentage'] < 80 ? 'low' : 'ok' %>">
            <td><%= f['file'] %></td>
            <td><%= f['percentage'].round(2) %>%</td>
            <td><%= f['covered'] %></td>
            <td><%= f['total'] %></td>
          </tr>
        <% end %>
      </table>
    </body>
  </html>
HTML

model = SimpleCovMcp::CoverageModel.new
files = model.relativize(model.all_files)
File.write('coverage.html', template.result(binding))
```

### Annotated Source Output

The CLI supports annotated source viewing:

```sh
# Show uncovered lines with context
simplecov-mcp uncovered lib/simplecov_mcp/model.rb \
  --source uncovered \
  --source-context 3

# Show full file with coverage annotations
simplecov-mcp uncovered lib/simplecov_mcp/model.rb \
  --source full \
  --source-context 0
```

**Programmatic Source Annotation:**
```ruby
def annotate_source(file_path)
  model = SimpleCovMcp::CoverageModel.new
  details = model.detailed_for(file_path)
  source_lines = File.readlines(file_path)

  output = []
  details['lines'].each do |line_data|
    line_num = line_data['line']
    hits = line_data['hits']
    source = source_lines[line_num - 1]

    marker = case hits
             when nil then '     '
             when 0   then '  ✗  '
             else          "  #{hits}  "
             end

    output << "#{marker}#{line_num.to_s.rjust(4)}: #{source}"
  end

  output.join
end

puts annotate_source('lib/simplecov_mcp/model.rb')
```

### Integration with Coverage Trackers

**Send to Codecov:**
```sh
#!/bin/bash
bundle exec rspec
simplecov-mcp list --json > coverage.json

# Transform to Codecov format (example)
jq '{
  coverage: [
    .files[] | {
      name: .file,
      coverage: .percentage
    }
  ]
}' coverage.json | curl -X POST \
  -H "Authorization: token $CODECOV_TOKEN" \
  -d @- https://codecov.io/upload
```

**Send to Coveralls:**
```ruby
require 'simplecov_mcp'
require 'net/http'
require 'json'

model = SimpleCovMcp::CoverageModel.new
files = model.all_files

coveralls_data = {
  repo_token: ENV['COVERALLS_REPO_TOKEN'],
  source_files: files.map { |f|
    {
      name: f['file'],
      coverage: model.raw_for(f['file'])['lines']
    }
  }
}

uri = URI('https://coveralls.io/api/v1/jobs')
Net::HTTP.post(uri, coveralls_data.to_json, {
  'Content-Type' => 'application/json'
})
```

---

## Additional Resources

- [CLI Usage Guide](CLI_USAGE.md)
- [Library API Reference](LIBRARY_API.md)
- [MCP Integration Guide](MCP_INTEGRATION.md)
- [Error Handling Details](ERROR_HANDLING.md)
- [Troubleshooting](TROUBLESHOOTING.md)
