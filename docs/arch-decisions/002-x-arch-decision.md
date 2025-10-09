# ADR 002: Context-Aware Error Handling Strategy

## Status

Accepted

## Context

SimpleCov MCP operates in three distinct contexts, each with different error handling requirements:

1. **CLI mode**: Human users expect friendly error messages, exit codes, and optional debug traces
2. **MCP server mode**: AI agents/clients need structured error responses that don't crash the server
3. **Library mode**: Embedding applications need exceptions they can catch and handle programmatically

Initially, we considered uniform error handling across all modes, but this created poor user experiences:

- CLI users saw raw exceptions with stack traces (scary and unhelpful)
- MCP servers crashed on errors instead of returning error responses
- Library users got friendly messages logged to stderr (unwanted side effects in their applications)

### Key Requirements

- **CLI**: User-friendly messages, meaningful exit codes, optional stack traces for debugging
- **MCP Server**: Logged errors (to file, not stdout), structured JSON-RPC error responses, no server crashes
- **Library**: Raise custom exceptions with no logging, allowing consumers to handle errors as needed
- **Consistency**: Same underlying error types, but different presentation strategies

## Decision

We implemented a **context-aware error handling strategy** using three components:

### 1. Custom Exception Hierarchy

All errors inherit from `SimpleCovMcp::Error` (lib/simplecov_mcp/errors.rb) with a `user_friendly_message` method:

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

### 2. ErrorHandler Class

The `ErrorHandler` class (lib/simplecov_mcp/error_handler.rb:7) provides configurable error handling behavior:

```ruby
class ErrorHandler
  attr_accessor :error_mode, :logger

  VALID_ERROR_MODES = [:off, :on, :on_with_trace].freeze

  def initialize(error_mode: :on, logger: nil)
    @error_mode = error_mode
    @logger = logger
  end

  def handle_error(error, context: nil, reraise: true)
    log_error(error, context)
    if reraise
      raise error.is_a?(SimpleCovMcp::Error) ? error : convert_standard_error(error)
    end
  end
end
```

The `convert_standard_error` method (lib/simplecov_mcp/error_handler.rb:37) transforms Ruby's standard errors into user-friendly custom exceptions:

- `Errno::ENOENT` → `FileNotFoundError`
- `JSON::ParserError` → `CoverageDataError`
- `Errno::EACCES` → `FilePermissionError`

### 3. ErrorHandlerFactory

The `ErrorHandlerFactory` (lib/simplecov_mcp/error_handler_factory.rb:4) creates mode-specific handlers:

```ruby
module ErrorHandlerFactory
  def self.for_cli(error_mode: :on)
    ErrorHandler.new(error_mode: error_mode)
  end

  def self.for_library(error_mode: :off)
    ErrorHandler.new(error_mode: :off)  # No logging
  end

  def self.for_mcp_server(error_mode: :on)
    ErrorHandler.new(error_mode: :on)   # Logs to file
  end
end
```

### Error Flow by Mode

**CLI Mode** (lib/simplecov_mcp/cli.rb):
1. Catches all exceptions in the main run loop
2. Uses `for_cli` handler to log errors if debug mode is enabled
3. Displays `user_friendly_message` to the user
4. Exits with appropriate code (1 for errors, 2 for usage errors)

**MCP Server Mode** (lib/simplecov_mcp/base_tool.rb:46):
1. Each tool wraps execution in a rescue block
2. Uses `for_mcp_server` handler to log errors to `~/simplecov_mcp.log`
3. Returns structured JSON-RPC error response
4. Server continues running (no crashes)

**Library Mode** (lib/simplecov_mcp.rb:75):
1. Uses `for_library` handler with `error_mode: :off` (no logging)
2. Raises custom exceptions directly
3. Consumers catch and handle `SimpleCovMcp::Error` subclasses

## Consequences

### Positive

1. **Excellent UX**: Each context gets appropriate error handling behavior
2. **Robustness**: MCP server never crashes on tool errors
3. **Debuggability**: CLI users can enable stack traces with error modes, MCP errors are logged
4. **Clean library API**: No unwanted side effects (logging, stderr output) when used as a library
5. **Type safety**: Custom exceptions allow programmatic error handling by type

### Negative

1. **Complexity**: Three error handling paths to maintain and test
2. **Coordination required**: All error types must implement `user_friendly_message` consistently
3. **Error conversion overhead**: Standard errors must be converted to custom exceptions

### Trade-offs

- **Versus uniform error handling**: More code complexity, but dramatically better UX in each context
- **Versus separate error classes per mode**: Single error hierarchy is simpler, factory pattern adds mode-specific behavior

### Implementation Notes

The `ErrorHandler.convert_standard_error` method (lib/simplecov_mcp/error_handler.rb:37) uses pattern matching on exception types and error messages to provide helpful, context-aware error messages. This includes:

- Extracting filenames from system error messages
- Detecting SimpleCov-specific error patterns
- Providing actionable suggestions ("please run your tests first")

## References

- Custom exceptions: `lib/simplecov_mcp/errors.rb`
- ErrorHandler implementation: `lib/simplecov_mcp/error_handler.rb:7-124`
- ErrorHandlerFactory: `lib/simplecov_mcp/error_handler_factory.rb:4-29`
- CLI error handling: `lib/simplecov_mcp/cli.rb` (rescue block in run method)
- MCP tool error handling: `lib/simplecov_mcp/base_tool.rb:46-54`
- Library mode: `lib/simplecov_mcp.rb:75-86`
- Related ADR: [001: Dual-Mode Operation](001-x-arch-decision.md)
