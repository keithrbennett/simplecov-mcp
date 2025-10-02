# Code Examples Audit Report

**Date:** October 2, 2025
**Auditor:** Claude (Anthropic AI Assistant)
**Scope:** All code examples in documentation

## Executive Summary

This audit examines all code examples across the documentation to determine which can be executed against the simplecov-mcp codebase itself.

**Status:**
- ✅ **README.md** - All uncommented examples are runnable
- ⚠️ **docs/CLI_USAGE.md** - 50+ examples with generic file paths
- ⚠️ **docs/MCP_INTEGRATION.md** - 30+ examples with generic file paths
- ⚠️ **docs/TROUBLESHOOTING.md** - 20+ examples with generic file paths
- ✅ **docs/INSTALLATION.md** - Installation commands only (no file-specific examples)

## Detailed Findings

### ✅ README.md - COMPLIANT

All uncommented code examples use actual files from the simplecov-mcp codebase:

**CLI Examples:**
- `lib/simple_cov_mcp/model.rb` ✓
- `lib/simple_cov_mcp/cli.rb` ✓
- `lib/simple_cov_mcp/util.rb` ✓
- `lib/simple_cov_mcp/tools/**/*.rb` ✓

**Library Examples:**
- All file paths use actual codebase files ✓
- One customization example is properly commented out ✓

**MCP Prompts:**
- All prompts reference actual files ✓

**Status:** ✅ Ready for 1.0 release

---

### ⚠️ docs/CLI_USAGE.md - NEEDS UPDATE

**Generic file paths found (line numbers):**

| Line | Example | Issue |
|------|---------|-------|
| 22 | `simplecov-mcp summary lib/my_file.rb` | Generic filename |
| 25 | `simplecov-mcp uncovered lib/my_file.rb` | Generic filename |
| 28 | `simplecov-mcp detailed lib/my_file.rb` | Generic filename |
| 31 | `simplecov-mcp raw lib/my_file.rb` | Generic filename |
| 75-77 | Multiple `lib/my_file.rb` examples | Generic filename |
| 109-111 | Multiple `lib/my_file.rb` examples | Generic filename |
| 158-160 | Multiple `lib/my_file.rb` examples | Generic filename |
| 203-204 | Multiple `lib/my_file.rb` examples | Generic filename |
| 275 | `simplecov-mcp summary lib/file.rb --json` | Generic filename |
| 306-311 | Multiple `lib/file.rb` examples | Generic filename |

**Additional generic examples:**
- Lines 427-435: Examples using `lib/foo.rb`, `lib/models/user.rb`
- Lines 448-465: Examples using `lib/file.rb`, `lib/models/user.rb`
- Lines 478-487: Examples using `lib/file.rb`
- Lines 493-510: Examples using `lib/file.rb`, `lib/my_file.rb`
- Lines 552-567: Examples using `lib/file.rb`, `lib/my_file.rb`

**Recommendation:** Replace with actual files:
- `lib/my_file.rb` → `lib/simple_cov_mcp/model.rb`
- `lib/file.rb` → `lib/simple_cov_mcp/cli.rb`
- `lib/models/user.rb` → `lib/simple_cov_mcp/tools/coverage_summary_tool.rb`
- `lib/foo.rb` → `lib/simple_cov_mcp/util.rb`

---

### ⚠️ docs/MCP_INTEGRATION.md - NEEDS UPDATE

**Generic file paths found:**

| Line | Example | Issue |
|------|---------|-------|
| 92 | `simplecov-mcp summary lib/file.rb` | Generic filename |
| 233 | `"path": "lib/my_file.rb"` | Generic in JSON example |
| 242 | `"file": "lib/my_file.rb"` | Generic in JSON response |
| 252-253 | Prompts with `lib/models/user.rb`, `app/services/authentication.rb` | Generic paths |
| 262 | `"path": "lib/my_file.rb"` | Generic in JSON |
| 269 | `"file": "lib/my_file.rb"` | Generic in JSON |
| 280-281 | Prompts with `lib/models/user.rb`, `app/controllers/api_controller.rb` | Generic paths |
| 290-313 | Multiple `lib/my_file.rb` examples | Generic in tool descriptions |
| 322-335 | Multiple `lib/my_file.rb` examples | Generic in tool descriptions |
| 346 | `["lib/**/*.rb", "app/**/*.rb"]` | Generic glob patterns |
| 355-362 | `lib/foo.rb`, `lib/bar.rb` | Generic filenames |
| 398 | Table with `lib/foo.rb`, `lib/bar.rb` | Generic in output example |

**Example prompts (lines 407-430):**
- "coverage for `lib/models/user.rb`"
- "coverage gaps in `app/models/`"
- "uncovered lines in `lib/authentication.rb`"

**Recommendation:**
- Use actual files: `lib/simple_cov_mcp/model.rb`, `lib/simple_cov_mcp/cli.rb`
- Update JSON examples to show real paths
- Update prompts to reference actual directories like `lib/simple_cov_mcp/tools/`

---

### ⚠️ docs/TROUBLESHOOTING.md - NEEDS UPDATE

**Generic file paths found:**

| Line | Example | Issue |
|------|---------|-------|
| 237 | `simplecov-mcp summary lib/my_file.rb` | Generic filename |
| 240 | `simplecov-mcp summary /full/path/to/lib/my_file.rb` | Generic path |
| 312 | `simplecov-mcp --json summary lib/file.rb` | Generic filename |
| 315 | `simplecov-mcp summary lib/file.rb --json` | Generic filename |
| 355 | `simplecov-mcp uncovered lib/file.rb --source --color` | Generic filename |
| 360 | `simplecov-mcp uncovered lib/file.rb --source --no-color > log.txt` | Generic filename |
| 367 | `simplecov-mcp uncovered lib/file.rb --source` | Generic filename |
| 370 | `simplecov-mcp uncovered lib/file.rb --source \| less` | Generic filename |
| 458 | `"path": "lib/file.rb"` | Generic in JSON |
| 468 | `["lib/**/*.rb"]` | Could be more specific |
| 537 | `simplecov-mcp summary lib/file.rb` | Generic filename |
| 546 | `simplecov-mcp list --tracked-globs "lib/**/*.rb"` | Generic glob |

**Additional examples:**
- Lines 584-599: Debug examples with generic paths
- Lines 607-617: CI/CD examples (could use real files)

**Recommendation:**
- Replace `lib/file.rb` with `lib/simple_cov_mcp/model.rb`
- Replace `lib/my_file.rb` with `lib/simple_cov_mcp/cli.rb`
- Update tracked-globs to `lib/simple_cov_mcp/tools/**/*.rb`

---

### ✅ docs/INSTALLATION.md - COMPLIANT

**Status:** All examples are installation commands or version manager setup. No file-specific examples that need updating.

**Examples are:**
- Installation commands (`gem install`, `bundle install`)
- Version checks (`ruby -v`, `which simplecov-mcp`)
- PATH configuration
- Test commands (`simplecov-mcp version`)

All are runnable in the context of the gem installation.

---

## Summary Statistics

| File | Total Code Examples | Runnable | Commented | Generic (needs fix) |
|------|---------------------|----------|-----------|---------------------|
| README.md | ~25 | 24 | 1 | 0 |
| docs/INSTALLATION.md | ~30 | 30 | 0 | 0 |
| docs/CLI_USAGE.md | ~80 | ~20 | 0 | ~60 |
| docs/MCP_INTEGRATION.md | ~50 | ~15 | 0 | ~35 |
| docs/TROUBLESHOOTING.md | ~40 | ~15 | 0 | ~25 |
| **TOTAL** | **~225** | **~104** | **1** | **~120** |

**Current Status:** ~46% of code examples are runnable with actual codebase files

**Target:** 100% of uncommented examples runnable (or appropriately commented if illustrative)

---

## Recommended Action Plan

### Phase 1: High Priority (CLI_USAGE.md)

This is the main CLI reference document. Users will copy-paste these examples.

**Files to update:**
1. `docs/CLI_USAGE.md`

**Search & Replace:**
- `lib/my_file.rb` → `lib/simple_cov_mcp/model.rb`
- `lib/file.rb` → `lib/simple_cov_mcp/cli.rb`
- `lib/models/user.rb` → `lib/simple_cov_mcp/tools/coverage_summary_tool.rb`
- `lib/foo.rb` → `lib/simple_cov_mcp/util.rb`
- `lib/bar.rb` → `lib/simple_cov_mcp/errors.rb`
- `lib/calculator.rb` → `lib/simple_cov_mcp/staleness_checker.rb`

**Estimated time:** 15-20 minutes

### Phase 2: Medium Priority (MCP_INTEGRATION.md)

Users will use these as templates for AI prompts.

**Files to update:**
1. `docs/MCP_INTEGRATION.md`

**Updates needed:**
- Tool input/output examples (lines 233-399)
- Example prompts (lines 407-430)
- JSON-RPC examples (throughout)

**Estimated time:** 15-20 minutes

### Phase 3: Lower Priority (TROUBLESHOOTING.md)

Troubleshooting examples are often illustrative. Consider:
- Update to real files where it makes sense
- Comment out purely illustrative examples
- Mark some as "example placeholder" if needed

**Files to update:**
1. `docs/TROUBLESHOOTING.md`

**Estimated time:** 10-15 minutes

---

## Post-Update Validation

After updates, validate with:

```sh
# Extract all uncommented file paths from docs
grep -h "simplecov-mcp.*lib/" docs/*.md README.md | \
  grep -v "^#" | \
  grep -o "lib/[a-z_/]*\.rb" | \
  sort -u > /tmp/doc_files.txt

# Check all exist
while read file; do
  [ -f "$file" ] && echo "✓ $file" || echo "✗ $file MISSING"
done < /tmp/doc_files.txt
```

---

## Long-term Maintenance

### Documentation Guidelines

Add to `docs/DEVELOPMENT.md`:

**Code Example Policy:**
1. All uncommented code examples MUST use actual files from the simplecov-mcp codebase
2. If an example needs to be illustrative only, comment it out with explanation
3. Before releasing, run the validation script above
4. Prefer these real files in examples:
   - `lib/simple_cov_mcp/model.rb` (high coverage, good example)
   - `lib/simple_cov_mcp/cli.rb` (has uncovered lines, good for testing)
   - `lib/simple_cov_mcp/util.rb` (good for detailed examples)
   - `lib/simple_cov_mcp/tools/*.rb` (good for directory filtering)

### CI/CD Check (Future)

Consider adding a CI check:

```yaml
# .github/workflows/docs.yml
- name: Validate documentation examples
  run: |
    ./scripts/validate_doc_examples.sh
```

---

## Benefits of Runnable Examples

1. **Trust** - Users can verify examples work
2. **Testing** - Examples are tested implicitly when users try them
3. **Maintenance** - If code changes break examples, users report it
4. **Learning** - Users explore real code, not abstract examples
5. **Dogfooding** - We use our own tool to document itself

---

## Next Steps

1. ✅ README.md is already compliant
2. ⬜ Update `docs/CLI_USAGE.md` (highest priority)
3. ⬜ Update `docs/MCP_INTEGRATION.md`
4. ⬜ Update `docs/TROUBLESHOOTING.md`
5. ⬜ Add validation script
6. ⬜ Add to documentation guidelines
7. ⬜ Run full validation before 1.0 release

**Estimated total time to complete:** 40-60 minutes
