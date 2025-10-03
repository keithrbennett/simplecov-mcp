# Error Handling Guide

This tool provides different error handling behavior depending on how it's used:

## CLI Mode

When used as a command-line tool, errors are displayed as user-friendly messages without stack traces:

```bash
$ simplecov-mcp summary nonexistent.rb
File error: No coverage data found for the specified file
```

For debugging, set the environment variable to see full stack traces.

## Library Mode

When used as a Ruby library, errors are raised as custom exception classes that can be caught and handled:

```ruby
begin
  SimpleCovMcp.run_as_library(['summary', 'missing.rb'])
rescue SimpleCovMcp::FileError => e
  puts "Handled gracefully: #{e.user_friendly_message}"
end
```

Available exception classes:
- `SimpleCovMcp::Error` - Base error class
- `SimpleCovMcp::FileError` - File not found or access issues
- `SimpleCovMcp::CoverageDataError` - Invalid or missing coverage data
- `SimpleCovMcp::ConfigurationError` - Configuration problems
- `SimpleCovMcp::UsageError` - Command usage errors

## MCP Server Mode

When running as an MCP server, errors are handled internally and returned as structured responses to the MCP client. The MCP server uses:

- **Logging enabled** - Errors are logged to `~/simplecov_mcp.log` for server debugging
- **Clean error messages** - User-friendly messages are returned to the client (no stack traces unless)
- **Structured responses** - Errors are returned as proper MCP tool responses, not exceptions

The MCP server automatically configures error handling appropriately for server usage.

## Custom Error Handlers

Library usage defaults to no logging to avoid side effects, but you can customize this:

```ruby
# Default library behavior - no logging
SimpleCovMcp.run_as_library(['summary', 'file.rb'])

# Custom error handler with logging enabled
handler = SimpleCovMcp::ErrorHandler.new(
  log_errors: true,         # Enable logging for library usage
  show_stack_traces: false  # Clean error messages
)
SimpleCovMcp.run_as_library(argv, error_handler: handler)

# Or configure globally for MCP tools
SimpleCovMcp.configure_error_handling do |handler|
  handler.log_errors = true
  handler.show_stack_traces = true  # For debugging
end
```

## Stale Coverage Errors

When strict staleness checking is enabled (`--stale error`), the model (and CLI) raise a `CoverageDataStaleError` if a source file appears newer than the coverage data or the line counts differ.

- Enable per instance: `SimpleCovMcp::CoverageModel.new(staleness: 'error')`

The error message is detailed and includes:

- File and Coverage times (UTC and local) and line counts
- A delta indicating how much newer the file is than coverage
- The absolute path to the `.resultset.json` used

**Example excerpt:**

```
Coverage data stale: Coverage data appears stale for lib/foo.rb
File      - time: 2025-09-16T14:03:22Z (local 2025-09-16T07:03:22-07:00), lines: 226
Coverage  - time: 2025-09-15T21:11:09Z (local 2025-09-15T14:11:09-07:00), lines: 220
Delta     - file is +123s newer than coverage
Resultset - /path/to/your/project/coverage/.resultset.json
```
