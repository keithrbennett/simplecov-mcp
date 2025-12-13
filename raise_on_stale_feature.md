## Task: Implement and Verify Unified `raise_on_stale` Feature

**Objective:**
The `cov-loupe` Ruby gem previously had an inconsistent and potentially confusing approach to handling stale coverage data. The goal of this task was to refactor the staleness checking mechanism to be unified, consistent, and clearer across all interfaces (Ruby API, CLI, and MCP tools) using a single boolean flag, `raise_on_stale`. This change aims to simplify the architecture, improve readability, and streamline future enhancements.

**Feature Description: `raise_on_stale`**
The `raise_on_stale` feature standardizes how `cov-loupe` behaves when it detects outdated or inconsistent coverage data (e.g., source files newer than coverage reports, line count mismatches, missing files).

*   **Mechanism:** It replaces the previous `staleness:` parameter (which accepted symbols like `:off` or `:error`) and the `check_stale:` boolean parameter (used in specific methods). Now, `raise_on_stale` is a straightforward boolean:
    *   `true`: If stale coverage is detected, a `CovLoupe::CoverageDataStaleError` or `CovLoupe::CoverageDataProjectStaleError` will be raised, causing the operation to fail.
    *   `false`: Staleness will be noted (e.g., the `stale: 'T'` flag will still appear in reports), but no error will be raised. This allows for reporting staleness without halting execution.

*   **Unified Behavior:** This boolean flag is now the primary mechanism to control enforcement across all relevant methods in the `CoverageModel`, and it is directly exposed via the CLI and MCP tools.

**Current Status & Completed Work:**

The implementation and verification of the `raise_on_stale` feature are **complete**. All code changes have been applied, and the entire test suite passes successfully.

Specifically, the following subtasks have been finished:

1.  **Update CoverageModel API:**
    *   The `CoverageModel` constructor now accepts `raise_on_stale: false` (default) instead of `staleness: :off`.
    *   Methods like `raw_for`, `summary_for`, `uncovered_for`, `detailed_for`, `list`, `project_totals`, and `format_table` now accept an optional `raise_on_stale` boolean parameter.
    *   The internal `StalenessChecker` instances are now created on-demand per call, mapping the `raise_on_stale` boolean to the `StalenessChecker`'s internal `:error` or `:off` mode as needed. The persistent `@checker` instance has been removed from the model.

2.  **Update CLI Layer:**
    *   The `--staleness` CLI option has been renamed to `--raise-on-stale`.
    *   `OptionParserBuilder`, `AppConfig`, and the main `CLI` logic have been updated to handle this new boolean flag.
    *   The translation logic (`config.staleness == :error`) has been removed in favor of directly using `config.raise_on_stale`.

3.  **Update MCP Tools:**
    *   All relevant MCP tools (`ListTool`, `CoverageTotalsTool`, `CoverageTableTool`, `CoverageSummaryTool`, `CoverageRawTool`, `CoverageDetailedTool`, `UncoveredLinesTool`, `ValidateTool`) have had their input schemas and internal logic updated to accept and utilize the `raise_on_stale` boolean parameter.

4.  **Update Presenters:**
    *   `ProjectCoveragePresenter` and `ProjectTotalsPresenter` have been updated to accept and store `raise_on_stale` instead of `check_stale`, and pass this flag correctly to the `CoverageModel` methods.

5.  **Update Specs:**
    *   The entire RSpec test suite has been systematically updated to reflect the new API signatures and boolean flag usage. All 764 examples pass with 0 failures, ensuring the correctness and robustness of the refactoring.

6.  **Update Documentation:**
    *   The user documentation (`CLI_USAGE.md`, `LIBRARY_API.md`, `MCP_INTEGRATION.md`) has been updated to explain and demonstrate the use of the new `raise_on_stale` feature.

**Rationale for the Change:**
The previous design created an unnecessary distinction between a configuration setting (`staleness`) and an override argument (`check_stale`), leading to potential confusion. The `raise_on_stale` boolean simplifies the API significantly by:
*   **Clarity:** The name directly conveys its purpose ("raise an error if stale").
*   **Consistency:** A single boolean flag is used uniformly across all methods and interfaces.
*   **Flexibility:** While we originally considered using an enum (like `:warn`), the primary use cases are "raise error" or "don't raise error". The boolean `raise_on_stale` directly addresses this, and future logging/warning behavior can still be added without impacting this core decision.
*   **Architectural Simplicity:** Removing the persistent `@checker` instance from the `CoverageModel` and creating checker instances per call removes hidden state and makes method behavior more predictable.

**Remaining Tasks:**
None. The implementation, testing, and documentation of the `raise_on_stale` feature are complete. The codebase is now in a consistent and robust state regarding staleness handling.