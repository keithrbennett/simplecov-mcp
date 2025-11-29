# Troubleshooting Guide

[Back to main README](../README.md)

## Table of Contents

- [Running Issues](#running-issues)
- [Coverage Data Issues](#coverage-data-issues)
- [MCP Server Issues](#mcp-server-issues)
- [Development Issues](#development-issues)
- [Diagnostic Commands](#diagnostic-commands)

## Running Issues

### Running the Test Suite with RVM (Codex macOS)

Codex's macOS sandbox forbids `/bin/ps`; RVM shells need it. When you run `bundle exec rspec` there, the shell falls back to macOS Ruby 2.6 and Bundler dies with `Gem::Resolver::APISet::GemParser` errors.

**Workarounds:**

- Run outside the macOS sandbox (Codex on Ubuntu, Gemini, Claude Code, local shells) or use a version manager that does not invoke `ps`.
- Or execute RSpec with explicit RVM paths:
  ```bash
  PATH="$HOME/.rvm/gems/ruby-3.4.5@simplecov-mcp/bin:$HOME/.rvm/rubies/ruby-3.4.5/bin:$PATH" \
    GEM_HOME="$HOME/.rvm/gems/ruby-3.4.5@simplecov-mcp" \
    GEM_PATH="$HOME/.rvm/gems/ruby-3.4.5@simplecov-mcp:$HOME/.rvm/gems/ruby-3.4.5@global" \
    $HOME/.rvm/rubies/ruby-3.4.5/bin/bundle exec rspec
  ```
- Use a different AI coding agent and/or operating system.

## Coverage Data Issues

### Missing `coverage/.resultset.json`

`simplecov-mcp` only reads coverage data; it never generates it. If you see "Could not find .resultset.json":

1. Run the test suite with SimpleCov enabled (default project setup already enables it).
   ```bash
   bundle exec rspec
   ls coverage/.resultset.json
   ```
2. If your coverage lives elsewhere, point the tools at it:
   ```bash
   simplecov-mcp --resultset build/coverage/.resultset.json
   # or
   export SIMPLECOV_MCP_OPTS="--resultset build/coverage"
   ```

### Stale Coverage Errors

`--staleness error` (or `staleness: 'error'`) compares file mtimes and line counts to the coverage snapshot. When it fails:

- Regenerate coverage (`bundle exec rspec`) so the snapshot matches current sources.
- Or drop back to warning-only behaviour using `--staleness off` / `staleness: 'off'`.

If you only care about a subset of files, supply `--tracked-globs` (CLI) or `tracked_globs:` (API) so new files outside those globs do not trigger staleness.

### "No coverage data found for file"

The model looks up files by absolute path, then cwd-relative path, then basename. If you still hit this error:

1. Verify the file is listed in the coverage table (`simplecov-mcp list | grep model.rb`).
2. Use the exact project-relative path that SimpleCov recorded (case-sensitive, no symlinks).
3. If the file truly never executes under tests, add coverage or exclude it from your workflow.

## MCP Server Issues

### MCP Integration Not Working

**Symptoms:**
- AI assistant reports "Could not connect to MCP server"
- AI says "I don't have access to simplecov-mcp tools"

**Diagnostic steps:**

1. **Verify executable exists and works:**
   ```bash
   which simplecov-mcp
   simplecov-mcp version
   ```

2. **Test MCP server mode manually:**
   ```bash
   echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"version_tool","arguments":{}}}' | simplecov-mcp
   ```
   Should return JSON-RPC response.

3. **Verify MCP server is configured:**
   ```bash
   claude mcp list  # For Claude Code
   codex mcp list   # For Codex
   tail -f simplecov_mcp.log  # Check logs
   ```

4. **Restart AI assistant** - Config changes often require restart

5. **Use absolute path in MCP config:**
   ```bash
   # Find absolute path
   which simplecov-mcp

   # Update your MCP client config to use this path
   ```

6. **Use CLI as fallback:**

   If MCP still isn't working, you can use the CLI with `--json` flag instead.
   See **[CLI Fallback for LLMs](CLI_FALLBACK_FOR_LLMS.md)** for complete guidance.

### Path Issues with Version Managers

**Symptom:** Works in terminal but not in MCP client.

**Cause:** MCP client doesn't have your shell environment (PATH, RVM, etc.).

**Solution:** Use absolute paths in MCP configuration:

```bash
# For rbenv/asdf
which simplecov-mcp
# Use this path in MCP config

# For RVM, create wrapper
rvm wrapper ruby-3.3.8 simplecov-mcp simplecov-mcp
# Use: ~/.rvm/wrappers/ruby-3.3.8/simplecov-mcp
```

## Development Issues

### Test Suite Failures

**Symptom:** `bundle exec rspec` fails with coverage errors.

**Common causes:**

1. **Stale coverage data** - Delete `coverage/` directory and re-run
2. **SimpleCov not loaded** - Check `spec/spec_helper.rb` requires SimpleCov
3. **Wrong Ruby version** - Verify Ruby >= 3.2

## Diagnostic Commands

Before reporting an issue, run these diagnostic commands and include the output:

```bash
# System info
ruby -v
gem -v
bundle -v

# simplecov-mcp info
gem list simplecov-mcp
which simplecov-mcp
simplecov-mcp version

# Test basic functionality
simplecov-mcp --help
simplecov-mcp list 2>&1

# Check coverage data
ls -la coverage/.resultset.json
head -20 coverage/.resultset.json

# Test MCP mode
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"version_tool","arguments":{}}}' | simplecov-mcp 2>&1
```

## Getting More Help

If the above doesn't solve your problem:

1. **Check error mode** - Run with `--error-mode debug` for full stack traces:
   ```bash
   simplecov-mcp --error-mode debug summary lib/simplecov_mcp/cli.rb
   ```

2. **Check logs:**
   ```bash
   # MCP server logs
   tail -50 simplecov_mcp.log

   # Or specify custom log location
   simplecov-mcp --log-file /tmp/debug.log summary lib/simplecov_mcp/cli.rb
   ```

3. **Search existing issues:**
   https://github.com/keithrbennett/simplecov-mcp/issues

4. **Report a bug:**
   Include output from [Diagnostic Commands](#diagnostic-commands) above

## Related Documentation

- [Installation Guide](INSTALLATION.md) - Setup and PATH configuration
- [CLI Usage](CLI_USAGE.md) - Command-line options and examples
- [CLI Fallback for LLMs](CLI_FALLBACK_FOR_LLMS.md) - Using CLI when MCP isn't available
- [MCP Integration](MCP_INTEGRATION.md) - MCP server configuration
- [Error Handling](ERROR_HANDLING.md) - Understanding error modes
