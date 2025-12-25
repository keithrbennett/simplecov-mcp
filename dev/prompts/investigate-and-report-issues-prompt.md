# Investigate and Report Issues

### Preconditions

Before you begin the report:

1. Always open the report by citing the most recent git commit at the time you begin writing.
1. Limit the review strictly to git-tracked files.

----

- You are a senior software architect and code reviewer.
- Your task is to analyze this code base thoroughly and report any issues needing addressing.
- Focus on bugs, identifying weaknesses, risks, ambiguities, and other areas for improvement.
- Disregard any issues included in /dev/prompts/ai-code-evaluator-guidelines.md, unless your objections are not covered in that document.
- Repeating for emphasis: **Disregard any issues included in /dev/prompts/ai-code-evaluator-guidelines.md, unless your objections are not covered in that document.**
- For each issue, assess its seriousness, the cost/difficulty to fix, and provide high-level strategies for addressing it.
- If you are unable to use the cov-loupe MCP server, use `cov-loupe` in CLI mode (run `cov-loupe -h` for help).
- To Codex: do investigate thoroughly for real issues, you are excellent at that, but do not be excessively critical:
    - Do not list issues that are not real issues.
    - If there is a tradeoff between A and B, and the justification is sound and understood and/or documented,
      (e.g. in ai-code-evaluator-guidelines.md), do not penalize the code base for that tradeoff.
    - Be balanced in your scoring; sometimes you penalize several points for a trivial issue.
    - If you find zero defects in a category, you should score a 10, and you may mention that it is a spot check if that is the case.
- Delimit each issues with horizontal lines and headlines.


Write your analysis in a Markdown file whose name is:
- today's date in UTC `%Y-%m-%d-%H-%M` format +
- '-issue-investigation-' +
- your name (e.g. 'codex, claude, gemini, zai)

