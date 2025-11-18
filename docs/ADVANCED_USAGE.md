# Advanced Usage Guide

[Back to main README](../README.md)

This guide covers advanced usage patterns, integration strategies, and optimization techniques for simplecov-mcp.

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

The MCP server uses structured error responses. Understanding the error types helps with debugging:

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

**Error Types:**
- `FileError` - File not found in coverage or filesystem
- `FileNotFoundError` - Source file missing from filesystem
- `CoverageDataError` - Invalid or corrupt `.resultset.json`
- `CoverageDataStaleError` - Coverage older than source (single file)
- `CoverageDataProjectStaleError` - Project-wide staleness issues

### MCP Server Logging

The MCP server logs to `simplecov_mcp.log` in the current directory by default. For custom log locations, configure via your MCP client:

**Claude Code (`claude_desktop_config.json`):**
```json
{
  "mcpServers": {
    "simplecov-mcp": {
      "command": "simplecov-mcp",
      "args": ["--log-file", "/var/log/coverage/mcp.log"]
    }
  }
}
```

**Or use environment variables:**
```json
{
  "mcpServers": {
    "simplecov-mcp": {
      "command": "simplecov-mcp",
      "env": {
        "SIMPLECOV_MCP_OPTS": "--log-file /var/log/coverage/mcp.log"
      }
    }
  }
}
```

**To log to standard error:**
```json
{
  "mcpServers": {
    "simplecov-mcp": {
      "command": "simplecov-mcp",
      "args": ["--log-file", "stderr"]
    }
  }
}
```

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
simplecov-mcp --stale error summary lib/model.rb

# Check specific file staleness
simplecov-mcp summary lib/model.rb --stale error
```

**Ruby API:**
```ruby
model = SimpleCovMcp::CoverageModel.new(
  staleness: 'error'
)

begin
  summary = model.summary_for('lib/model.rb')
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
  --tracked-globs "lib/**/*.rb" \
  --tracked-globs "app/**/*.rb"

# Combine with JSON output for parsing
simplecov-mcp list --stale error --json > stale-check.json
```

**Ruby API:**
```ruby
model = SimpleCovMcp::CoverageModel.new(
  staleness: 'error',
  tracked_globs: ['lib/**/*.rb', 'app/**/*.rb']
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

**Example: GitHub Actions**
```yaml
- name: Validate Coverage Freshness
  run: |
    bundle exec rspec
    simplecov-mcp --stale error --tracked-globs "lib/**/*.rb" || {
      echo "Coverage is stale! Re-run tests."
      exit 1
    }
```

**Example: GitLab CI**
```yaml
coverage:validate:
  script:
    - bundle exec rspec
    - simplecov-mcp list --stale error --json > coverage.json
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage.json
```

---

## Advanced Path Resolution

### Multi-Strategy Path Matching

SimpleCov-mcp uses a sophisticated path resolution strategy:

1. **Exact absolute path match**
2. **Relative path resolution from root**
3. **Basename (filename) fallback**

This allows flexible path specifications:

```ruby
model = SimpleCovMcp::CoverageModel.new(root: '/project')

# All these work:
model.summary_for('/project/lib/model.rb')           # Absolute
model.summary_for('lib/model.rb')                    # Relative
model.summary_for('model.rb')                        # Basename only
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

SimpleCov-mcp uses different error handling strategies based on context:

**CLI Mode:**
- User-friendly messages
- Exit codes (0 = success, 1 = error)
- Optional debug mode

**Library Mode:**
- Raises typed exceptions
- Programmatic error handling
- Full exception details

**MCP Server Mode:**
- JSON-RPC error responses
- Logging to file
- Structured error data

### Error Modes

**CLI Error Modes:**
```sh
# Silent mode - minimal output
simplecov-mcp --error-mode off summary lib/model.rb

# Standard mode - user-friendly errors (default)
simplecov-mcp --error-mode on summary lib/model.rb

# Verbose mode - full stack traces
simplecov-mcp --error-mode trace summary lib/model.rb
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

For library integration, provide custom error handlers:

```ruby
class CustomErrorHandler
  def handle_error(error, context: nil)
    # Log to custom service
    ErrorTracker.notify(error, context: context)

    # Re-raise or handle gracefully
    raise error
  end
end

cli = SimpleCovMcp::CoverageCLI.new(
  error_handler: CustomErrorHandler.new
)
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
data = model.summary_for('lib/model.rb')
# => { 'file' => '/project/lib/model.rb', ... }

# Relativize paths
relative_data = model.relativize(data)
# => { 'file' => 'lib/model.rb', ... }

# Works with arrays too
files = model.all_files
relative_files = model.relativize(files)
```

---

## CI/CD Integration Patterns

### GitHub Actions

**Complete Workflow:**
```yaml
name: Coverage Analysis

on: [push, pull_request]

jobs:
  coverage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.2
          bundler-cache: true

      - name: Run tests with coverage
        run: bundle exec rspec

      - name: Install simplecov-mcp
        run: gem install simplecov-mcp

      - name: Validate coverage freshness
        run: |
          simplecov-mcp --stale error \
            --tracked-globs "lib/**/*.rb" \
            --tracked-globs "app/**/*.rb"

      - name: Check minimum coverage
        run: |
          # Export coverage data
          simplecov-mcp list --json > coverage.json

          # Use jq to check minimum threshold
          MIN_COVERAGE=$(jq '[.files[].percentage] | add / length' coverage.json)
          if (( $(echo "$MIN_COVERAGE < 80" | bc -l) )); then
            echo "Coverage below 80%: $MIN_COVERAGE%"
            exit 1
          fi

      - name: Upload coverage report
        uses: actions/upload-artifact@v3
        with:
          name: coverage-report
          path: coverage.json

      - name: Comment PR with coverage
        if: github.event_name == 'pull_request'
        run: |
          COVERAGE=$(simplecov-mcp list)
          gh pr comment ${{ github.event.pull_request.number }} \
            --body "## Coverage Report\n\`\`\`\n$COVERAGE\n\`\`\`"
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### GitLab CI

```yaml
coverage:
  stage: test
  script:
    - bundle exec rspec
    - gem install simplecov-mcp
    - simplecov-mcp --stale error
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/coverage.xml
    paths:
      - coverage/
  coverage: '/TOTAL.*\s(\d+\.\d+)%/'
```

### Jenkins Pipeline

```groovy
pipeline {
    agent any

    stages {
        stage('Test') {
            steps {
                sh 'bundle exec rspec'
            }
        }

        stage('Coverage Analysis') {
            steps {
                sh 'gem install simplecov-mcp'
                sh '''
                    simplecov-mcp list --json > coverage.json
                    simplecov-mcp --stale error || exit 1
                '''
            }
        }

        stage('Coverage Report') {
            steps {
                publishHTML([
                    reportDir: 'coverage',
                    reportFiles: 'index.html',
                    reportName: 'Coverage Report'
                ])
            }
        }
    }
}
```

### Pre-commit Hooks

```sh
#!/bin/bash
# .git/hooks/pre-commit

# Run tests
bundle exec rspec || exit 1

# Validate coverage
simplecov-mcp --stale error --tracked-globs "lib/**/*.rb" || {
    echo "Coverage validation failed!"
    echo "Re-run tests or review coverage changes."
    exit 1
}

# Check for files with low coverage
LOW_COVERAGE=$(simplecov-mcp list --json | \
    jq -r '.files[] | select(.percentage < 80) | .file' | \
    head -5)

if [ -n "$LOW_COVERAGE" ]; then
    echo "Warning: Files with coverage below 80%:"
    echo "$LOW_COVERAGE"
fi
```

### Using Success Predicates in CI/CD

Use `--success-predicate` to enforce coverage policies:

**GitHub Actions:**
```yaml
- name: Enforce Coverage Policy
  run: |
    bundle exec rspec
    bundle exec simplecov-mcp --success-predicate coverage_policy.rb
```

**GitLab CI:**
```yaml
coverage:enforce:
  script:
    - bundle exec rspec
    - bundle exec simplecov-mcp --success-predicate coverage_policy.rb
```

**Jenkins:**
```groovy
stage('Coverage Policy') {
    steps {
        sh 'bundle exec rspec'
        sh 'bundle exec simplecov-mcp --success-predicate coverage_policy.rb'
    }
}
```

The build will fail (exit code 1) if the predicate returns falsy.

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
--tracked-globs "lib/**/*.rb" --tracked-globs "app/**/*.rb"

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
simplecov-mcp uncovered lib/model.rb \
  --source uncovered \
  --source-context 3

# Show full file with coverage annotations
simplecov-mcp uncovered lib/model.rb \
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

puts annotate_source('lib/model.rb')
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

