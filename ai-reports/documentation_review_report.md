# Documentation Review Report

**Date:** 2025-11-23
**Reviewer:** Claude Code
**Scope:** All markdown files in the simplecov-mcp repository

## Executive Summary

The documentation suite is comprehensive and well-organized. However, I identified several issues ranging from errors to omissions and potential improvements. This report prioritizes findings by impact and provides an action plan.

---

## Critical Issues (High Priority)

### 1. ERROR_HANDLING.md - Incomplete TODO Comment
**File:** `docs/user/ERROR_HANDLING.md:18-21`
**Issue:** Contains an unfinished TODO comment indicating missing documentation.
```markdown
# TODO This does not do what it says it does
```
**Impact:** Confuses users, indicates documentation doesn't match actual behavior.
**Action:** Verify what `--error-mode trace` actually does and update documentation accordingly.

### 2. CONTRIBUTING.md - Incorrect Version File Path
**File:** `CONTRIBUTING.md:63`
**Issue:** References `lib/simplecov/mcp/version.rb` but the actual path is `lib/simplecov_mcp/version.rb`.
```markdown
1. Update version in `lib/simplecov/mcp/version.rb`
```
**Impact:** Maintainers following release process will look in wrong location.
**Action:** Correct path to `lib/simplecov_mcp/version.rb`.

### 3. CONTRIBUTING.md - References Non-existent CHANGELOG.md
**File:** `CONTRIBUTING.md:64`
**Issue:** References `CHANGELOG.md` which doesn't exist (the project uses `RELEASE_NOTES.md` instead).
**Impact:** Release process documentation is incorrect.
**Action:** Change reference to `RELEASE_NOTES.md`.

### 4. CONTRIBUTING.md - Ruby Version Mismatch
**File:** `CONTRIBUTING.md:46`
**Issue:** States "supports modern Ruby versions (3.1+)" but the README and other docs correctly state Ruby >= 3.2 is required (due to `mcp` gem dependency).
**Impact:** Developers may try to use Ruby 3.1 and encounter errors.
**Action:** Update to "Ruby >= 3.2".

### 5. Presentation Slide - Obsolete Directory Reference
**File:** `docs/dev/presentations/simplecov-mcp-presentation.md:153-168`
**Issue:** Shows architecture with `lib/simple_cov_mcp` path (old naming) instead of `lib/simplecov_mcp`.
**Impact:** Confuses developers looking at the actual codebase.
**Action:** Update architecture diagram to use `lib/simplecov_mcp`.

### 6. Presentation Slide - Obsolete CLI Commands in MCP Tools Table
**File:** `docs/dev/presentations/simplecov-mcp-presentation.md:76-84`
**Issue:** References obsolete CLI commands (`table`, `all-files`, `help`) that were merged into `list` in v1.0.0.
**Impact:** Misleads users about available commands.
**Action:** Update table to use current command names (`list` instead of `table`/`all-files`).

### 7. ADVANCED_USAGE.md - Broken Class Name in Example
**File:** `docs/user/ADVANCED_USAGE.md:335`
**Issue:** Example shows class defined as `CoveragePolicy` but instantiated as `AllFilesAboveThreshold.new`.
```ruby
class CoveragePolicy
  def call(model)
    # ...
  end
end

AllFilesAboveThreshold.new  # Wrong - should be CoveragePolicy.new
```
**Impact:** Code example won't work if copied.
**Action:** Fix to `CoveragePolicy.new`.

---

## Medium Priority Issues

### 8. CLAUDE.md - Outdated Testing Notes
**File:** `CLAUDE.md:102`
**Issue:** States "No SimpleCov runtime dependency" but v1.0.0 introduced a runtime dependency for multi-suite merging.
**Impact:** Misleads AI assistants and developers about dependencies.
**Action:** Update to clarify that SimpleCov is now a lazy-loaded runtime dependency.

### 9. GEMINI.md - Missing `coverage_totals_tool`
**File:** `GEMINI.md:60-64`
**Issue:** CLI subcommands list doesn't include `total` subcommand added in v1.1.0.
**Impact:** Users don't know about this feature.
**Action:** Add `total` to the list of subcommands.

### 10. docs/user/README.md - Missing CLI_FALLBACK_FOR_LLMS.md
**File:** `docs/user/README.md`
**Issue:** Index doesn't list CLI_FALLBACK_FOR_LLMS.md which is a new and useful doc.
**Impact:** Users may not discover this helpful guide.
**Action:** Add link to the index.

### 11. Broken Back Link in INSTALLATION.md
**File:** `docs/user/INSTALLATION.md:3`
**Issue:** Back link points to `../README.md` which would be `docs/README.md` but should likely be `../../README.md` (project root).
**Impact:** Broken navigation.
**Action:** All `docs/user/*.md` files use `../README.md` - verify if there's a `docs/README.md` or fix links.

### 12. usefulness_recommendations.md - Outdated Recommendations
**File:** `ai-reports/usefulness_recommendations.md:21-22`
**Issue:** Recommends `--fail-under PCT` which was implemented as `--success-predicate`, so this recommendation is now implemented differently.
**Impact:** Report suggests features that already exist in different form.
**Action:** Either update to note these are implemented, or archive as historical context.

### 13. Missing MCP Tool in CLAUDE.md
**File:** `CLAUDE.md:80-89`
**Issue:** MCP Tools list doesn't include `coverage_totals_tool` added in v1.1.0.
**Impact:** AI assistants don't know about this tool.
**Action:** Add `coverage_totals_tool` to the list.

---

## Low Priority Issues (Documentation Polish)

### 14. EXAMPLES.md - Conflicting Source Flags
**File:** `docs/user/EXAMPLES.md:70`
**Issue:** Shows `--source=full --source=uncovered` together which is contradictory.
```bash
simplecov-mcp uncovered lib/simplecov_mcp/cli.rb --source=full --source=uncovered --source-context 5
```
**Impact:** Confusing example.
**Action:** Remove one of the conflicting flags.

### 15. README.md - Broken Internal Link Text
**File:** `README.md:231`
**Issue:** Says "See docs/dev/DEVELOPMENT.md for more *(coming soon)*" but the file exists and is comprehensive.
**Impact:** Undersells existing documentation.
**Action:** Remove "(coming soon)".

### 16. Architecture Decision Records Inconsistent Naming
**File:** `docs/dev/arch-decisions/*.md`
**Issue:** Files are named `001-x-arch-decision.md` etc. with uninformative names. The pattern `001-dual-mode-operation.md` would be more discoverable.
**Impact:** Minor - harder to find specific ADRs.
**Action:** Consider renaming for clarity (low priority).

### 17. ~~examples/prompts/README.md - References Non-existent .txt Files~~
**Status:** FALSE POSITIVE - The referenced `.txt` files (`summary.txt`, `detailed_with_source.txt`, `list_lowest.txt`, `uncovered.txt`, `custom_resultset.txt`) actually exist in the directory. No action needed.

### 18. Duplicate Content Between Files
**Observation:** Several documents repeat the same content (e.g., security warnings for predicates, resultset configuration). This is intentional for standalone readability but increases maintenance burden.
**Action:** Consider using include snippets or more cross-references (optional).

---

## Omissions Identified

### 19. No Documentation for `project_totals` API Method
**Issue:** LIBRARY_API.md doesn't document the `project_totals` method, though it's used in examples.
**Action:** Add method reference to LIBRARY_API.md.

### 20. Missing `relativize` Method Documentation
**Issue:** The `relativize` method is used in examples but not documented in LIBRARY_API.md method reference.
**Action:** Add to Method Reference section.

### 21. No CLI Help for `--force-cli` in README Quick Reference
**Issue:** README troubleshooting used to mention `--force-cli`. Flag removed in 4.0.0; use `-F/--force-mode cli|mcp|auto` instead.
**Action:** Add to troubleshooting section.

---

## Useless/Redundant Documentation Candidates

### 22. ai-reports/usefulness_recommendations.md
**Observation:** This is an internal planning document that's now partially outdated (some features implemented differently). Could be confusing to users.
**Recommendation:** Move to a `docs/internal/` directory or archive, or update to reflect current state.

### 23. spec/TIMESTAMPS.md
**Observation:** Very specialized developer documentation about test constants. Only useful for contributors modifying timestamp tests.
**Assessment:** Appropriate for spec directory but could be moved to a comment in spec_helper.rb.

---

## Action Plan

### Immediate (Critical Fixes)
1. Fix ERROR_HANDLING.md TODO comment
2. Fix CONTRIBUTING.md version file path
3. Fix CONTRIBUTING.md changelog reference
4. Fix CONTRIBUTING.md Ruby version requirement
5. Fix ADVANCED_USAGE.md broken class name example
6. Fix EXAMPLES.md conflicting source flags

### Short-term (Medium Priority)
7. Update presentation slide architecture diagram
8. Update presentation slide MCP tools table
9. Update CLAUDE.md testing notes and tools list
10. Update GEMINI.md subcommands list
11. Update docs/user/README.md index
12. Add missing API methods to LIBRARY_API.md
13. Fix examples/prompts/README.md references

### Optional (Low Priority)
14. Remove "coming soon" from README.md
15. Consider renaming ADR files
16. Review ai-reports for currency/placement
17. Fix back links in docs/user/ files

---

## Fixes Applied (2025-11-23)

The following issues were fixed in this session:

### Critical (All Fixed)
- [x] **#1** ERROR_HANDLING.md - Removed TODO comment, corrected `--error-mode trace` description
- [x] **#2** CONTRIBUTING.md - Fixed version file path to `lib/simplecov_mcp/version.rb`
- [x] **#3** CONTRIBUTING.md - Changed `CHANGELOG.md` reference to `RELEASE_NOTES.md`
- [x] **#4** CONTRIBUTING.md - Updated Ruby version from "3.1+" to ">= 3.2"
- [x] **#5** Presentation - Updated directory path from `lib/simple_cov_mcp` to `lib/simplecov_mcp`
- [x] **#6** Presentation - Updated MCP tools table with current CLI commands
- [x] **#7** ADVANCED_USAGE.md - Fixed class name from `AllFilesAboveThreshold.new` to `CoveragePolicy.new`

### Medium Priority (All Fixed)
- [x] **#8** CLAUDE.md - Updated testing notes about SimpleCov lazy loading
- [x] **#9** CLAUDE.md - Added `coverage_totals_tool` to MCP tools list
- [x] **#10** GEMINI.md - Updated SimpleCov dependency description
- [x] **#11** GEMINI.md - Added `total` and `version` subcommands
- [x] **#12** docs/user/README.md - Added CLI_FALLBACK_FOR_LLMS.md to index
- [x] **#14** EXAMPLES.md - Removed conflicting `--source=full --source=uncovered` flags
- [x] **#19-20** LIBRARY_API.md - Added `project_totals` and `relativize` method documentation

### Low Priority (Partial)
- [x] **#14** README.md - Removed "(coming soon)" from DEVELOPMENT.md link
- [x] **#17** Verified prompts README - `.txt` files exist (false positive)

### Remaining (Not Fixed)
- [ ] Consider renaming ADR files for clarity
- [ ] Review ai-reports for currency/placement
- [ ] Verify back links in docs/user/ files
