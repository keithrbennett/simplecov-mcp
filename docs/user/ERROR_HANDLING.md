# Error Handling Guide

[Back to main README](../README.md)

Error handling differs by usage mode:

## CLI Mode

Errors are displayed as user-friendly messages without stack traces:

```bash
$ simplecov-mcp summary nonexistent.rb
File error: No coverage data found for the specified file
```

For debugging, use the `--error-mode trace` flag to include stack traces in log output and display the first 5 lines of the backtrace in CLI output:

```bash
$ simplecov-mcp --error-mode trace summary nonexistent.rb
```

## Library Mode

Calls to `SimpleCovMcp::CoverageModel` raise custom exceptions you can handle programmatically:

```ruby
handler = SimpleCovMcp::ErrorHandlerFactory.for_library  # disables CLI-style logging
context = SimpleCovMcp.create_context(error_handler: handler)

SimpleCovMcp.with_context(context) do
  model = SimpleCovMcp::CoverageModel.new
  begin
    model.summary_for('missing.rb')
  rescue SimpleCovMcp::FileError => e
    puts "Handled gracefully: #{e.user_friendly_message}"
  end
end
```

Available exception classes:
- `SimpleCovMcp::Error` - Base error class
- `SimpleCovMcp::FileError` - File not found or access issues
- `SimpleCovMcp::CoverageDataError` - Invalid or missing coverage data
- `SimpleCovMcp::ConfigurationError` - Configuration problems
- `SimpleCovMcp::UsageError` - Command usage errors

## MCP Server Mode

Errors are returned as structured responses to the MCP client:

- **Logging enabled** - Errors go to `simplecov_mcp.log` in the current directory by default
- **Clean error messages** - User-friendly messages, no stack traces by default
- **Structured responses** - Tool responses instead of exceptions

## Custom Error Handlers

Library usage can opt into different logging behavior by installing a custom handler on the active context:

```ruby
handler = SimpleCovMcp::ErrorHandler.new(
  log_errors: true,         # Enable logging when embedding
  show_stack_traces: false  # Keep error messages clean
)

context = SimpleCovMcp.create_context(error_handler: handler)

SimpleCovMcp.with_context(context) do
  model = SimpleCovMcp::CoverageModel.new
  model.summary_for('lib/simplecov_mcp/model.rb')
end
```

## Stale Coverage Errors

When strict staleness checking is enabled (`--staleness error`), the model (and CLI) raise a `CoverageDataStaleError` if a source file appears newer than the coverage data or the line counts differ.

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
