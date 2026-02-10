# Test Coverage Review and Improvement Analysis

Please provide a comprehensive report on the test coverage of this codebase, with special attention to actionable improvements.

## Objectives

Analyze the current state of test coverage and produce a detailed report that will guide prioritization of testing efforts. The report should help answer:
- Which components are well-tested vs. under-tested?
- Where are the highest-value opportunities to improve coverage?
- What's the effort-to-benefit ratio for improving each area?

## Prerequisites

**CRITICAL**: This analysis requires the `cov-loupe` MCP server to be available and functional.

- **Verify MCP server availability** by calling `help_tool` or `version_tool` at the start
- **If the MCP server is not available or tools fail**, abort immediately and inform the user that the cov-loupe MCP server must be configured and running
- **Do NOT** attempt to parse `.resultset.json` files directly or estimate coverage without using the MCP tools
- All coverage data must come from the cov-loupe MCP tools to ensure accuracy and consistency

## Required Analysis

### 1. Coverage Assessment by Logical Component

For each major logical component of the codebase, provide:

- **Component Name & Purpose**: Brief description of what it does
- **Current Coverage**: Percentage and absolute lines (covered/total)
- **Criticality Rating**: Low/Medium/High/Critical
  - Consider: frequency of use, impact of failures, complexity, user-facing vs internal
- **Coverage Quality Assessment**: Beyond percentages, assess:
  - Are edge cases tested?
  - Are error paths tested?
  - Are integration points tested?
  - Are there obvious gaps in test scenarios?

### 2. Prioritized Improvement Opportunities

For each under-tested component, provide:

- **Current State**: What's covered, what's not
- **Risk Assessment**: What could go wrong with insufficient coverage?
- **Recommended Tests**: Specific test scenarios that should be added
- **Effort Estimate**: Small/Medium/Large
  - Small: 1-2 hours, straightforward test cases
  - Medium: Half-day effort, may require fixtures or mocking
  - Large: 1+ days, complex setup, integration testing, or significant refactoring needed
- **Priority**: High/Medium/Low based on criticality × risk × effort

### 3. Coverage Metrics Summary

Provide aggregate statistics:
- Overall coverage percentage
- Coverage by directory/module
- Number of files with <50%, 50-80%, >80% coverage
- Trend analysis if historical data available

### 4. Testing Infrastructure Assessment

Evaluate the testing setup itself:
- Are test fixtures adequate?
- Are test utilities/helpers sufficient?
- Are there patterns that make testing difficult?
- Would refactoring improve testability?

### 5. Recommendations

Provide actionable next steps:
1. **Quick Wins**: High-value, low-effort improvements (do first)
2. **Strategic Priorities**: High-value, high-effort improvements (plan for these)
3. **Long-term Improvements**: Infrastructure or architectural changes to improve testability
4. **Coverage Targets**: Suggested coverage goals by component type

## Analysis Guidelines

- Use the `cov-loupe` MCP tools to gather coverage data (prefer MCP tools over parsing `.resultset.json` directly)
- Read actual source code to understand component purpose and complexity
- Consider both line coverage and branch coverage implications
- Be specific about what tests are missing (don't just say "add more tests")
- Consider maintainability: focus on meaningful tests, not just coverage percentage
- Acknowledge uncertainty when you lack context about business requirements

## Output Format

Structure your report with clear sections, tables where helpful, and specific file paths with line numbers. Use severity indicators (🔴 Critical, 🟡 Medium, 🟢 Low) for quick scanning.

Example component analysis:

```
### Component: CLI Command Parser (lib/cov_loupe/cli.rb)

**Coverage**: 87% (234/269 lines)
**Criticality**: 🔴 Critical (main user interface)
**Quality**: Good coverage of happy paths, gaps in error handling

**Gaps Identified**:
- Line 145-158: Flag validation error paths not tested
- Line 203-215: Help text formatting edge cases not covered
- No tests for conflicting flag combinations

**Recommended Tests**:
1. Invalid flag combinations (--mode=invalid, conflicting options)
2. Help text rendering with various terminal widths
3. Error message clarity for common user mistakes

**Effort**: Medium (4-6 hours, requires mock terminal output testing)
**Priority**: High (user-facing, error paths are important for UX)
```

## Deliverable

A markdown report that can be saved as `test-coverage-analysis-report.md` with the following structure:

### Required Structure

1. **Executive Summary** (at the very beginning, before any other content)
   - 2-3 paragraph overview of overall coverage health
   - Key findings: most critical gaps, biggest risks, easiest wins
   - High-level recommendation on where to focus effort first

2. **Detailed Component Analysis**
   - One section per major component following the example format
   - Include coverage percentages, criticality ratings, and specific gaps

3. **Prioritized Action Items**
   - Organized by priority (High/Medium/Low)
   - With effort estimates and expected impact

4. **Summary Table** (at the end, before appendix)
   - Tabular view of all components for quick reference
   - Columns: Component | Coverage % | Criticality | Priority | Effort | Status
   - Sorted by Priority (High first)

5. **Appendix**
   - Raw coverage data from MCP tools
   - Any additional technical details or assumptions
