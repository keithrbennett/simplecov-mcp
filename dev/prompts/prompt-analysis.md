# Prompt Audit: Directory Structure & Content Review

## Directory Structure Overview

The three prompt roots serve distinct audiences:

| Root | Audience | Purpose |
|---|---|---|
| `dev/prompts/` | Maintainers of cov-loupe | Improving/reviewing the codebase itself |
| `docs/user/prompts/` | End users of cov-loupe | System/persona prompts for configuring an AI assistant |
| `examples/prompts/` | End users of cov-loupe | Concrete example queries to paste into a chat |

The separation between `dev/prompts/` and `examples/prompts/` is correct and should be preserved:
`dev/prompts` is entirely about developing cov-loupe, while `examples/` is for users of it.

However, `examples/prompts/` and `docs/user/prompts/` both target end users, and their READMEs
cross-link awkwardly. They could be merged under `docs/user/prompts/` with an `examples/`
subfolder, or left split if the intent is "reference architecture" vs "copy-paste queries."

---

## Specific Issues

### 1. Misplaced file — delete or ignore it

`dev/prompts/improve/cov_loupe.log` is a runtime log file sitting inside the prompts directory.
It has no business being there and should be deleted and added to `.gitignore`.

---

### 2. Archive — safe to delete

The three files in `dev/prompts/archive/` are explicitly labelled as superseded by
`identify-action-items.md`. Keeping them adds noise; the README already documents what they were.
Unless there's a specific reason to preserve the git-history-accessible copies, the whole
`archive/` folder can go.

---

### 3. `docs/user/prompts/use-cli-not-mcp-prompt.md` — stale and fragile

The help block is pinned to `v4.0.0.pre` and contains a hardcoded local path
(`/home/kbennett/code/cov-loupe/**/*.md`). Both will silently become wrong. Better approach:
remove the pasted help block entirely and replace with an instruction to run `cov-loupe --help`.
The prompt's actual value is the framing/context, not the reproduced help text.

---

### 4. `rails-coverage-analysis-prompt.md` vs `non-web-coverage-analysis-prompt.md` — near-duplicate structure

Both files follow an identical 10-section skeleton (Executive Summary, Coverage by Component,
Well-Tested Areas, Poorly-Tested Areas, Priority Issues Table, Specific Testing Analysis,
Anti-Patterns, Actionable Roadmap, Metrics Dashboard, Risk Assessment). The only real differences
are component names in sections 2 and 6. Maintaining two near-identical 150+ line files is a
synchronization burden. Options:

- **Preferred:** A single `coverage-analysis-prompt.md` that includes a short preamble telling
  the AI "adapt the component categories to the framework in use," with Rails-specific categories
  as an inline example.
- **Alternative:** Keep both but extract the shared skeleton into a short `_base.md` with a note
  at the top of each file.

---

### 5. `dev/prompts/improve/review-test-coverage.md` — misclassified, excessively complex

This file:
- Produces a report but makes **no changes** — it's a review, not an improvement
- Should live in `dev/prompts/review/`, not `improve/`
- Is 150+ lines (the longest by far), requiring MCP availability, specifying output filename,
  output format structure, emoji severity indicators, a 5-section report structure, and an
  appendix. The level of prescription is high enough that an AI following it literally may spend
  more time satisfying formatting requirements than finding real gaps.

Suggestion: Move to `review/`, rename to `review-test-coverage.md`, and trim the output format
prescription to ~10 lines of high-level guidance. The comprehensive-codebase-review already covers
test coverage as one of its 10 dimensions — if this prompt is truly standalone, it needs a clear
note at the top explaining when to use it instead.

---

### 6. `dev/prompts/improve/update-documentation.md` — too sparse

Four bullet points vs. 50–150 lines for every other prompt in `improve/`. It tells you *what* to
look at (file globs) but barely *how* to evaluate it. Compared to the detailed guidance in
`simplify-code-logic.md` and `refactor-test-suite.md`, this feels unfinished. Needs at minimum:

- Criteria for "accurate/clear/complete"
- What to check for broken links
- Instructions on running documentation examples (or a reference to
  `validate/test-documentation-examples.md`)
- A note about the MkDocs include-markdown pattern (already documented in
  `guidelines/ai-code-evaluator-guidelines.md` — link to it rather than repeating)

---

### 7. `dev/prompts/validate/create-screencast-outline.md` — category mismatch

"Validate" implies checking correctness of something that exists. Creating a screencast outline is
a *planning/produce* task. Consider renaming the `validate/` directory to `produce/` or moving
this file to `docs/dev/` since it's closer to marketing/release planning than code validation.

---

### 8. `examples/prompts/*.txt` — placeholder paths with no warning

All five files use `lib/foo.rb` or `src/app.rb` as placeholder paths. There's no inline note that
these must be replaced, and users who copy-paste literally will get confusing errors. Either:

- Add a one-line comment at the top: `# Replace lib/foo.rb with your actual file path`
- Rename with a `.md` extension and wrap in a template note

Also, `.txt` is inconsistent with the rest of the repo (all `.md`). Converting to `.md` lets the
examples be rendered and linked in the documentation site.

---

### 9. `dev/prompts/review/comprehensive-codebase-review.md` — trailing stub section

The last section heading is `### Summarize suggested changes` with no body. Appears unfinished —
either flesh it out or remove it.

---

### 10. `dev/prompts/improve/review-test-coverage.md` — overlaps with `comprehensive-codebase-review.md`

Both ask for a coverage breakdown table, per-file analysis, and scoring. If someone runs
`comprehensive-codebase-review.md` they already get the test coverage dimension. The standalone
`review-test-coverage.md` is only worth keeping if it's faster/cheaper for a coverage-only check,
which should be stated explicitly at the top.

---

## Summary Table

| Issue | File(s) | Type | Priority |
|---|---|---|---|
| Log file in prompts dir | `improve/cov_loupe.log` | Wrong file | High |
| Stale version + hardcoded local path | `docs/user/prompts/use-cli-not-mcp-prompt.md` | Stale content | High |
| Near-duplicate 10-section structure | `rails-coverage-analysis-prompt.md` vs `non-web-coverage-analysis-prompt.md` | Duplication | Medium |
| Misclassified (review, not improve) | `improve/review-test-coverage.md` | Wrong category | Medium |
| Redundant archive | `archive/` (3 files) | Noise | Medium |
| Underdeveloped prompt | `improve/update-documentation.md` | Too sparse | Medium |
| Wrong category (produce, not validate) | `validate/create-screencast-outline.md` | Wrong category | Low |
| Unfinished section | `review/comprehensive-codebase-review.md` | Incomplete | Low |
| Placeholder paths without warning | `examples/prompts/*.txt` | UX / clarity | Low |
| `.txt` vs `.md` inconsistency | `examples/prompts/*.txt` | Convention | Low |
| Coverage review overlaps with comprehensive review | `improve/review-test-coverage.md` | Duplication | Low |
