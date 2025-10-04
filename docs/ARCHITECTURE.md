# Architecture

simplecov-mcp is organized around a single coverage data model that feeds three delivery channels: a command-line interface, an MCP server for LLM agents, and a light-weight Ruby API. The codebase is intentionally modular—shared logic for loading, normalizing, and validating SimpleCov data lives in `lib/simplecov_mcp/`, while adapters wrap that core for each runtime mode.

## Runtime Entry Points

- **Executable** – `exe/simplecov-mcp` bootstraps the gem, enforces Ruby >= 3.2, and delegates to `SimpleCovMcp.run(ARGV)`.
- **Mode Negotiation** – `SimpleCovMcp.run` inspects environment defaults from `SIMPLECOV_MCP_OPTS`, checks for CLI subcommands, and prefers CLI mode when STDIN is a TTY. Otherwise it instantiates `SimpleCovMcp::MCPServer`.
- **Embedded Usage** – `SimpleCovMcp.run_as_library(argv, error_handler:)` lets callers execute the same commands without the CLI’s process control. It configures a library-oriented error handler and reuses `CoverageModel` directly.

## Coverage Data Pipeline

1. **Resultset discovery** – The tool locates the `.resultset.json` file by checking a series of default paths or by using a path specified by the user. For a detailed explanation of the configuration options, see the [Configuring the Resultset](../README.md#configuring-the-resultset) section in the main README.
2. **Parsing and normalization** – `CoverageModel` loads the chosen resultset once, selects the first suite that exposes `coverage`, and maps all file keys to absolute paths anchored at the configured project root. Timestamps are cached for staleness checks.
3. **Path relativizing** – `PathRelativizer` produces relative paths for user-facing payloads without mutating the canonical data. Tool responses pass through `CoverageModel#relativize` before leaving the process.
4. **Derived metrics** – `CovUtil.summary`, `CovUtil.uncovered`, and `CovUtil.detailed` compute coverage stats from the raw `lines` arrays. `CoverageModel` exposes `summary_for`, `uncovered_for`, `detailed_for`, and `raw_for` helpers that wrap these utilities.
5. **Staleness detection** – `StalenessChecker` compares source mtimes/line counts to coverage metadata. CLI flags and MCP arguments can promote warnings to hard failures (`--stale error`) or simply mark rows as stale for display.

## Interfaces

### CLI (`SimpleCovMcp::CoverageCLI`)

- Builds on Ruby’s `OptionParser`, with global options such as `--resultset`, `--stale`, `--json`, and `--source` modes.
- Subcommands (`list`, `summary`, `raw`, `uncovered`, `detailed`, `version`) translate to calls on `CoverageModel`.
- Uses `ErrorHandlerFactory.for_cli` to convert unexpected exceptions into friendly user messages while honoring `--error-mode`.
- Formatting logic (tables, JSON) lives in the model to keep presentation consistent with MCP responses.

### MCP Server (`SimpleCovMcp::MCPServer`)

- Assembles a list of tool classes and mounts them in `MCP::Server` using STDIO transport.
- Relies on the same core model; each tool instance recreates `CoverageModel` with the arguments provided by the MCP client, keeping the server stateless between requests.
- Error handling delegates to `BaseTool.handle_mcp_error`, which swaps in the MCP-specific handler and emits `MCP::Tool::Response` objects.

### Library API

- Consuming code can instantiate `CoverageModel` directly for fine-grained control, or call `SimpleCovMcp.run_as_library` for a higher-level wrapper over the CLI verbs.
- Library mode defaults to silent error logging (`error_mode: :off`) so host applications can decide how to surface failures.

## MCP Tool Stack

- `SimpleCovMcp::BaseTool` centralizes JSON schema definitions, error conversion, and response serialization for the MCP protocol.
- Individual tools reside in `lib/simplecov_mcp/tools/` and follow a consistent shape: define an input schema, call into `CoverageModel`, then serialize via `respond_json`. Examples include `AllFilesCoverageTool`, `CoverageSummaryTool`, and `UncoveredLinesTool`.
- Tools are registered in `SimpleCovMcp::MCPServer#run`. Adding a new tool only requires creating a subclass and appending it to that list.

## Error Handling & Logging

- Custom exceptions under `lib/simplecov_mcp/errors.rb` capture context for configuration issues, missing files, stale coverage, and general runtime errors. Each implements `#user_friendly_message` for consistent UX.
- `SimpleCovMcp::ErrorHandler` encapsulates logging and severity decisions. Modes (`:off`, `:on`, `:on_with_trace`) control whether errors are recorded and whether stack traces are included.
- `ErrorHandlerFactory` wires the appropriate handler per runtime: CLI, MCP server, or embedded library.
- Diagnostics are written via `CovUtil.log` to `simplecov_mcp.log` by default (override with `--log-file` or `SimpleCovMcp.log_file = '-'` to disable).

## Configuration Surface

- **Environment defaults** – `SIMPLECOV_MCP_OPTS` applies baseline CLI flags before parsing the actual command line.
- **Resultset overrides** – The location of the `.resultset.json` file can be specified via CLI options or in the MCP configuration. See [Configuring the Resultset](../README.md#configuring-the-resultset) for details.
- **Tracked globs** – For project staleness checks, `tracked_globs` ensures new files raise alerts when absent from coverage.
- **Colorized source** – CLI-only flags (`--source`, `--source-context`, `--color`) enhance human-readable reports when working locally.

## Repository Layout Highlights

- `lib/simplecov_mcp/` – Core runtime (model, utilities, error handling, CLI, MCP server, tools).
- `lib/simplecov_mcp.rb` – Primary public entry point required by gem consumers.
- `docs/` – User-facing guides (usage, installation, troubleshooting, architecture).
- `spec/` – RSpec suite with fixtures under `spec/fixtures/` for deterministic coverage data.
- `scripts/` – Helper scripts (e.g., `scripts/setup_codex_cloud.sh`).

## Extending the System

1. Add or update data processing inside `CoverageModel` or `CovUtil` when a new metric is needed.
2. Surface that metric through the desired interface: CLI option/subcommand, new MCP tool, or library helper.
3. Register the new tool in `MCPServer`, or update CLI option parsing in `CoverageCLI`.
4. Provide tests under `spec/` mirroring the lib path (`spec/lib/simplecov_mcp/..._spec.rb`).
5. Update documentation to reflect the new capability.

By funnelling every interface through the shared `CoverageModel`, simplecov-mcp guarantees that CLI users, MCP clients, and embedding libraries all observe identical coverage semantics and staleness rules, while still allowing each adapter to tailor presentation and error handling to its audience.
