# ADR 001: Dual-Mode Operation (CLI and MCP Server)

[Back to main README](../../README.md)

## Status

Accepted

## Context

SimpleCov MCP needed to serve two distinct use cases:

1. **Human users** wanting a command-line tool to inspect coverage reports in their terminal
2. **AI agents and MCP clients** needing programmatic access to coverage data via the Model Context Protocol (MCP) over JSON-RPC

We considered three approaches:

1. **Separate binaries/gems**: Create `simplecov-cli` and `cov-loupe` as separate projects
2. **Single binary with explicit mode flags**: Require users to pass `--mcp` or `--cli` to select mode
3. **Automatic mode detection**: Single binary that automatically detects the operating mode based on input

### Key Constraints

- MCP servers communicate via JSON-RPC over stdin/stdout, so any human-readable output would corrupt the protocol
- CLI users expect immediate, readable output without ceremony
- The gem should be simple to install and use for both audiences
- Mode detection must be reliable and unambiguous

## Decision

We implemented **automatic mode detection** via a single entry point (`CovLoupe.run`) that routes to either CLI or MCP server mode based on the execution context.

### Mode Detection Algorithm

The `ModeDetector` class (lib/cov_loupe/mode_detector.rb:6) implements a priority-based detection strategy:

1. 
2. 
3. **Force mode flag** (`-F/--force-mode cli|mcp`) overrides detection
2. **Explicit CLI flags** (`-h`, `--help`, `--version`) → CLI mode
2. **Presence of subcommands** (non-option arguments like `summary`, `list`) → CLI mode
3. **TTY detection** fallback: `stdin.tty?` returns true → CLI mode, false → MCP server mode

The implementation is in `lib/cov_loupe.rb:34-52`:

```ruby
def run(argv)
  env_opts = extract_env_opts
  full_argv = env_opts + argv

  if ModeDetector.cli_mode?(full_argv)
    CoverageCLI.new.run(argv)
  else
    CovLoupe.default_log_file = parse_log_file(full_argv)
    MCPServer.new.run
  end
end
```

### Why This Works

- **MCP clients** pipe JSON-RPC to stdin (not a TTY) and don't pass subcommands → routes to MCP server
- **CLI users** run from an interactive terminal (TTY) or pass explicit subcommands → routes to CLI
- **Edge cases** are covered by explicit flags (`--force-mode mcp` for testing MCP mode from a TTY)

## Consequences

### Positive

1. **User convenience**: Single gem to install (`gem install cov-loupe`), single executable (`cov-loupe`)
2. **No ceremony**: Users don't need to remember mode flags or understand the MCP/CLI distinction
3. **Testable**: The `ModeDetector` class is a pure function that can be tested in isolation
4. **Clear separation**: CLI and MCP server implementations remain completely separate after routing

### Negative

1. **Complexity**: Requires maintaining the mode detection logic and keeping it accurate
2. **Potential ambiguity**: In unusual environments (non-TTY CLI execution without subcommands), users must understand `--force-mode`
3. **Shared dependencies**: Some components (error handling, coverage model) must work correctly in both modes

### Trade-offs

- **Versus separate gems**: More initial complexity, but better DX (single installation, no confusion about which gem to use)
- **Versus explicit mode flags**: Slightly more "magical", but eliminates user error and reduces boilerplate

### Future Constraints

- Mode detection logic must remain stable and backward-compatible
- Any new CLI subcommands must be registered in `ModeDetector::SUBCOMMANDS`
- Shared components (like `CoverageModel`) must never output to stdout/stderr in ways that differ by mode

## References

- Implementation: `lib/cov_loupe.rb:34-52`
- Mode detection: `lib/cov_loupe/mode_detector.rb:6-63`
- CLI implementation: `lib/cov_loupe/cli.rb`
- MCP server implementation: `lib/cov_loupe/mcp_server.rb`
- Related ADR: [002: Context-Aware Error Handling](002-x-arch-decision.md)
