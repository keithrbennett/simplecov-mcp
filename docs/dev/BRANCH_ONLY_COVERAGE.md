# Branch-Only Coverage Handling

[Back to main README](../README.md)

> **Note:** This document is for **developers working on cov-loupe**, not for users of the gem.
> If you're a user, you don't need to read this - branch-only coverage "just works" automatically.
> This explains the internal implementation for contributors who need to maintain or modify the code.

## The Problem This Solves for cov-loupe

SimpleCov can be configured to track different types of coverage:
- **Line coverage**: Which lines of code were executed
- **Branch coverage**: Which paths through if/else, case/when, etc. were taken
- **Both**: Track both lines and branches together

When users configure SimpleCov to track **only branch coverage** (without line coverage),
the `.resultset.json` file has a different structure: the `lines` array is `null`,
and only the `branches` data exists.

**This breaks cov-loupe** because our entire tool is designed around the `lines` array:
- Our MCP tools (`coverage_summary_tool`, `uncovered_lines_tool`, etc.) expect line data
- Our CLI commands expect line data
- Our `CoverageModel` API expects line data

Rather than failing with "no coverage data found" errors, cov-loupe **automatically
converts branch coverage into line coverage** so all our tools continue to work seamlessly
for projects using branch-only configuration.

## What Branch-Only Coverage Data Looks Like

When SimpleCov writes branch-only coverage, the `.resultset.json` file looks different
from the normal line coverage format. Here's an example:

```json
{
  "lib/example.rb": {
    "lines": null,
    "branches": {
      "[:if, 0, 12, 4, 20, 29]": {
        "[:then, 1, 13, 6, 13, 18]": 4,
        "[:else, 2, 15, 6, 15, 16]": 0
      }
    }
  }
}
```

### Understanding the Branch Data Structure

The `branches` hash uses a nested structure:

**Outer key** (e.g., `"[:if, 0, 12, 4, 20, 29]"`):
- This is either a Ruby array or its stringified version
- It describes where the branch decision happens (the `if` statement itself)
- Format: `[type, id, start_line, start_col, end_line, end_col]`
  - Position 0: Branch type (`:if`, `:case`, `:unless`, etc.)
  - Position 1: SimpleCov's internal ID for this branch
  - **Position 2: The line number** ← This is what we need for line coverage!
  - Position 3: Starting column
  - Position 4: Ending line
  - Position 5: Ending column

**Nested hash** (the value of the outer key):
- Contains each possible path through the branch
- Keys are branch targets like `"[:then, 1, 13, 6, 13, 18]"` or `"[:else, 2, 15, 6, 15, 16]"`
- Each target has the same array format as the outer key
- Values are integers showing how many times that path was executed
  - `4` means the `then` branch ran 4 times
  - `0` means the `else` branch never ran

**Why this matters for our conversion:**
- We extract the line number (position 2) from each branch target
- We sum up all the execution counts for branches on the same line
- This gives us enough information to build a line coverage array

## How cov-loupe Converts Branch Coverage to Line Coverage

Since all of cov-loupe's tools expect a `lines` array, we need to build one from
the `branches` data. This happens automatically in the `CoverageLineResolver` whenever
it detects that `lines` is `null` but `branches` exists.

### The Conversion Algorithm

Here's how we transform branch data into line data:

**Step 1: Parse the branch keys**
- Branch keys can be either raw Ruby arrays or stringified (e.g., `"[:if, 0, 12, 4, 20, 29]"`)
- We handle both formats by parsing the string format when needed

**Step 2: Extract line numbers**
- From each branch target tuple, we pull out position 2 (the line number)
- Invalid or malformed tuples are silently skipped

**Step 3: Sum hits per line**
- Multiple branches can exist on the same line (e.g., nested ifs, ternaries)
- We add up all the execution counts for branches on the same line
- Example: if line 15 has a `then` branch hit 4 times and an `else` branch hit 2 times,
  that line gets a total of 6 hits

**Step 4: Build the line array**
- We create an array with length equal to the highest line number found
- Each array position represents a line: `array[0]` = line 1, `array[1]` = line 2, etc.
- Positions get the summed hit count for that line, or `nil` if no branches appeared there

**Result:** We now have a `lines` array that looks exactly like SimpleCov's normal
format, so all our tools (`summary`, `uncovered`, staleness checks, etc.) work without
knowing branch coverage was involved.

## Where to Find the Code

If you need to modify or debug the branch coverage conversion, here's where everything lives:

### Implementation
**`lib/cov_loupe/resolvers/coverage_line_resolver.rb`**
- `lines_from_entry` – Detects when to synthesize line data
- `synthesize_lines_from_branches` – The main conversion logic
- `extract_line_number` – Parses line numbers from branch tuples

Inline comments near `synthesize_lines_from_branches` reference this document for maintainers.

### Tests
**`spec/resolvers/coverage_line_resolver_spec.rb`**
- Contains tests specifically for the resolver and branch synthesis

**`spec/cov_loupe_model_spec.rb`**
- Integration tests showing how the model uses synthesized line data

### Test Data
**`spec/fixtures/branch_only_project/coverage/.resultset.json`**
- Example of real branch-only coverage data used in tests
- Useful reference when debugging issues or adding new test cases

## Important Implementation Notes

### Why the resolver returns `nil` for missing files

When `CoverageLineResolver.lookup_lines` can't find a file, it returns `nil` rather
than immediately raising an error. This is deliberate:

- The lookup tries multiple strategies: exact path match, relative path, path without
  working directory prefix
- Each strategy calls `lines_from_entry` which may return `nil`
- Only after **all strategies fail** does the resolver raise a `FileError`
- This ensures we try every possible way to find the file before giving up

If you change `lines_from_entry` to raise an error immediately, the multi-strategy
lookup will break!

### Future-proofing for SimpleCov changes

SimpleCov's branch tuple format could change in future versions. If that happens:

1. Update `extract_line_number` to recognize the new tuple format
2. Add test fixtures with the new format
3. Update this documentation with the new structure
4. Keep backward compatibility with the old format if possible

This way, cov-loupe continues working even when SimpleCov evolves.
