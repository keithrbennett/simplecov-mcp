# CovLoupe Screencast Outline

**Duration:** 3-4 minutes
**Target Audience:** Ruby developers using SimpleCov who work with AI coding assistants

---

## Hook (15-20 seconds)

**Visual:** Split screen showing raw `.resultset.json` (thousands of lines) vs. a simple AI chat

**Script:**
> "SimpleCov generates great coverage data, but have you ever tried asking an AI to analyze a `.resultset.json` file? It's massive, cryptic, and overwhelming. What if your AI assistant could just *query* your coverage data like it queries your code?"

---

## Section 1: The Problem & Solution (30 seconds)

### The Problem with Raw `.resultset.json`
**Visual:** Show the actual structure of a resultset file
- Absolute paths embedded throughout
- Raw line arrays (nulls, zeros, numbers)
- No summaries, no percentages, no staleness info
- Context-free: AI must parse, compute, and reason from scratch every time

### The Solution: cov-loupe
**Visual:** Quick terminal demo of `cov-loupe` command
```bash
cov-loupe
```

**Key points:**
- Structured, queryable coverage data
- Pre-computed percentages and summaries
- Built-in staleness detection
- Three interfaces: CLI, MCP server, Library API

---

## Section 2: AI-Powered Coverage Analysis (60-90 seconds)

### Demo 1: Comprehensive Coverage Report
**Visual:** AI chat window with Claude Code / Claude Desktop

**Prompt:**
```
Using cov-loupe, analyze the test coverage and generate a prioritized
report of coverage gaps. For each gap, explain:
1. What the code does
2. Why it matters (risk level)
3. What tests would improve it

Focus on the lib/payments/ directory.
```

**Why this is powerful:**
- AI doesn't need to parse raw JSON
- Gets structured data (file, percentage, uncovered lines)
- Can cross-reference with actual source code
- Produces actionable insights, not just numbers

### Demo 2: Intelligent Test Generation
**Visual:** AI generating actual RSpec tests

**Prompt:**
```
Using cov-loupe, find the uncovered lines in lib/api/client.rb and write
meaningful RSpec tests for them. Don't just aim for coverage - write
tests that actually validate behavior.
```

**Key insight:** The AI can:
1. Query which lines are uncovered
2. Read the source to understand context
3. Generate tests that make semantic sense

### Demo 3: Coverage Analysis by Application Layer
**Prompt:**
```
Using cov-loupe, generate a table showing average coverage by directory:
- app/models/
- app/controllers/
- lib/services/
- lib/jobs/

Sort by coverage ascending and flag any below 80%.
```

**Why cov-loupe makes this easy:**
- `--tracked-globs` filters to specific patterns
- `totals` command aggregates stats
- AI can reason across multiple layers

---

## Section 3: Killer Features Demo (45-60 seconds)

### Feature 1: Staleness Detection
**Visual:** Terminal showing stale coverage warning

```bash
cov-loupe --raise-on-stale true list
```

**Script:**
> "Ever ship a PR thinking coverage was fine, only to realize the tests hadn't run on your latest changes? Cov-loupe detects when files are newer than the coverage data."

### Feature 2: Policy Validation with Custom Predicates
**Visual:** Show a coverage policy file

```ruby
# coverage_policy.rb
->(model) do
  critical = model.list(tracked_globs: ['lib/payments/**/*.rb'])['files']
  standard = model.list(tracked_globs: ['lib/**/*.rb'])['files']

  critical.all? { |f| f['percentage'] >= 95 } &&
    standard.all? { |f| f['percentage'] >= 80 }
end
```

```bash
cov-loupe validate coverage_policy.rb
```

**Script:**
> "Different code needs different coverage standards. Payment processing? 95% minimum. Everything else? 80%. One command, enforced in CI."

### Feature 3: Source Code Annotations
**Visual:** Terminal showing annotated source

```bash
cov-loupe -s uncovered -c 3 uncovered lib/payments/refund_service.rb
```

**Script:**
> "See exactly which lines aren't covered, with surrounding context. Perfect for feeding into an AI to understand what's being missed."

---

## Section 4: The "Wow" Moment - Deep AI Reasoning (45 seconds)

### The Big Prompt
**Visual:** Full-screen AI chat

**Prompt:**
```
Using cov-loupe, perform a comprehensive test coverage audit:

1. Get the coverage table and identify files below 80%
2. For each low-coverage file, get the uncovered lines
3. Read those files to understand what the uncovered code does
4. Generate a prioritized action plan with:
   - Risk assessment (what could break if untested)
   - Complexity estimate (how hard to test)
   - Recommended test approach

Output as a markdown report suitable for a sprint planning meeting.
```

**Why this demonstrates value:**
- AI orchestrates multiple cov-loupe queries
- Cross-references coverage data with source code
- Produces business-ready output
- This would take hours manually; AI does it in seconds

---

## Section 5: Quick Setup (20 seconds)

**Visual:** Terminal

```bash
# Install
gem install cov-loupe

# CLI usage (works immediately after running SimpleCov)
cov-loupe

# Add MCP server for AI assistants
claude mcp add cov-loupe cov-loupe -- -m mcp
```

**Script:**
> "Three commands to go from SimpleCov data to AI-queryable coverage insights."

---

## Closing (15 seconds)

**Visual:** Side-by-side comparison:
- Left: Asking AI "analyze my .resultset.json" (confused response)
- Right: Asking AI "Using cov-loupe, find my coverage gaps" (structured, actionable response)

**Script:**
> "Stop making AI work with raw data. Give it the right tools, and it becomes your coverage co-pilot. Try cov-loupe today."

**Call to action:**
- GitHub: github.com/keithrbennett/cov-loupe
- `gem install cov-loupe`

---

## Why cov-loupe > Raw .resultset.json Analysis

| Challenge with Raw JSON | How cov-loupe Solves It |
|------------------------|-------------------------|
| 1000s of lines to parse | Pre-computed summaries |
| Raw line arrays [null, 0, 1, null...] | Percentage, covered/total counts |
| Absolute paths everywhere | Flexible path resolution |
| No staleness info | Built-in freshness detection |
| AI must recompute every time | Consistent, structured responses |
| No filtering capability | `--tracked-globs` for focus |
| No policy enforcement | `validate` command with predicates |
| Can't see context | `--source` shows annotated code |

---

## Backup Prompts (if time permits)

### Risk-Focused Analysis
```
Using cov-loupe, identify the highest-risk untested code by looking at:
1. Files with 0% coverage
2. Controllers and models with < 50% coverage
3. Any payment or authentication related files

For each, explain the potential business impact of bugs in that code.
```

### PR Review Integration
```
Using cov-loupe, check the coverage of these changed files:
- lib/orders/processor.rb
- lib/payments/validator.rb

For any file below 80%, show the specific uncovered lines and suggest
what edge cases might be missing from the test suite.
```

### Coverage Trend Analysis
```
Using cov-loupe, get the current totals and compare against this baseline:
- Total coverage: 78%
- Models: 85%
- Controllers: 72%

Identify which areas improved and which regressed.
```
