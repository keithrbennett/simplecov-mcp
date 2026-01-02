# Architectural Review & Action Plan

### Preconditions

Before you begin the report:

1. Always open the report by citing the most recent git commit at the time you begin writing.
1. Limit the review strictly to git-tracked files.

----

- You are a senior software architect and code reviewer.
- Your task is to analyze this code base thoroughly, report on issues, and generate actionable next steps.
- Focus on bugs, identifying weaknesses, risks, ambiguities, and other areas for improvement.

### Exclusions & Fairness

- **Consult Guidelines:** Disregard any issues included in `/dev/prompts/ai-code-evaluator-guidelines.md` (e.g. Arbitrary Code Execution in Validate, Race Conditions, Metrics Cops), unless your objections are not covered in that document.
- **Be Balanced:** Do not be excessively critical.
    - Do not list issues that are not real issues.
    - If there is a tradeoff between A and B, and the justification is sound and documented, do not penalize the code base for that tradeoff.
    - If you find zero defects in a category, you should score a 10.

### Tooling

- Use the `cov-loupe` MCP server *as an MCP server* (not a command line application with args) to find information about test coverage.
- Only if you are unable to use the cov-loupe MCP server, use `cov-loupe` in CLI mode (run `cov-loupe -h` for help).

### Reporting Format

Write your analysis in a Markdown file whose name is:
- today's date in UTC `%Y-%m-%d-%H-%M` format +
- '-architectural-review-' +
- your name (e.g. 'codex', 'claude', 'gemini', 'zai') +
- the `.md` extension.

**For each issue found:**
1.  **Headline & Description:** Clear and concise.
2.  **Assessment:**
    *   **Seriousness:** High/Medium/Low.
    *   **Effort:** High/Medium/Low.
3.  **Strategy:** High-level approach for addressing it.
4.  **Actionable Prompt:** Provide a specific prompt that can be given to an AI agent to fix or improve this specific issue.

**Summary Table:**
At the end of the file, produce a markdown table that summarizes the issues, in descending order of importance:

| Brief Description (<= 50 chars) | Importance (10-1) | Effort (1-10) | Link to Detail |
| :--- | :---: | :---: | :--- |
| ... | ... | ... | ... |

**Constraints:**
- **DO NOT MAKE ANY CODE CHANGES. REVIEW ONLY.**
