# Application Architecture

[Back to main README](../../index.md)

This document describes the core architectural decisions that shape how cov-loupe operates: its dual-mode design and context-aware error handling strategy.

## Table of Contents

- [Dual-Mode Operation (CLI and MCP Server)](#dual-mode-operation-cli-and-mcp-server)
- [Context-Aware Error Handling](#context-aware-error-handling)

---

## Dual-Mode Operation (CLI and MCP Server)

### Status

Accepted

### Context

cov-loupe needed to serve two distinct use cases:

1. **Human users** wanting a command-line tool to inspect coverage reports in their terminal
2. **AI agents and MCP clients** needing programmatic access to coverage data via the Model Context Protocol (MCP) over JSON-RPC

We considered three approaches:

1. **Separate binaries/gems**: Create `simplecov-cli` and `cov-loupe` as separate projects
2. **Single binary with explicit mode flags**: Require users to pass `--mcp` or `--cli` to select mode
3. **Automatic mode detection**: Single binary that automatically detects the operating mode based on input

#### Key Constraints

- MCP servers communicate via JSON-RPC over stdin/stdout, so any human-readable output would corrupt the protocol
- CLI users expect immediate, readable output without ceremony
- The gem should be simple to install and use for both audiences
- Mode detection must be reliable and unambiguous

### Decision

We implemented **automatic mode detection** via a single entry point (`CovLoupe.run`) that routes to either CLI or MCP server mode based on the execution context.

#### Mode Detection Algorithm

The `ModeDetector` class (defined in `lib/cov_loupe/mode_detector.rb`) implements a priority-based detection strategy:

1. **Force mode flag** (`-F/--force-mode cli|mcp`) overrides detection
2. **Explicit CLI flags** (`-h`, `--help`, `--version`) → CLI mode
3. **Presence of subcommands** (non-option arguments like `summary`, `list`) → CLI mode
4. **TTY detection** fallback: `stdin.tty?` returns true → CLI mode, false → MCP server mode

The implementation lives in `lib/cov_loupe.rb` within `CovLoupe.run`:

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

#### Why This Works

- **MCP clients** pipe JSON-RPC to stdin (not a TTY) and don't pass subcommands → routes to MCP server
- **CLI users** run from an interactive terminal (TTY) or pass explicit subcommands → routes to CLI
- **Edge cases** are covered by explicit flags (`--force-mode mcp` for testing MCP mode from a TTY)

### Consequences

#### Positive

1. **User convenience**: Single gem to install (`gem install cov-loupe`), single executable (`cov-loupe`)
2. **No ceremony**: Users don't need to remember mode flags or understand the MCP/CLI distinction
3. **Testable**: The `ModeDetector` class is a pure function that can be tested in isolation
4. **Clear separation**: CLI and MCP server implementations remain completely separate after routing

#### Negative

1. **Complexity**: Requires maintaining the mode detection logic and keeping it accurate
2. **Potential ambiguity**: In unusual environments (non-TTY CLI execution without subcommands), users must understand `--force-mode`
3. **Shared dependencies**: Some components (error handling, coverage model) must work correctly in both modes

#### Trade-offs

- **Versus separate gems**: More initial complexity, but better DX (single installation, no confusion about which gem to use)
- **Versus explicit mode flags**: Slightly more "magical", but eliminates user error and reduces boilerplate

#### Future Constraints

- Mode detection logic must remain stable and backward-compatible
- Any new CLI subcommands must be registered in `ModeDetector::SUBCOMMANDS`
- Shared components (like `CoverageModel`) must never output to stdout/stderr in ways that differ by mode

### References

- Implementation: `lib/cov_loupe.rb` (`CovLoupe.run`)
- Mode detection: `lib/cov_loupe/mode_detector.rb`
- CLI implementation: `lib/cov_loupe/cli.rb`
- MCP server implementation: `lib/cov_loupe/mcp_server.rb`
- Related section: [Context-Aware Error Handling](#context-aware-error-handling)

---

## Context-Aware Error Handling

### Status

Accepted

### Context

cov-loupe operates in three distinct contexts, each with different error handling requirements:

1. **CLI mode**: Human users expect friendly error messages, exit codes, and optional debug traces
2. **MCP server mode**: AI agents/clients need structured error responses that don't crash the server
3. **Library mode**: Embedding applications need exceptions they can catch and handle programmatically

Initially, we considered uniform error handling across all modes, but this created poor user experiences:

- CLI users saw raw exceptions with stack traces (scary and unhelpful)
- MCP servers crashed on errors instead of returning error responses
- Library users got friendly messages logged to stderr (unwanted side effects in their applications)

#### Key Requirements

- **CLI**: User-friendly messages, meaningful exit codes, optional stack traces for debugging
- **MCP Server**: Logged errors (to file, not stdout), structured JSON-RPC error responses, no server crashes
- **Library**: Raise custom exceptions with no logging, allowing consumers to handle errors as needed
- **Consistency**: Same underlying error types, but different presentation strategies

### Decision

We implemented a **context-aware error handling strategy** using three components:

#### 1. Custom Exception Hierarchy

All errors inherit from `CovLoupe::Error` (lib/cov_loupe/errors.rb) with a `user_friendly_message` method:

```ruby
class Error < StandardError
  def user_friendly_message
    message  # Can be overridden in subclasses
  end
end

class FileNotFoundError < FileError; end
class CoverageDataError < Error; end
class ResultsetNotFoundError < CoverageDataError; end
# ... etc
```

This provides a unified interface for presenting errors to users while preserving exception types for programmatic handling.

#### 2. ErrorHandler Class

The `ErrorHandler` class (see `lib/cov_loupe/error_handler.rb`) provides configurable error handling behavior:

```ruby
class ErrorHandler
  attr_accessor :error_mode, :logger

  VALID_ERROR_MODES = [:off, :log, :debug].freeze

  def initialize(error_mode: :log, logger: nil)
    @error_mode = error_mode
    @logger = logger
  end

  def handle_error(error, context: nil, reraise: true)
    log_error(error, context)
    if reraise
      raise error.is_a?(CovLoupe::Error) ? error : convert_standard_error(error)
    end
  end
end
```

The `convert_standard_error` method transforms Ruby's standard errors into user-friendly custom exceptions:

- `Errno::ENOENT` → `FileNotFoundError`
- `JSON::ParserError` → `CoverageDataError`
- `Errno::EACCES` → `FilePermissionError`

#### 3. ErrorHandlerFactory

The `ErrorHandlerFactory` (defined in `lib/cov_loupe/error_handler_factory.rb`) creates mode-specific handlers:

```ruby
module ErrorHandlerFactory
  def self.for_cli(error_mode: :log)
    ErrorHandler.new(error_mode: error_mode)
  end

  def self.for_library(error_mode: :off)
    ErrorHandler.new(error_mode: :off)  # No logging
  end

  def self.for_mcp_server(error_mode: :log)
    ErrorHandler.new(error_mode: :log)   # Logs to file
  end
end
```

#### Error Flow by Mode

**CLI Mode** (lib/cov_loupe/cli.rb):
1. Catches all exceptions in the main run loop
2. Uses `for_cli` handler to log errors if debug mode is enabled
3. Displays `user_friendly_message` to the user
4. Exits with appropriate code (1 for errors, 2 for usage errors)

**MCP Server Mode** (`lib/cov_loupe/base_tool.rb`):
1. Each tool wraps execution in a rescue block
2. Uses `for_mcp_server` handler to log errors to `~/cov_loupe.log`
3. Returns structured JSON-RPC error response
4. Server continues running (no crashes)

**Library Mode** (`lib/cov_loupe.rb`):
1. Uses `for_library` handler with `error_mode: :off` (no logging)
2. Raises custom exceptions directly
3. Consumers catch and handle `CovLoupe::Error` subclasses

### Consequences

#### Positive

1. **Excellent UX**: Each context gets appropriate error handling behavior
2. **Robustness**: MCP server never crashes on tool errors
3. **Debuggability**: CLI users can enable stack traces with error modes, MCP errors are logged
4. **Clean library API**: No unwanted side effects (logging, stderr output) when used as a library
5. **Type safety**: Custom exceptions allow programmatic error handling by type

#### Negative

1. **Complexity**: Three error handling paths to maintain and test
2. **Coordination required**: All error types must implement `user_friendly_message` consistently
3. **Error conversion overhead**: Standard errors must be converted to custom exceptions

#### Trade-offs

- **Versus uniform error handling**: More code complexity, but dramatically better UX in each context
- **Versus separate error classes per mode**: Single error hierarchy is simpler, factory pattern adds mode-specific behavior

#### Implementation Notes

The `ErrorHandler.convert_standard_error` method uses pattern matching on exception types and error messages to provide helpful, context-aware error messages. This includes:

- Extracting filenames from system error messages
- Detecting SimpleCov-specific error patterns
- Providing actionable suggestions ("please run your tests first")

### References

- Custom exceptions: `lib/cov_loupe/errors.rb`
- ErrorHandler implementation: `lib/cov_loupe/error_handler.rb`
- ErrorHandlerFactory: `lib/cov_loupe/error_handler_factory.rb`
- CLI error handling: `lib/cov_loupe/cli.rb` (rescue block in `CoverageCLI#run`)
- MCP tool error handling: `lib/cov_loupe/base_tool.rb` (`BaseTool#call`)
- Library mode: `lib/cov_loupe.rb` (error handling within `CovLoupe.run`)
- Related section: [Dual-Mode Operation](#dual-mode-operation-cli-and-mcp-server)
