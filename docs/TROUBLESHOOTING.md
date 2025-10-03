# Troubleshooting

Quick answers for the few issues that matter most when using or developing `simplecov-mcp`.

## Running the Test Suite with RVM (Codex macOS)

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

## Missing `coverage/.resultset.json`

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

## Stale Coverage Errors

`--stale error` (or `staleness: 'error'`) compares file mtimes and line counts to the coverage snapshot. When it fails:

- Regenerate coverage (`bundle exec rspec`) so the snapshot matches current sources.
- Or drop back to warning-only behaviour using `--stale off` / `staleness: 'off'`.

If you only care about a subset of files, supply `--tracked-globs` (CLI) or `tracked_globs:` (API) so new files outside those globs do not trigger staleness.

## "No coverage data found for file"

The model looks up files by absolute path, then cwd-relative path, then basename. If you still hit this error:

1. Verify the file is listed in the coverage table (`simplecov-mcp list | grep model.rb`).
2. Use the exact project-relative path that SimpleCov recorded (case-sensitive, no symlinks).
3. If the file truly never executes under tests, add coverage or exclude it from your workflow.

## MCP Tool Errors

Most CLI/MCP errors share the same causes as above. Two quick checks before digging deeper:

1. **Path arguments** must be relative to the project root unless you pass an absolute path.
2. **`--resultset` / `resultset:`** should point to either the `.resultset.json` file or a directory containing it.

If those are correct, re-run with to see the full stack trace.
