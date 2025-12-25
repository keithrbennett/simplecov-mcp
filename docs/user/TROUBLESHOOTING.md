# Troubleshooting Guide

[Back to main README](../index.md)

## Table of Contents

- [Running Issues](#running-issues)
- [Coverage Data Issues](#coverage-data-issues)
- [MCP Server Issues](#mcp-server-issues)
- [Diagnostic Commands](#diagnostic-commands)

## Running Issues

### Running the Test Suite with RVM (Codex macOS)

Codex's macOS sandbox forbids `/bin/ps`; RVM shells need it. When you run `bundle exec rspec` there, the shell falls back to macOS Ruby 2.6 and Bundler dies with `Gem::Resolver::APISet::GemParser` errors.

**Workarounds:**

- Run outside the macOS sandbox (Codex on Ubuntu, Gemini, Claude Code, local shells) or use a version manager that does not invoke `ps`.
- Or execute RSpec with explicit RVM paths:
  ```bash
  PATH="$HOME/.rvm/gems/ruby-3.4.5@cov-loupe/bin:$HOME/.rvm/rubies/ruby-3.4.5/bin:$PATH" \
    GEM_HOME="$HOME/.rvm/gems/ruby-3.4.5@cov-loupe" \
    GEM_PATH="$HOME/.rvm/gems/ruby-3.4.5@cov-loupe:$HOME/.rvm/gems/ruby-3.4.5@global" \
    $HOME/.rvm/rubies/ruby-3.4.5/bin/bundle exec rspec
  ```
- Use a different AI coding agent and/or operating system.

## Coverage Data Issues

### Missing `coverage/.resultset.json`

`cov-loupe` only reads coverage data; it never generates it. If you see "Could not find .resultset.json":

1. Run the test suite with SimpleCov enabled (default project setup already enables it).
   ```bash
   bundle exec rspec
   ls coverage/.resultset.json
   ```
2. If your coverage lives elsewhere, point the tools at it:
   ```bash
   cov-loupe -r build/coverage/.resultset.json  # -r = --resultset
   # or
   export COV_LOUPE_OPTS="-r build/coverage"
   ```

### Stale Coverage Errors

`--raise-on-stale` (or `-S`, or `raise_on_stale: true`) compares file mtimes and line counts to the coverage snapshot and raises if stale. When it fails:

- Regenerate coverage (`bundle exec rspec`) so the snapshot matches current sources.
- Or drop back to warning-only behaviour using `--no-raise-on-stale` / `raise_on_stale: false`.

If you only care about a subset of files, supply `-g` / `--tracked-globs` (CLI) or `tracked_globs:` (API) so new files outside those globs do not trigger staleness.

### "No coverage data found for file"

The model looks up files by absolute path, then cwd-relative path, then basename. If you still hit this error:

1. Verify the file is listed in the coverage table (`cov-loupe list | grep model.rb`).
2. Use the exact project-relative path that SimpleCov recorded (case-sensitive, no symlinks).
3. If the file truly never executes under tests, add coverage or exclude it from your workflow.

## MCP Server Issues

### MCP Integration Not Working

**Symptoms:**
- AI assistant reports "Could not connect to MCP server"
- AI says "I don't have access to cov-loupe tools"

**Diagnostic steps:**

1. **Verify executable exists and works:**
   ```bash
   which cov-loupe
   cov-loupe version
   ```

2. **Test MCP server mode manually:**
   ```bash
   echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"version_tool","arguments":{}}}' | cov-loupe
   ```
   Should return JSON-RPC response.

3. **Verify MCP server is configured:**
   ```bash
   claude mcp list  # For Claude Code
   codex mcp list   # For Codex
   gemini mcp list  # For Gemini
   tail -f cov_loupe.log  # Check logs
   ```

4. **Restart AI assistant** - Config changes often require restart

5. **Use absolute path in MCP config:**
   ```bash
   # Find absolute path
   which cov-loupe

   # Update your MCP client config to use this path
   ```

6. **Use CLI as fallback:**

   If MCP still isn't working, you can use the CLI with `-fJ` flag instead.
   See **[CLI Fallback for LLMs](CLI_FALLBACK_FOR_LLMS.md)** for complete guidance.

7. **Check for Codex environment variable issues:**
   If you are using Codex and the server fails to start due to missing gems, you need to manually add 
   `env_vars = ["GEM_HOME", "GEM_PATH"]` to your `~/.codex/config.toml`. 
   See the [MCP Integration - Codex section](MCP_INTEGRATION.md#codex) for complete setup instructions.

### Path Issues with Version Managers

**Symptom:** `cov-loupe` works in terminal but not in MCP client.

**Cause:** MCP client doesn't have your shell environment (PATH, RVM, etc.).

**Solution:** Use absolute paths in MCP configuration:

```bash
# For rbenv/asdf - get the full absolute path
which cov-loupe
# Example output: /home/username/.rbenv/shims/cov-loupe
# Use this exact path in your MCP config

# For RVM you may need to create a wrapper and specify its absolute path
# (Replace ruby-3.3.8 with your rvm Ruby label) 
rvm wrapper ruby-3.3.8 cov-loupe cov-loupe

# Get the full path (expands ~ to your home directory)
realpath ~/.rvm/wrappers/ruby-3.3.8/cov-loupe
# Example output: /home/username/.rvm/wrappers/ruby-3.3.8/cov-loupe

# Use the FULL path in MCP config (NOT the ~ version):
# Good: /home/username/.rvm/wrappers/ruby-3.3.8/cov-loupe
# Bad:  ~/.rvm/wrappers/ruby-3.3.8/cov-loupe  (~ may not expand)
```

## Diagnostic Commands

Before reporting an issue, run these diagnostic commands and include the output:

```bash
# System info
ruby -v
gem -v
bundle -v

# cov-loupe info
gem list cov-loupe
which cov-loupe
cov-loupe version

# Test basic functionality
cov-loupe --help
cov-loupe list 2>&1

# Check coverage data
ls -la coverage/.resultset.json
head -20 coverage/.resultset.json

# Test MCP mode
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"version_tool","arguments":{}}}' | cov-loupe 2>&1
```

## Getting More Help

If the above doesn't solve your problem:

1. **Check error mode** - Run with `--error-mode debug` for full stack traces:
   ```bash
   cov-loupe --error-mode debug summary lib/cov_loupe/cli.rb
   ```

2. **Check logs:**
   ```bash
   # MCP server logs
   tail -50 cov_loupe.log

   # Or specify custom log location (--log-file or -l)
   cov-loupe -l /tmp/debug.log summary lib/cov_loupe/cli.rb
   ```

3. **Search existing issues:**
   https://github.com/keithrbennett/cov-loupe/issues

4. **Report a bug:**
   Include output from [Diagnostic Commands](#diagnostic-commands) above

## Related Documentation

- [Installation Guide](INSTALLATION.md) - Setup and PATH configuration
- [CLI Usage](CLI_USAGE.md) - Command-line options and examples
- [CLI Fallback for LLMs](CLI_FALLBACK_FOR_LLMS.md) - Using CLI when MCP isn't available
- [MCP Integration](MCP_INTEGRATION.md) - MCP server configuration
- [Error Handling](ERROR_HANDLING.md) - Understanding error modes
