# Troubleshooting Guide

Common issues and solutions for simplecov-mcp.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Coverage Data Issues](#coverage-data-issues)
- [CLI Issues](#cli-issues)
- [MCP Server Issues](#mcp-server-issues)
- [Performance Issues](#performance-issues)
- [Environment-Specific Issues](#environment-specific-issues)
- [Getting Help](#getting-help)

## Installation Issues

### "command not found: simplecov-mcp"

**Symptom:** Shell reports command not found after installation

**Solutions:**

1. **Verify gem is installed:**
   ```sh
   gem list simplecov-mcp
   ```
   If not listed, install it:
   ```sh
   gem install simplecov-mcp
   ```

2. **Check gem bin directory is in PATH:**
   ```sh
   # Find gem bin directory
   gem env | grep "EXECUTABLE DIRECTORY"

   # Add to PATH if needed (add to ~/.bashrc or ~/.zshrc)
   export PATH="$(ruby -e 'puts Gem.bindir'):$PATH"

   # Reload shell
   source ~/.zshrc
   ```

3. **Use bundle exec if in a project:**
   ```sh
   bundle exec simplecov-mcp
   ```

4. **Rehash version manager:**
   ```sh
   # rbenv
   rbenv rehash

   # asdf
   asdf reshim ruby
   ```

### "cannot load such file -- mcp"

**Symptom:** Error loading MCP gem dependency

**Cause:** Ruby version < 3.2

**Solutions:**

1. **Check Ruby version:**
   ```sh
   ruby -v
   ```

2. **Upgrade to Ruby 3.2 or higher:**
   ```sh
   # With rbenv
   rbenv install 3.3.8
   rbenv global 3.3.8

   # With RVM
   rvm install 3.3.8
   rvm use 3.3.8 --default

   # With asdf
   asdf install ruby 3.3.8
   asdf global ruby 3.3.8
   ```

3. **Reinstall gem:**
   ```sh
   gem install simplecov-mcp
   ```

### Ruby Version Compatibility

**Symptom:** Various errors related to gem dependencies

**Requirements:**
- Ruby >= 3.2 (hard requirement due to `mcp` gem)

**Check Ruby version in different contexts:**
```sh
# Interactive shell
ruby -v

# Via version manager
rbenv version  # or rvm current, asdf current ruby

# In MCP server context (test full path)
/full/path/to/ruby -v
```

### PATH Configuration Issues

**Symptom:** Works in one terminal but not another

**Diagnosis:**
```sh
# Check current PATH
echo $PATH

# Check where gem installs bins
gem env gemdir
ruby -e 'puts Gem.bindir'

# Verify simplecov-mcp location
which simplecov-mcp
```

**Solutions:**

1. **Add gem bin to PATH permanently:**
   ```sh
   # Add to ~/.bashrc, ~/.zshrc, etc.
   export PATH="$(ruby -e 'puts Gem.bindir'):$PATH"
   ```

2. **For version managers:**
   ```sh
   # rbenv users: ensure this is in shell config
   eval "$(rbenv init -)"

   # RVM users
   source ~/.rvm/scripts/rvm

   # asdf users
   . "$HOME/.asdf/asdf.sh"
   ```

## Coverage Data Issues

### Missing .resultset.json File

**Symptom:** "Could not find .resultset.json" error

**Solutions:**

1. **Generate coverage data:**
   ```sh
   # Run your test suite
   bundle exec rspec  # or your test command

   # Verify file was created
   ls coverage/.resultset.json
   ```

2. **Check SimpleCov configuration:**
   ```ruby
   # spec/spec_helper.rb or test/test_helper.rb
   require 'simplecov'
   SimpleCov.start
   ```

3. **Specify custom location:**
   ```sh
   # If coverage is elsewhere
   simplecov-mcp --resultset path/to/.resultset.json

   # Or set environment variable
   export SIMPLECOV_RESULTSET=path/to/coverage
   ```

4. **Search order:**
   simplecov-mcp looks for `.resultset.json` in:
   - `.resultset.json` (project root)
   - `coverage/.resultset.json`
   - `tmp/.resultset.json`

### Stale Coverage Data

**Symptom:** "Coverage data appears stale" warning or error

**Causes:**
- Source file modified after coverage was generated
- Source file line count differs from coverage data
- New files added that aren't in coverage

**Solutions:**

1. **Regenerate coverage (recommended):**
   ```sh
   bundle exec rspec
   ```

2. **Disable staleness checking:**
   ```sh
   simplecov-mcp --stale off  # This is the default
   ```

3. **Understand what's stale:**
   ```sh
   # See which files are stale (marked with !)
   simplecov-mcp list

   # Get detailed stale error info
   simplecov-mcp --stale error
   ```

4. **For CI/CD:**
   ```sh
   # Always generate fresh coverage
   bundle exec rspec
   simplecov-mcp --stale error  # Now it should pass
   ```

### File Not Found in Coverage

**Symptom:** "No coverage data found for file: path/to/file.rb"

**Causes:**
- File not executed by tests
- File path mismatch
- File excluded by SimpleCov configuration

**Solutions:**

1. **Check file path:**
   ```sh
   # Use project-relative path
   simplecov-mcp summary lib/simple_cov_mcp/model.rb

   # Or absolute path
   simplecov-mcp summary /full/path/to/lib/simple_cov_mcp/model.rb
   ```

2. **Verify file is in coverage:**
   ```sh
   simplecov-mcp list | grep model.rb
   ```

3. **Check SimpleCov filters:**
   ```ruby
   # In your SimpleCov configuration
   SimpleCov.start do
     # Files might be filtered out
     add_filter '/test/'
     add_filter '/spec/'
     add_filter '/vendor/'
   end
   ```

4. **Ensure file is loaded by tests:**
   - File must be required/loaded during test execution
   - Add tests that exercise the file

### Invalid Coverage Format

**Symptom:** "Invalid coverage data format" or JSON parsing errors

**Solutions:**

1. **Verify .resultset.json is valid JSON:**
   ```sh
   ruby -rjson -e "JSON.parse(File.read('coverage/.resultset.json'))"
   ```

2. **Regenerate coverage:**
   ```sh
   rm coverage/.resultset.json
   bundle exec rspec
   ```

3. **Check disk space:**
   ```sh
   df -h .
   ```
   Full disk can cause truncated JSON files.

## CLI Issues

### Option Parsing Errors

**Symptom:** "invalid option" or "invalid argument" errors

**Solutions:**

1. **Check option format:**
   ```sh
   # Correct
   simplecov-mcp --sort-order ascending
   simplecov-mcp -o a

   # Wrong
   simplecov-mcp --sort-order asc  # Must be 'ascending' or 'a'
   ```

2. **Use quotes for paths with spaces:**
   ```sh
   simplecov-mcp --resultset "path with spaces/coverage"
   ```

3. **Check subcommand vs. option order:**
   ```sh
   # Correct: global options before subcommand
   simplecov-mcp --json summary lib/simple_cov_mcp/model.rb

   # Also correct: global options after subcommand
   simplecov-mcp summary lib/simple_cov_mcp/model.rb --json
   ```

4. **Get help:**
   ```sh
   simplecov-mcp --help
   ```

### Unexpected Output Format

**Symptom:** JSON when expecting table, or vice versa

**Solutions:**

1. **Check --json flag:**
   ```sh
   # For JSON
   simplecov-mcp list --json

   # For table (default)
   simplecov-mcp list
   ```

2. **Check SIMPLECOV_MCP_OPTS:**
   ```sh
   echo $SIMPLECOV_MCP_OPTS

   # Temporarily unset
   unset SIMPLECOV_MCP_OPTS
   simplecov-mcp list
   ```

### Color Output Issues

**Symptom:** ANSI codes in logs or no colors in terminal

**Solutions:**

1. **Explicitly enable colors:**
   ```sh
   simplecov-mcp uncovered lib/simple_cov_mcp/model.rb --source --color
   ```

2. **Disable for logging:**
   ```sh
   simplecov-mcp uncovered lib/simple_cov_mcp/model.rb --source --no-color > log.txt
   ```

3. **Auto-detection:**
   Colors are auto-enabled when output is a TTY:
   ```sh
   # Has colors
   simplecov-mcp uncovered lib/simple_cov_mcp/model.rb --source

   # No colors (piped)
   simplecov-mcp uncovered lib/simple_cov_mcp/model.rb --source | less
   ```

## MCP Server Issues

### Connection Problems

**Symptom:** AI assistant can't connect to MCP server

**Diagnostics:**

1. **Test manually:**
   ```sh
   # Should return version
   simplecov-mcp version

   # Test MCP mode
   echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"version_tool","arguments":{}}}' | simplecov-mcp
   ```

2. **Check executable path:**
   ```sh
   which simplecov-mcp
   ls -l $(which simplecov-mcp)
   ```

3. **Check Ruby version:**
   ```sh
   ruby -v  # Must be >= 3.2
   ```

4. **Review logs:**
   ```sh
   tail -f ~/simplecov_mcp.log
   ```

**Solutions:**

1. **Use absolute path in MCP config:**
   ```json
   {
     "command": "/Users/yourname/.rbenv/shims/simplecov-mcp"
   }
   ```

2. **For RVM, use wrapper:**
   ```sh
   rvm wrapper ruby-3.3.8 simplecov-mcp simplecov-mcp
   # Use: ~/.rvm/wrappers/ruby-3.3.8/simplecov-mcp
   ```

3. **Restart AI assistant** after config changes

### JSON-RPC Parse Errors

**Symptom:** "Invalid JSON-RPC" or parse errors

**Cause:** Multi-line JSON (MCP requires single-line)

**Solutions:**

1. **Use single-line JSON:**
   ```sh
   # Wrong (multi-line)
   echo '{
     "jsonrpc": "2.0"
   }' | simplecov-mcp

   # Correct (single line)
   echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"version_tool","arguments":{}}}' | simplecov-mcp
   ```

2. **Use jq to minify:**
   ```sh
   cat request.json | jq -c . | simplecov-mcp
   ```

### MCP Tool Errors

**Symptom:** MCP tools return error responses

**Common issues:**

1. **Missing required parameters:**
   ```json
   {
     "name": "coverage_summary_tool",
     "arguments": {
       "path": "lib/simple_cov_mcp/model.rb"  // Required!
     }
   }
   ```

2. **Wrong parameter types:**
   ```json
   {
     "name": "all_files_coverage_tool",
     "arguments": {
       "tracked_globs": ["lib/simple_cov_mcp/**/*.rb"]  // Array, not string
     }
   }
   ```

3. **File paths:**
   - Use project-relative paths
   - Or absolute paths
   - Avoid shell expansions (~, *, etc.)

**Debugging:**

1. **Check tool parameters:**
   ```sh
   echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"help_tool","arguments":{}}}' | simplecov-mcp
   ```

2. **Enable debug logging:**
   ```sh
   simplecov-mcp --error-mode on_with_trace
   ```

3. **Check logs:**
   ```sh
   tail -f ~/simplecov_mcp.log
   ```

### Tools Not Appearing

**Symptom:** AI assistant doesn't see simplecov-mcp tools

**Solutions:**

1. **Verify MCP server config:**
   ```sh
   # Claude
   claude mcp list

   # Codex
   cat ~/.codex/config.toml | grep simplecov
   ```

2. **Restart AI assistant:**
   Many require restart after config changes

3. **Check server is running:**
   Look for MCP server status in AI assistant

4. **Test manually:**
   ```sh
   echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | simplecov-mcp
   ```

## Performance Issues

### Slow Coverage Analysis

**Symptoms:** Commands take a long time to complete

**Causes:**
- Very large .resultset.json files
- Many files in project
- Slow file system (network drives)

**Solutions:**

1. **Use specific file queries:**
   ```sh
   # Faster: query specific file
   simplecov-mcp summary lib/simple_cov_mcp/model.rb

   # Slower: list all files
   simplecov-mcp list
   ```

2. **Filter with tracked-globs:**
   ```sh
   # Only analyze lib/simple_cov_mcp/
   simplecov-mcp list --tracked-globs "lib/simple_cov_mcp/**/*.rb"
   ```

3. **Check resultset size:**
   ```sh
   ls -lh coverage/.resultset.json

   # If > 10MB, consider splitting test suite
   ```

4. **Use local storage:**
   - Avoid network/NFS drives for coverage data
   - Use local disk or ramdisk

### Memory Usage

**Symptom:** High memory usage or out-of-memory errors

**Solutions:**

1. **Large resultsets:**
   - simplecov-mcp loads entire resultset into memory
   - For very large projects (1000+ files), consider splitting

2. **Use streaming for exports:**
   ```sh
   # Stream JSON to file instead of holding in memory
   simplecov-mcp list --json > coverage.json
   ```

## Environment-Specific Issues

### Docker/Container Issues

**Symptom:** Can't find files or coverage in containers

**Solutions:**

1. **Mount project directory:**
   ```dockerfile
   FROM ruby:3.3
   WORKDIR /app
   COPY . /app
   RUN gem install simplecov-mcp
   CMD ["simplecov-mcp"]
   ```

2. **Run with volume mount:**
   ```sh
   docker run -v $(pwd):/app -w /app ruby:3.3 sh -c "gem install simplecov-mcp && simplecov-mcp"
   ```

3. **Set correct working directory:**
   ```sh
   docker run -v $(pwd):/app ruby:3.3 simplecov-mcp --root /app
   ```

### CI/CD Issues

**Symptom:** Works locally but fails in CI

**Solutions:**

1. **Check Ruby version in CI:**
   ```yaml
   # GitHub Actions
   - uses: ruby/setup-ruby@v1
     with:
       ruby-version: 3.3
   ```

2. **Ensure coverage is generated:**
   ```yaml
   - run: bundle exec rspec  # Generate coverage first
   - run: bundle exec simplecov-mcp --stale error
   ```

3. **Use absolute paths:**
   ```yaml
   - run: SIMPLECOV_RESULTSET=$PWD/coverage simplecov-mcp
   ```

4. **Check permissions:**
   ```sh
   ls -la coverage/.resultset.json
   chmod 644 coverage/.resultset.json
   ```

### Network Drive Issues

**Symptom:** Slow or intermittent failures on network drives

**Solutions:**

1. **Copy coverage to local disk:**
   ```sh
   cp /network/path/coverage/.resultset.json /tmp/
   simplecov-mcp --resultset /tmp/.resultset.json
   ```

2. **Use SSH/rsync instead of NFS:**
   ```sh
   rsync -avz server:/path/to/coverage/ ./coverage/
   simplecov-mcp
   ```

### Windows Issues

**Symptom:** Path-related errors on Windows

**Solutions:**

1. **Use forward slashes:**
   ```sh
   simplecov-mcp --resultset coverage/.resultset.json
   ```

2. **Use WSL (Windows Subsystem for Linux):**
   ```sh
   wsl gem install simplecov-mcp
   wsl simplecov-mcp
   ```

## Getting Help

### Enable Debug Mode

```sh
# Environment variable
export SIMPLECOV_MCP_DEBUG=1
simplecov-mcp

# Or via flag
simplecov-mcp --error-mode on_with_trace
```

### Check Logs

```sh
# View log file
cat ~/simplecov_mcp.log

# Watch in real-time
tail -f ~/simplecov_mcp.log

# Search for errors
grep -i error ~/simplecov_mcp.log
```

### Gather Diagnostic Info

When reporting issues, include:

1. **Version info:**
   ```sh
   simplecov-mcp version
   ruby -v
   gem list simplecov-mcp
   ```

2. **Environment:**
   ```sh
   echo $PATH
   which simplecov-mcp
   gem env
   ```

3. **Test command:**
   ```sh
   simplecov-mcp --error-mode on_with_trace list
   ```

4. **Minimal reproduction:**
   - Simplest command that fails
   - Sample .resultset.json if possible
   - Full error message

### Report Issues

If you've tried the solutions above and still have issues:

1. **Check existing issues:**
   https://github.com/keithrbennett/simplecov-mcp/issues

2. **Create new issue with:**
   - Diagnostic info (above)
   - Steps to reproduce
   - Expected vs. actual behavior
   - Relevant log excerpts

### Community Help

- **GitHub Discussions:** For questions and discussions
- **GitHub Issues:** For bugs and feature requests

## Quick Diagnostic Checklist

Before reporting an issue, try:

- [ ] Ruby version >= 3.2? (`ruby -v`)
- [ ] Gem installed? (`gem list simplecov-mcp`)
- [ ] Executable in PATH? (`which simplecov-mcp`)
- [ ] Coverage file exists? (`ls coverage/.resultset.json`)
- [ ] Can run manually? (`simplecov-mcp version`)
- [ ] Checked logs? (`tail ~/simplecov_mcp.log`)
- [ ] Tried debug mode? (`simplecov-mcp --error-mode trace`)
- [ ] Regenerated coverage? (`bundle exec rspec`)

## Next Steps

- **[CLI Usage](CLI_USAGE.md)** - Complete CLI reference
- **[MCP Integration](MCP_INTEGRATION.md)** - MCP server setup
- **[Installation](INSTALLATION.md)** - Installation guide
