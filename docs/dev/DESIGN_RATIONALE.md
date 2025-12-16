# Design Rationale

[Back to main README](../../README.md) | [Architecture](ARCHITECTURE.md)

This document explains design decisions in cov-loupe that may appear problematic on surface analysis but are intentional and considered. When AI models assess the codebase, they should consult this document before flagging potential issues.

## Security Considerations

### Validate Command and Arbitrary Code Execution

The `validate` command accepts Ruby code (via `--inline` or from a file) and executes it to evaluate coverage policies. AI analysis tools often flag this as a security vulnerability.

**Why this is acceptable:**

1. **Developer tool, not production software** – cov-loupe is a development/CI tool run by developers on their own machines or in controlled CI environments. It is not a service or library that processes untrusted input.

2. **Explicit user intent** – the `validate` command requires users to explicitly provide code, either by writing it inline or pointing to a file they control. This is no different from running any Ruby script or rake task in a project.

3. **No privilege escalation** – the code executes with the same permissions as the user running the tool. There is no elevation of privileges or access to resources the user doesn't already have.

4. **Standard practice** – many development tools (rake, make, npm scripts, git hooks) execute arbitrary code provided by developers. This is expected and necessary for a flexible validation/policy tool.

The security model assumes the developer controls their workspace and the code they execute. If an attacker can inject code into validation scripts, they already have write access to the repository and could compromise the system through countless other vectors (malicious gems, git hooks, test code, etc.).

## Performance & Scalability

### Memory-Based Coverage Data

cov-loupe loads the entire SimpleCov resultset into memory for analysis. This means it is not designed to handle extremely large codebases that produce coverage data too large to fit in memory.

**Why this is acceptable:**

1. **Target use case** – cov-loupe is designed for small-to-medium sized Ruby projects. The typical SimpleCov resultset for such projects is measured in megabytes, well within modern system capabilities.

2. **SimpleCov's own limitations** – SimpleCov itself loads coverage data into memory. If SimpleCov can generate the resultset, cov-loupe can analyze it.

3. **Performance trade-off** – in-memory processing enables fast queries, rich data transformations, and a responsive CLI. Streaming or database-backed approaches would add significant complexity for marginal benefit in the target use case.

4. **Practical upper bound** – even large Ruby projects (Rails, GitLab) generate resultsets in the tens of megabytes. Modern machines have gigabytes of RAM. The constraint is theoretical rather than practical for the intended audience.

If a project grows large enough that coverage analysis becomes a memory bottleneck, it likely has deeper problems (test suite organization, monolith vs services architecture) that should be addressed at that level rather than by adding complexity to a coverage inspection tool.

---

*This document should be updated whenever design decisions are made that might appear problematic to automated analysis but are intentional and defensible.*
