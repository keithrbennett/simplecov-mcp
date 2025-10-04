# Examples and Recipes

This document provides a collection of examples and common recipes for using `simplecov-mcp`.

## Example Scripts

The [`/examples`](/examples) directory in the repository contains runnable Ruby scripts and other resources demonstrating various features.

- **[filter_and_table_demo.rb](/examples/filter_and_table_demo.rb):** A comprehensive script showing how to use `simplecov-mcp` as a library to filter coverage data by directory, pattern, and threshold, and then generate custom tables.

## CI/CD Recipes

### Fail CI on Low Coverage

You can use `simplecov-mcp` in your CI/CD pipeline to enforce coverage standards.

**Fail CI if any file has uncovered lines:**

```ruby
# scripts/ci_check_coverage.rb
require "simplecov_mcp"

model = SimpleCovMcp::CoverageModel.new(root: Dir.pwd)
all_files_data = model.all_files

# Find files with less than 100% coverage
low_coverage_files = all_files_data.select { |f| f['percentage'] < 100.0 }

if low_coverage_files.any?
  puts "❌ The following files have uncovered lines:"
  low_coverage_files.each do |file|
    puts "- #{file['file']}: #{file['percentage']}%"
  end
  exit 1
else
  puts "✅ All files are 100% covered!"
  exit 0
end
```

**Enforce a project-wide minimum percentage:**

```ruby
# scripts/ci_check_threshold.rb
require "simplecov_mcp"

THRESHOLD = 90.0

model = SimpleCovMcp::CoverageModel.new(root: Dir.pwd)
all_files_data = model.all_files

# Find files below the threshold
offenders = all_files_data.select { |f| f['percentage'] < THRESHOLD }

if offenders.any?
  puts "❌ The following files are below the #{THRESHOLD}% coverage threshold:"
  offenders.each do |file|
    puts "- #{file['file']}: #{file['percentage']}%"
  end
  exit 1
else
  puts "✅ All files meet the #{THRESHOLD}% coverage threshold."
  exit 0
end
```

## Example Prompts for AI Assistants

Here are some example prompts you can use with an MCP-enabled AI assistant.

**Basic Queries:**
```
Using simplecov-mcp, show me a table of all files and their coverages.
```

```
Using simplecov-mcp, what is the coverage summary for the file `lib/simplecov_mcp/cli.rb`?
```

**Finding Gaps:**
```
Using simplecov-mcp, find the uncovered code lines in `lib/simplecov_mcp/model.rb` and show them to me with 3 lines of context.
```

**Analysis and Reporting:**
```
Using simplecov-mcp, find the 5 files with the lowest coverage percentage and create a markdown table summarizing them.
```

```
Using simplecov-mcp, analyze the risk of the current state of coverage and propose a plan of action to improve it, focusing on the most critical files first.
```

For more prompts, see the [`/examples/prompts`](/examples/prompts) directory.
