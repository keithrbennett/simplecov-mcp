# ADR 003: Coverage Staleness Detection

[Back to main README](../../README.md)

## Status

Accepted

## Context

Coverage data can become outdated when source files are modified after tests run. This creates misleading results:

- Coverage percentages appear lower/higher than reality
- Line numbers in coverage reports don't match the current source
- AI agents and users may make decisions based on stale data

We needed a staleness detection system that could:

1. Detect when source files have been modified since coverage was collected
2. Detect when source files have different line counts than coverage data
3. Handle edge cases (deleted files, files without trailing newlines)
4. Support both file-level and project-level checks
5. Allow users to control whether staleness is reported or causes errors

### Alternative Approaches Considered

1. **No staleness checking**: Simple, but leads to confusing/incorrect reports
2. **Single timestamp check**: Fast, but misses line count mismatches (files edited and reverted)
3. **Content hashing**: Accurate, but expensive for large projects
4. **Multi-type detection with modes**: More complex, but provides accurate detection with user control

## Decision

We implemented a **three-type staleness detection system** with configurable error modes.

### Three Staleness Types

The `StalenessChecker` class (lib/simplecov_mcp/staleness_checker.rb:8) detects three distinct types of staleness:

1. **Type 'M' (Missing)**: The source file exists in coverage but is now deleted/missing
   - Returned by `stale_for_file?` when `File.file?(file_abs)` returns false
   - Example: File was deleted after tests ran

2. **Type 'T' (Timestamp)**: The source file's mtime is newer than the coverage timestamp
   - Detected by comparing `File.mtime(file_abs)` with coverage timestamp
   - Example: File was edited after tests ran

3. **Type 'L' (Length)**: The source file line count doesn't match the coverage lines array length
   - Detected by comparing `File.foreach(path).count` with `coverage_lines.length`
   - Handles edge case: Files without trailing newlines (adjusts count by 1)
   - Example: Lines were added/removed without changing mtime (rare but possible with version control)

### Implementation Details

The core algorithm is in `compute_file_staleness_details` (lib/simplecov_mcp/staleness_checker.rb:137):

```ruby
def compute_file_staleness_details(file_abs, coverage_lines)
  coverage_ts = coverage_timestamp
  exists = File.file?(file_abs)
  file_mtime = exists ? File.mtime(file_abs) : nil

  cov_len = coverage_lines.respond_to?(:length) ? coverage_lines.length : 0
  src_len = exists ? safe_count_lines(file_abs) : 0

  newer = !!(file_mtime && file_mtime.to_i > coverage_ts.to_i)

  # Adjust for missing trailing newline edge case
  adjusted_src_len = src_len
  if exists && cov_len.positive? && src_len == cov_len + 1 && missing_trailing_newline?(file_abs)
    adjusted_src_len -= 1
  end

  len_mismatch = (cov_len.positive? && adjusted_src_len != cov_len)
  newer &&= !len_mismatch  # Prioritize length mismatch over timestamp

  {
    exists: exists,
    file_mtime: file_mtime,
    coverage_timestamp: coverage_ts,
    cov_len: cov_len,
    src_len: src_len,
    newer: newer,
    len_mismatch: len_mismatch
  }
end
```

### Staleness Modes

The checker supports two modes (lib/simplecov_mcp/staleness_checker.rb:9):

- **`:off`** (default): Staleness is detected but only reported in responses, never raises errors
- **`:error`**: Staleness raises `CoverageDataStaleError` or `CoverageDataProjectStaleError`

This allows:
- Interactive tools to show warnings without crashing
- CI systems to fail builds on stale coverage
- AI agents to decide how to handle staleness based on their goals

### File-Level vs Project-Level Checks

**File-level** (`check_file!` and `stale_for_file?`, lib/simplecov_mcp/staleness_checker.rb:25,49):
- Checks a single file's staleness
- Returns `false` or staleness type character ('M', 'T', 'L')
- Used by single-file tools (summary, detailed, uncovered)

**Project-level** (`check_project!`, lib/simplecov_mcp/staleness_checker.rb:59):
- Checks all covered files plus optionally tracked files
- Detects:
  - Files newer than coverage timestamp
  - Files deleted since coverage was collected
  - Tracked files missing from coverage (newly added files)
- Raises `CoverageDataProjectStaleError` with lists of problematic files
- Used by `all_files_coverage_tool` and `coverage_table_tool`

### Tracked Globs Feature

The project-level check supports `tracked_globs` parameter to detect newly added files:

```ruby
# Detects if lib/**/*.rb files exist that have no coverage data
checker.check_project!(coverage_map)  # with tracked_globs: ['lib/**/*.rb']
```

This helps teams ensure new files are included in test runs.

## Consequences

### Positive

1. **Accurate detection**: Three types catch different staleness scenarios comprehensively
2. **Edge case handling**: Missing trailing newlines handled correctly
3. **User control**: Modes allow errors or warnings based on use case
4. **Detailed information**: Staleness errors include specific file lists and timestamps
5. **Project awareness**: Can detect newly added files that lack coverage

### Negative

1. **Complexity**: Three staleness types are harder to understand than a single timestamp check
2. **Performance**: Line counting and mtime checks for every file add overhead
3. **Maintenance burden**: Edge case logic (trailing newlines) requires careful testing
4. **Ambiguity**: When multiple staleness types apply, prioritization logic (length > timestamp) may surprise users

### Trade-offs

- **Versus timestamp-only**: More accurate but slower and more complex
- **Versus content hashing**: Fast enough for most projects, but can't detect "edit then revert" scenarios
- **Versus no checking**: Essential for reliable coverage reporting, worth the complexity

### Edge Cases Handled

1. **Missing trailing newline**: Files without `\n` at EOF have `line_count == coverage_length + 1`, checker adjusts for this
2. **Deleted files**: Appear as 'M' (missing) type staleness
3. **Empty files**: `cov_len.positive?` guard prevents false positives
4. **No coverage timestamp**: Defaults to 0, effectively disabling timestamp checks

## References

- Implementation: `lib/simplecov_mcp/staleness_checker.rb:8-168`
- File-level checking: `lib/simplecov_mcp/staleness_checker.rb:25-55`
- Project-level checking: `lib/simplecov_mcp/staleness_checker.rb:59-95`
- Staleness detail computation: `lib/simplecov_mcp/staleness_checker.rb:137-166`
- Error types: `lib/simplecov_mcp/errors.rb` (CoverageDataStaleError, CoverageDataProjectStaleError)
- Usage in tools: `lib/simplecov_mcp/tools/all_files_coverage_tool.rb`, `lib/simplecov_mcp/model.rb`
