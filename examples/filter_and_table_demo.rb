#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Using simplecov-mcp as a library to filter and format coverage tables
# This demonstrates filtering files by directory and other criteria, then generating tables

require_relative '../lib/simplecov_mcp'

def check_coverage_data
  unless File.exist?('spec/fixtures/project1/coverage/.resultset.json')
    puts <<~EOS
      Error: Coverage data file not found.

      Please run this script from project root directory:

          examples/filter_and_table_demo.rb

      If coverage data is missing, run tests first to generate it:

          bundle exec rspec
    EOS
    exit 1
  end
end

def output_examples
  puts <<~EOS
    # simplecov-mcp Library Usage Examples
    =============================================

  EOS

  # Initialize coverage model
  # Using the built-in coverage data from running specs
  model = SimpleCovMcp::CoverageModel.new(
    root: '.',
    resultset: 'spec/fixtures/project1/coverage'
  )

  puts <<~EOS
    ## 1. Full Coverage Table
    ```
    #{model.format_table}
    ```

  EOS

  puts <<~EOS
    ## 2. Filter by Directory (lib/ only)
    ```ruby
    # Filter files by directory (e.g., only show files in lib/)
    all_files_data = model.all_files
    lib_files = all_files_data.select { |file| file["file"].include?("/lib/") }
    lib_files_table = model.format_table(lib_files)
    # => formatted table showing only files from lib/ directory
    ```

  EOS

  # Execute the code
  all_files_data = model.all_files
  lib_files = all_files_data.select { |file| file['file'].include?('/lib/') }
  lib_files_table = model.format_table(lib_files)
  puts <<~EOS
    Result:
    ```
    #{lib_files_table}
    ```

  EOS

  puts <<~EOS
    ## 3. Filter by Pattern (files with specific naming)
    ```ruby
    # Filter by pattern (e.g., only show files with "foo" in name)
    foo_files = all_files_data.select { |file| file["file"].include?("foo") }
    foo_table = model.format_table(foo_files)
    # => formatted table showing only files with 'foo' in filename
    ```

  EOS

  # Execute the code
  foo_files = all_files_data.select { |file| file['file'].include?('foo') }
  foo_table = model.format_table(foo_files)
  puts <<~EOS
    Result:
    ```
    #{foo_table}
    ```

    EOS

  puts <<~EOS
    ## 4. Filter by Coverage Threshold (only high-coverage files)
    ```ruby
    # Filter by coverage percentage (e.g., only files >= 50% coverage)
    high_coverage_files = all_files_data.select { |file| file["percentage"] >= 50.0 }
    high_coverage_table = model.format_table(high_coverage_files)
    # => formatted table showing only well-covered files
    ```

    EOS

  # Execute the code
  high_coverage_files = all_files_data.select { |file| file['percentage'] >= 50.0 }
  high_coverage_table = model.format_table(high_coverage_files)
  puts <<~EOS
    Result:
    ```
    #{high_coverage_table}
    ```

    EOS

  puts <<~EOS
    ## 5. Staleness Analysis
    ```ruby
    # Analyze coverage staleness to find potentially problematic files
    stale_files, healthy_files = all_files_data.partition { |file| file["stale"] }

    puts "## Potentially Stale Coverage Files"
    puts model.format_table(stale_files, sort_order: :descending)

    puts "## Healthy Coverage Files"
    puts model.format_table(healthy_files, sort_order: :descending)
    ```

    EOS

  # Execute the stale analysis
  stale_files, healthy_files = all_files_data.partition { |file| file['stale'] }

  puts 'Result:'
  puts '```'
  puts '## Potentially Stale Coverage Files'
  puts model.format_table(stale_files, sort_order: :descending) if stale_files.any?
  puts '(No stale files found)' if stale_files.empty?
  puts
  puts '## Healthy Coverage Files'
  puts model.format_table(healthy_files, sort_order: :descending) if healthy_files.any?
  puts '(No healthy files found)' if healthy_files.empty?
  puts '```'
  puts
  puts 'NOTE: To see staleness analysis in action with both stale and healthy files,'
  puts 'try modifying file timestamps:'
  puts '  - Make one file appear older: `touch -t 202401010000 spec/fixtures/project1/lib/foo.rb`'
  puts '  - Or make one file appear newer: `touch spec/fixtures/project1/lib/bar.rb`'
  puts 'Then run this script again to see partition results change.'
  puts

  puts <<~EOS
    ## Summary
    This example demonstrates how simplecov-mcp can be used as a library to:
    - Load and query coverage data
    - Filter files by various criteria (directory, filename, coverage threshold)
    - Perform staleness analysis to identify potentially problematic files
    - Generate CI/CD integration reports with exit codes for monitoring
    - Create custom reports tailored to specific needs

    The table formatting functionality (format_table) is now accessible
    directly in library mode, not just through the CLI!
  EOS
end


def main
  check_coverage_data
  output_examples
end

main if __FILE__ == $0
