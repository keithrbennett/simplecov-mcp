# Version 2.0 Breaking Changes - Implementation Guide

This document provides step-by-step prompts for implementing the breaking changes planned for v2.0. Each task includes a detailed prompt that can be given to a coding assistant.

---

## Phase 1: Core Consistency (High Impact)

### Task 1.1: Rename `stale_mode` → `staleness` in AppConfig

**Estimated Time:** 15 minutes

**Prompt:**

```
I need to rename the `stale_mode` attribute to `staleness` throughout the codebase for consistency.

Current state:
- AppConfig uses `stale_mode` (lib/simplecov_mcp/app_config.rb)
- CoverageModel uses `staleness` parameter
- MCP tools use `stale` parameter

Changes needed:
1. In lib/simplecov_mcp/app_config.rb:
   - Rename the struct attribute from `:stale_mode` to `:staleness`
   - Update the `initialize` default parameter from `stale_mode:` to `staleness:`
   - Update the `model_options` method to use `staleness: staleness` instead of `staleness: stale_mode`

2. Search the entire codebase for references to `stale_mode` and update them to `staleness`:
   - lib/simplecov_mcp/cli.rb - Update all references to `config.stale_mode`
   - lib/simplecov_mcp/option_parser_builder.rb - Update the option handler
   - lib/simplecov_mcp/commands/ - Check all command files
   - Any test files that reference `stale_mode`

3. Run the test suite to ensure nothing broke:
   bundle exec rspec

4. Verify all tests pass before proceeding.

Please make these changes, ensuring that every reference to `stale_mode` is changed to `staleness`, and confirm all tests pass.
```

---

### Task 1.2: Rename CLI option `--stale` → `--staleness`

**Estimated Time:** 10 minutes

**Prompt:**

```
I need to rename the CLI option from `--stale` to `--staleness` for clarity and consistency.

Changes needed:

1. In lib/simplecov_mcp/option_parser_builder.rb (around line 77):
   - Change: o.on('-S', '--stale MODE', String, 'Staleness mode: o[ff]|e[rror] (default off)')
   - To: o.on('--staleness MODE', String, 'Staleness detection: off|error (default off)')
   - Remove the '-S' short form for clarity

2. In lib/simplecov_mcp/constants.rb (around line 15):
   - Change: '-S --stale'
   - To: '--staleness'
   - Remove the '-S' entry

3. Update any help text or examples that reference `--stale`:
   - lib/simplecov_mcp/option_parser_builder.rb - Check the examples section
   - README.md - Search for `--stale` and update to `--staleness`
   - docs/user/CLI_USAGE.md - Update option documentation

4. Update RELEASE_NOTES.md to document this breaking change:
   - Add to the v2.0 section: "BREAKING: `--stale` option renamed to `--staleness`"

5. Run tests to verify:
   bundle exec rspec

Please make these changes and confirm that the CLI accepts `--staleness` but no longer accepts `--stale` or `-S`.
```

---

### Task 1.3: Convert `staleness` parameter to use symbols throughout

**Estimated Time:** 30 minutes

**Prompt:**

```
I need to standardize on using symbols (`:off`, `:error`) instead of strings ('off', 'error') for the staleness parameter throughout the codebase.

Current state:
- AppConfig stores symbols
- CoverageModel expects strings
- This causes unnecessary conversions

Target state:
- Everything uses symbols
- Only convert from strings at the CLI parsing boundary

Changes needed:

1. In lib/simplecov_mcp/model.rb (line 28):
   - Change: def initialize(root: '.', resultset: nil, staleness: 'off', tracked_globs: nil)
   - To: def initialize(root: '.', resultset: nil, staleness: :off, tracked_globs: nil)
   - Update any string comparisons in this file from 'off'/'error' to :off/:error

2. In lib/simplecov_mcp/staleness_checker.rb:
   - Find the initialization and any mode comparisons
   - Change string literals 'off' and 'error' to symbols :off and :error
   - Update the `off?` method and similar to use symbol comparison

3. In lib/simplecov_mcp/option_normalizers.rb:
   - The normalize_stale_mode method already returns symbols - verify this is correct
   - Ensure it returns :off and :error (symbols)

4. In all MCP tools (lib/simplecov_mcp/tools/*.rb):
   - Update tool call signatures to use staleness: :off as default
   - Currently they use stale: 'off' - we'll fix the parameter name in a later task

5. Update all test files:
   - Search for staleness: 'off' and staleness: 'error'
   - Change to staleness: :off and staleness: :error
   - Check spec/app_config_spec.rb, spec/model_staleness_spec.rb, etc.

6. Run the full test suite:
   bundle exec rspec

7. Fix any failures related to string vs symbol comparisons.

Please make these changes systematically, ensuring that symbols are used everywhere except at the CLI parsing boundary where we convert user input strings to symbols.
```

---

### Task 1.4: Rename error mode `:on` → `:log`

**Estimated Time:** 25 minutes

**Prompt:**

```
I need to rename the error mode value `:on` to `:log` for better clarity about what it does (enables error logging).

Current values: :off, :on, :trace
Target values: :off, :log, :debug (renaming :trace to :debug as well for consistency)

Changes needed:

1. In lib/simplecov_mcp/option_normalizers.rb:
   - Update ERROR_MODE_MAP (around line 28-33):
     'off' => :off,
     'log' => :log,      # was 'on' => :on
     'debug' => :debug,  # was 'trace' => :trace
     'trace' => :debug   # Keep as alias for backward compatibility
   - Update the normalize_error_mode method documentation

2. In lib/simplecov_mcp/app_config.rb:
   - Change default from error_mode: :on to error_mode: :log (around line 31)

3. In lib/simplecov_mcp/option_parser_builder.rb (around line 89-91):
   - Update help text: 'Error handling mode: off|log|debug (default log)'
   - Update description to clarify what each mode does:
     "off (silent), log (log errors to file), debug (verbose with backtraces)"

4. Search the entire codebase for comparisons to :on and :trace:
   - Find: error_mode == :on or error_mode == :trace
   - Replace with: error_mode == :log and error_mode == :debug
   - Check lib/simplecov_mcp/error_handler.rb
   - Check lib/simplecov_mcp/cli.rb
   - Check all test files

5. Update tests:
   - spec/cli_enumerated_options_spec.rb - Update error mode tests
   - spec/option_normalizers_spec.rb - Update expectations
   - Any other files testing error modes

6. Update documentation:
   - README.md - Search for error-mode references
   - docs/user/ERROR_HANDLING.md - Update mode descriptions
   - docs/user/CLI_USAGE.md - Update option documentation

7. Update RELEASE_NOTES.md:
   - Add: "BREAKING: Error mode 'on' renamed to 'log', 'trace' renamed to 'debug'"

8. Run tests:
   bundle exec rspec

Please make these changes and ensure all tests pass. The key is that :on becomes :log and :trace becomes :debug throughout.
```

---

### Task 1.5: Unify MCP tool parameter names with CoverageModel API

**Estimated Time:** 30 minutes

**Prompt:**

```
I need to rename the MCP tool parameter from `stale` to `staleness` to match the CoverageModel API, eliminating the translation layer.

Current state:
- BaseTool INPUT_SCHEMA uses `stale:` parameter
- All tools accept `stale:` and rename it when calling CoverageModel
- CoverageModel expects `staleness:`

Target state:
- BaseTool INPUT_SCHEMA uses `staleness:` parameter
- All tools accept `staleness:` and pass it directly to CoverageModel
- No renaming needed

Changes needed:

1. In lib/simplecov_mcp/base_tool.rb (around line 29):
   - Change the INPUT_SCHEMA property from `stale:` to `staleness:`
   - Update the description to match
   - Change enum to use symbols: enum: [:off, :error] (or keep as strings if required by MCP protocol)
   - Update the default value

2. Update all tool files in lib/simplecov_mcp/tools/:

   For each of these files:
   - all_files_coverage_tool.rb
   - coverage_detailed_tool.rb
   - coverage_raw_tool.rb
   - coverage_summary_tool.rb
   - coverage_table_tool.rb
   - coverage_totals_tool.rb
   - uncovered_lines_tool.rb

   Make these changes:
   a. Change method signature from `stale: 'off'` to `staleness: :off`
   b. Remove any parameter renaming (stale → staleness conversions)
   c. Pass staleness directly to CoverageModel.new(staleness: staleness)

   Example transformation:
   Before:
   ```ruby
   def call(path:, root: '.', resultset: nil, stale: 'off', error_mode: 'on', server_context:)
     model = CoverageModel.new(root: root, resultset: resultset, staleness: stale)
   ```

   After:
   ```ruby
   def call(path:, root: '.', resultset: nil, staleness: :off, error_mode: :log, server_context:)
     model = CoverageModel.new(root: root, resultset: resultset, staleness: staleness)
   ```

3. Update version_tool.rb and help_tool.rb if they reference the parameter.

4. Update test files:
   - spec/*_tool_spec.rb files - Update any tests that call tools with `stale:` parameter
   - Change to use `staleness:` instead

5. Update MCP documentation:
   - docs/user/MCP_INTEGRATION.md - Update tool parameter examples
   - CLAUDE.md - Update the MCP tools section

6. Run tests:
   bundle exec rspec spec/*_tool_spec.rb
   bundle exec rspec

Please make these changes systematically, ensuring that all tools now use `staleness` consistently.
```

---

### Task 1.6: Update all tests for Phase 1 changes

**Estimated Time:** 20 minutes

**Prompt:**

```
I need to comprehensively update all test files to reflect the Phase 1 breaking changes:
- stale_mode → staleness
- --stale → --staleness
- Strings → symbols for enum values
- :on → :log, :trace → :debug
- MCP tool parameter stale → staleness

Changes needed:

1. Run the test suite and identify all failures:
   bundle exec rspec

2. For each failing test, update it to use the new naming:
   - Replace `stale_mode:` with `staleness:`
   - Replace string values 'off', 'error', 'on', 'trace' with symbols :off, :error, :log, :debug
   - Replace `stale:` parameter in tool tests with `staleness:`

3. Check these specific test files that are likely to need updates:
   - spec/app_config_spec.rb - AppConfig initialization tests
   - spec/cli_enumerated_options_spec.rb - CLI option parsing tests
   - spec/option_normalizers_spec.rb - Normalization tests
   - spec/model_staleness_spec.rb - CoverageModel staleness tests
   - spec/staleness_more_spec.rb - Additional staleness tests
   - spec/*_tool_spec.rb - All MCP tool tests
   - spec/commands/*_spec.rb - Command tests
   - spec/cli/show_default_report_spec.rb - CLI output tests

4. Update test fixtures if any:
   - Check spec/fixtures/ for any configuration files
   - Update any example code in test descriptions

5. Run the full test suite until all tests pass:
   bundle exec rspec

6. Verify coverage hasn't decreased:
   - Check that all code paths are still tested
   - Look at coverage/.resultset.json or run with coverage report

Please go through all test files systematically, update them for the new naming conventions, and ensure all tests pass.
```

---

### Task 1.7: Update documentation for Phase 1 changes

**Estimated Time:** 25 minutes

**Prompt:**

```
I need to update all documentation to reflect the Phase 1 breaking changes for v2.0.

Changes to document:
- stale_mode → staleness
- --stale → --staleness (no short form -S)
- Error modes: on → log, trace → debug
- MCP tool parameter: stale → staleness
- All enum values are now symbols internally

Files to update:

1. README.md:
   - Search for `--stale` and replace with `--staleness`
   - Search for `--error-mode` references and update values
   - Update any code examples
   - Update the "Common Workflows" section if it mentions these options

2. docs/user/CLI_USAGE.md:
   - Update the full options reference section
   - Update all examples using `--stale` to use `--staleness`
   - Document that -S short form no longer exists
   - Update error mode documentation (off|log|debug)
   - Add migration notes for users upgrading from v1.x

3. docs/user/ADVANCED_USAGE.md:
   - Update staleness detection section
   - Update error handling section
   - Update any code examples

4. docs/user/ERROR_HANDLING.md:
   - Update error mode descriptions:
     - :off - No error logging
     - :log - Log errors to file/stderr (was :on)
     - :debug - Verbose logging with backtraces (was :trace)
   - Update all examples

5. docs/user/MCP_INTEGRATION.md:
   - Update MCP tool parameter documentation
   - Change all `stale:` examples to `staleness:`
   - Update the "Available MCP Tools" section

6. CLAUDE.md:
   - Update the MCP tools section
   - Update prompt examples to use new parameter names
   - Update any CLI examples

7. docs/user/EXAMPLES.md:
   - Update all CLI examples using old option names
   - Verify all examples still work

8. RELEASE_NOTES.md:
   - Add comprehensive v2.0.0 breaking changes section:
     ```markdown
     ## v2.0.0 - BREAKING CHANGES

     ### Parameter Naming Consistency
     - **BREAKING:** `stale_mode` renamed to `staleness` throughout API
     - **BREAKING:** CLI option `--stale` renamed to `--staleness` (short form `-S` removed)
     - **BREAKING:** MCP tool parameter `stale` renamed to `staleness`

     ### Error Mode Values
     - **BREAKING:** Error mode `on` renamed to `log`
     - **BREAKING:** Error mode `trace` renamed to `debug` (alias `trace` kept for compatibility)

     ### Internal Type Changes
     - All enumerated values (staleness, error_mode, sort_order) now use symbols internally
     - This improves performance and type safety but may affect library users doing string comparisons

     ### Migration Guide

     **CLI users:**
     - Change `--stale error` to `--staleness error`
     - Change `--error-mode on` to `--error-mode log`
     - Change `--error-mode trace` to `--error-mode debug`

     **Library users:**
     ```ruby
     # Old (v1.x)
     model = SimpleCovMcp::CoverageModel.new(staleness: 'error')
     config = SimpleCovMcp::AppConfig.new(stale_mode: :off, error_mode: :on)

     # New (v2.0)
     model = SimpleCovMcp::CoverageModel.new(staleness: :error)
     config = SimpleCovMcp::AppConfig.new(staleness: :off, error_mode: :log)
     ```

     **MCP tool users:**
     ```json
     // Old
     {"name": "coverage_summary_tool", "arguments": {"path": "lib/foo.rb", "stale": "error"}}

     // New
     {"name": "coverage_summary_tool", "arguments": {"path": "lib/foo.rb", "staleness": "error"}}
     ```
     ```

Please update all these documentation files to reflect the new naming conventions, add the migration guide, and ensure all examples are accurate.
```

---

## Phase 2: CLI Refinement (Medium Impact)

### Task 2.1: Add `--format` option with deprecation for `--json`

**Estimated Time:** 30 minutes

**Prompt:**

```
I need to add a new `--format` option to control output format, while keeping `--json` as a deprecated alias.

Current state:
- `--json` flag controls JSON output
- No unified format option

Target state:
- `--format FORMAT` option with values: table, json
- `--json` still works but shows deprecation warning
- Future-ready for adding csv, yaml, etc.

Changes needed:

1. In lib/simplecov_mcp/app_config.rb:
   - Add `:format` to the Struct definition (around line 9)
   - Add `format: :table` to the initialize defaults (around line 27)
   - Add a method to handle the json/format duality:
     ```ruby
     def json_output?
       format == :json
     end
     ```

2. In lib/simplecov_mcp/option_parser_builder.rb:
   - Add new option (around line 62, before --json):
     ```ruby
     o.on('-f', '--format FORMAT', String,
       'Output format: table|json (default: table)') do |v|
       config.format = normalize_format(v)
     end
     ```
   - Update the --json option to show deprecation:
     ```ruby
     o.on('-j', '--json', 'Output JSON (DEPRECATED: use --format json)') do
       warn "Warning: --json is deprecated, use --format json instead"
       config.format = :json
     end
     ```

3. In lib/simplecov_mcp/option_normalizers.rb:
   - Add FORMAT_MAP constant:
     ```ruby
     FORMAT_MAP = {
       't' => :table,
       'table' => :table,
       'j' => :json,
       'json' => :json
     }.freeze
     ```
   - Add normalize_format method:
     ```ruby
     def normalize_format(value, strict: true)
       normalized = FORMAT_MAP[value.to_s.downcase]
       return normalized if normalized
       raise OptionParser::InvalidArgument, "invalid argument: #{value}" if strict
       nil
     end
     ```

4. Update all commands that check config.json:
   - lib/simplecov_mcp/commands/list_command.rb
   - lib/simplecov_mcp/commands/total_command.rb
   - Any other commands with JSON output
   - Change: `if config.json`
   - To: `if config.json_output?` (or `if config.format == :json`)

5. In lib/simplecov_mcp/cli.rb (around line 78):
   - Change: `if config.json`
   - To: `if config.json_output?`

6. In lib/simplecov_mcp/constants.rb:
   - Add '--format' to OPTIONS_EXPECTING_ARGUMENT

7. Update tests:
   - spec/cli_enumerated_options_spec.rb - Add format option tests
   - Test that --json still works with deprecation warning
   - Test that --format json works
   - Test that --format table works

8. Update documentation:
   - README.md - Show --format examples
   - docs/user/CLI_USAGE.md - Document new option
   - Add note that --json is deprecated but still supported

9. Run tests:
   bundle exec rspec

Please implement this, ensuring backward compatibility with --json while guiding users toward --format.
```

---

### Task 2.2: Make `--source` require explicit mode

**Estimated Time:** 20 minutes

**Prompt:**

```
I need to make the `--source` option require an explicit mode value instead of having an optional value with a default.

Current state:
- `--source[=MODE]` with optional value, defaults to 'full' if omitted
- `--source-context N` for context lines

Target state:
- `--source MODE` requires explicit value: full or uncovered
- Rename `--source-context` to `--context` for brevity

Changes needed:

1. In lib/simplecov_mcp/option_parser_builder.rb (around line 67):
   - Change:
     ```ruby
     o.on('-s', '--source[=MODE]', String,
       'Include source (MODE: f[ull]|u[ncovered]; default full)') do |v|
       config.source_mode = normalize_source_mode(v)
     end
     ```
   - To:
     ```ruby
     o.on('-s', '--source MODE', String,
       'Source display: full|uncovered') do |v|
       config.source_mode = normalize_source_mode(v)
     end
     ```

2. In lib/simplecov_mcp/option_parser_builder.rb (around line 71):
   - Change:
     ```ruby
     o.on('-c', '--source-context N', Integer,
       'For --source=uncovered, show N context lines (default: 2)') do |v|
     ```
   - To:
     ```ruby
     o.on('-c', '--context N', Integer,
       'Context lines around uncovered lines (default: 2)') do |v|
     ```

3. In lib/simplecov_mcp/option_normalizers.rb (around line 55):
   - Update normalize_source_mode to NOT default nil to :full:
     ```ruby
     def normalize_source_mode(value, strict: true)
       # Remove: return :full if value.nil? || value == ''
       # Now require explicit value
       normalized = SOURCE_MODE_MAP[value.to_s.downcase]
       return normalized if normalized
       raise OptionParser::InvalidArgument, "invalid argument: #{value}" if strict
       nil
     end
     ```

4. Update any code that relies on the default behavior:
   - Search for uses of --source without a value
   - Update examples in documentation

5. Update documentation:
   - README.md - Update --source examples to include mode
   - docs/user/CLI_USAGE.md - Update option documentation
   - Change all `--source-context` to `--context`

6. Update tests:
   - spec/cli_enumerated_options_spec.rb - Test that --source requires a value
   - Test that omitting the value raises an error
   - Test --context instead of --source-context

7. Update RELEASE_NOTES.md:
   - Add: "BREAKING: `--source` now requires explicit mode (full|uncovered)"
   - Add: "BREAKING: `--source-context` renamed to `--context`"

8. Run tests:
   bundle exec rspec

Please make these changes, ensuring that --source no longer accepts an optional value.
```

---

### Task 2.3: Update examples and documentation for Phase 2

**Estimated Time:** 15 minutes

**Prompt:**

```
I need to update all documentation and examples to reflect the Phase 2 CLI refinements.

Changes to document:
- New --format option (table|json)
- --json is deprecated but still works
- --source requires explicit mode
- --source-context renamed to --context

Files to update:

1. README.md:
   - Update "Working with JSON Output" section to show --format json
   - Add deprecation note for --json
   - Update --source examples to include explicit mode
   - Update --source-context to --context

2. docs/user/CLI_USAGE.md:
   - Add --format option documentation
   - Mark --json as deprecated
   - Update --source documentation
   - Update --context documentation (was --source-context)
   - Update all examples

3. docs/user/EXAMPLES.md:
   - Update all CLI command examples
   - Show both --format json and --json (with note)
   - Update source code display examples

4. Update help text examples in:
   - lib/simplecov_mcp/option_parser_builder.rb examples section (around line 106)

5. RELEASE_NOTES.md additions for v2.0.0:
   ```markdown
   ### CLI Refinements

   - **NEW:** `--format FORMAT` option for output format control (table|json)
   - **DEPRECATED:** `--json` flag (use `--format json` instead, but still supported)
   - **BREAKING:** `--source` now requires explicit mode: `--source full` or `--source uncovered`
   - **BREAKING:** `--source-context` renamed to `--context` for brevity

   ### Migration Examples

   ```bash
   # Old
   simplecov-mcp --json list
   simplecov-mcp --source uncovered lib/foo.rb
   simplecov-mcp --source --source-context 3 uncovered lib/foo.rb

   # New (recommended)
   simplecov-mcp --format json list
   simplecov-mcp --source uncovered lib/foo.rb
   simplecov-mcp --source uncovered --context 3 lib/foo.rb

   # Old syntax (still works but deprecated)
   simplecov-mcp --json list  # Shows deprecation warning
   ```
   ```

Please update all documentation to show the new recommended syntax while noting backward compatibility.
```

---

## Phase 3: Polish (Low Impact)

### Task 3.1: Rename `total` subcommand to `totals`

**Estimated Time:** 15 minutes

**Prompt:**

```
I need to rename the `total` subcommand to `totals` (plural) for consistency with what it returns (multiple aggregated totals).

Changes needed:

1. In lib/simplecov_mcp/cli.rb (around line 14):
   - Change SUBCOMMANDS array:
     From: %w[list summary raw uncovered detailed total version]
     To: %w[list summary raw uncovered detailed totals version]

2. In lib/simplecov_mcp/commands/command_factory.rb:
   - Update the command mapping to handle 'totals'
   - Keep 'total' as an alias if we want backward compatibility (optional)

3. Rename the file:
   - Move: lib/simplecov_mcp/commands/total_command.rb
   - To: lib/simplecov_mcp/commands/totals_command.rb
   - Update the class name inside if needed (TotalCommand vs TotalsCommand)

4. Update class references:
   - If using TotalCommand class name, rename to TotalsCommand
   - Update any requires or references

5. In lib/simplecov_mcp/option_parser_builder.rb (around line 48):
   - Update help text:
     From: "total                   Show aggregated line totals and average %"
     To: "totals                  Show aggregated line totals and average %"

6. Update tests:
   - Rename spec/commands/total_command_spec.rb to totals_command_spec.rb
   - Update the describe blocks
   - Update any integration tests that use the 'total' subcommand

7. Update documentation:
   - README.md - Change 'total' to 'totals' in examples
   - docs/user/CLI_USAGE.md - Update subcommand documentation
   - docs/user/EXAMPLES.md - Update examples

8. Update RELEASE_NOTES.md:
   - Add: "BREAKING: `total` subcommand renamed to `totals`"

9. Run tests:
   bundle exec rspec

Optional: If you want backward compatibility, add an alias in the command factory.

Please make these changes to rename the subcommand to 'totals'.
```

---

### Task 3.2: Improve success predicate error messages

**Estimated Time:** 20 minutes

**Prompt:**

```
I need to improve the error messages and warnings for the success predicate feature (--success-predicate option).

Current state:
- Basic error messages in lib/simplecov_mcp/cli.rb (around line 190-225)
- No warning about security implications when loading the file

Target state:
- Better error messages with context
- Security warning when loading predicate files
- Clearer documentation

Changes needed:

1. In lib/simplecov_mcp/cli.rb, update the run_success_predicate method (around line 190):
   - Add security warning before loading:
     ```ruby
     def run_success_predicate
       path = config.success_predicate

       # Warn about security implications
       unless ENV['SIMPLECOV_MCP_SUPPRESS_SECURITY_WARNING']
         warn "⚠️  Loading validation code from: #{path}"
         warn "⚠️  This file will execute with full Ruby privileges."
         warn "⚠️  Only use files from trusted sources."
         warn ""
       end

       predicate = load_success_predicate(path)
       # ... rest of method
     end
     ```

2. In the load_success_predicate method, improve error messages:
   ```ruby
   def load_success_predicate(path)
     unless File.exist?(path)
       raise ConfigurationError.new(
         "Validation file not found: #{path}\n" \
         "Ensure the file exists and the path is correct."
       )
     end

     content = File.read(path)
     evaluation_context = Object.new
     predicate = evaluation_context.instance_eval(content, path, 1)

     unless predicate.respond_to?(:call)
       raise ConfigurationError.new(
         "Validation file must return a callable object (lambda, proc, or object with #call method)\n" \
         "File: #{path}\n" \
         "Returned: #{predicate.class}"
       )
     end

     predicate
   rescue SyntaxError => e
     raise ConfigurationError.new(
       "Syntax error in validation file:\n" \
       "  File: #{path}:#{e.message[/:(\d+):/, 1] || '?'}\n" \
       "  Error: #{e.message}\n\n" \
       "Ensure the file contains valid Ruby code."
     )
   rescue => e
     raise ConfigurationError.new(
       "Failed to load validation file:\n" \
       "  File: #{path}\n" \
       "  Error: #{e.class}: #{e.message}"
     )
   end
   ```

3. Update the error handling in run_success_predicate:
   ```ruby
   rescue ConfigurationError => e
     warn e.user_friendly_message
     exit 2
   rescue => e
     warn "Validation error: #{e.message}"
     warn e.backtrace.first(5).join("\n") if config.error_mode == :debug
     exit 2
   ```

4. Update documentation:
   - docs/user/ADVANCED_USAGE.md - Add security warning section
   - examples/success_predicates/README.md - Add security notes
   - README.md - Add security warning

5. Add to docs/user/ADVANCED_USAGE.md:
   ```markdown
   ### Security Considerations

   ⚠️ **Important:** The validation file executes with full Ruby privileges. It has unrestricted access to:
   - The file system
   - Network resources
   - System commands
   - All Ruby libraries

   **Only use validation files from trusted sources.** Do not use files from:
   - Untrusted contributors
   - Unreviewed pull requests
   - Public repositories without inspection

   To suppress the security warning (e.g., in CI):
   ```bash
   export SIMPLECOV_MCP_SUPPRESS_SECURITY_WARNING=1
   simplecov-mcp --success-predicate policy.rb
   ```
   ```

6. Update tests to expect the new error message format:
   - spec/cli_spec.rb or similar
   - Test that security warning appears
   - Test that warning can be suppressed

7. Run tests:
   bundle exec rspec

Please implement these improved error messages and security warnings.
```

---

### Task 3.3: Final documentation polish and migration guide

**Estimated Time:** 30 minutes

**Prompt:**

```
I need to create a comprehensive migration guide and polish all documentation for the v2.0 release.

Tasks:

1. Create a new file: docs/user/MIGRATION_V1_TO_V2.md with this content:

```markdown
# Migration Guide: v1.x to v2.0

This guide helps you upgrade from simplecov-mcp v1.x to v2.0.

## Breaking Changes Summary

### 1. Parameter Naming
- `stale_mode` → `staleness`
- MCP tool parameter `stale` → `staleness`
- CLI option `--stale` → `--staleness` (short form `-S` removed)

### 2. Error Mode Values
- `on` → `log`
- `trace` → `debug`

### 3. CLI Options
- `--source` now requires explicit mode
- `--source-context` → `--context`
- `total` subcommand → `totals`

### 4. Output Format
- New `--format` option (recommended)
- `--json` deprecated but still works

### 5. Internal Types
- All enum values now use symbols internally
- May affect library users doing string comparisons

## CLI Migration

### Before (v1.x)
```bash
# Staleness checking
simplecov-mcp --stale error list
simplecov-mcp -S e list

# JSON output
simplecov-mcp --json list

# Source display
simplecov-mcp --source uncovered lib/foo.rb
simplecov-mcp --source-context 3 uncovered lib/foo.rb

# Error modes
simplecov-mcp --error-mode on
simplecov-mcp --error-mode trace

# Totals
simplecov-mcp total
```

### After (v2.0)
```bash
# Staleness checking
simplecov-mcp --staleness error list
# (no short form)

# JSON output (new way)
simplecov-mcp --format json list

# JSON output (old way, deprecated but works)
simplecov-mcp --json list  # Shows deprecation warning

# Source display
simplecov-mcp --source uncovered lib/foo.rb
simplecov-mcp --context 3 uncovered lib/foo.rb

# Error modes
simplecov-mcp --error-mode log
simplecov-mcp --error-mode debug

# Totals
simplecov-mcp totals
```

## Library API Migration

### Before (v1.x)
```ruby
# CoverageModel with strings
model = SimpleCovMcp::CoverageModel.new(
  root: '.',
  staleness: 'error'  # String
)

# AppConfig with stale_mode
config = SimpleCovMcp::AppConfig.new(
  stale_mode: :off,
  error_mode: :on
)
```

### After (v2.0)
```ruby
# CoverageModel with symbols
model = SimpleCovMcp::CoverageModel.new(
  root: '.',
  staleness: :error  # Symbol
)

# AppConfig with staleness
config = SimpleCovMcp::AppConfig.new(
  staleness: :off,
  error_mode: :log
)
```

## MCP Tool Migration

### Before (v1.x)
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "coverage_summary_tool",
    "arguments": {
      "path": "lib/foo.rb",
      "stale": "error",
      "error_mode": "on"
    }
  }
}
```

### After (v2.0)
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "coverage_summary_tool",
    "arguments": {
      "path": "lib/foo.rb",
      "staleness": "error",
      "error_mode": "log"
    }
  }
}
```

## Environment Variable Migration

### Before (v1.x)
```bash
export SIMPLECOV_MCP_OPTS="--stale error --error-mode trace"
```

### After (v2.0)
```bash
export SIMPLECOV_MCP_OPTS="--staleness error --error-mode debug"
```

## Common Issues

### Issue: "Unknown option: --stale"
**Solution:** Change to `--staleness`

### Issue: "Invalid argument: on" for error-mode
**Solution:** Change `--error-mode on` to `--error-mode log`

### Issue: String comparison failing in library code
**Before:** `if model.staleness == 'error'`
**After:** `if model.staleness == :error`

### Issue: "--source requires an argument"
**Solution:** Provide explicit mode: `--source full` or `--source uncovered`

## Deprecation Timeline

- **v2.0:** `--json` shows deprecation warning but still works
- **v2.1:** `--json` may be removed (not decided yet)

Use `--format json` for future-proof code.

## Questions?

- Check the [Troubleshooting Guide](TROUBLESHOOTING.md)
- Review [CLI Usage](CLI_USAGE.md) for complete option reference
- File an issue: https://github.com/keithrbennett/simplecov-mcp/issues
```

2. Update README.md:
   - Add prominent "Upgrading from v1.x?" link at the top pointing to the migration guide
   - Ensure all examples use v2.0 syntax
   - Add version badge if not present

3. Update RELEASE_NOTES.md to finalize the v2.0 section:
   - Add release date
   - Link to migration guide
   - Emphasize breaking changes prominently
   - Add "Special Thanks" section if applicable

4. Create a checklist in docs/dev/V2_RELEASE_CHECKLIST.md:
   ```markdown
   # v2.0 Release Checklist

   ## Code Quality
   - [ ] All tests passing
   - [ ] No RuboCop violations
   - [ ] Coverage > 95%

   ## Documentation
   - [ ] MIGRATION_V1_TO_V2.md complete
   - [ ] RELEASE_NOTES.md updated
   - [ ] README.md examples use v2 syntax
   - [ ] All docs/ files reviewed
   - [ ] CLAUDE.md updated

   ## Testing
   - [ ] Manual CLI testing
   - [ ] MCP integration testing
   - [ ] Library API testing
   - [ ] Examples in examples/ directory work

   ## Version Bumping
   - [ ] lib/simplecov_mcp/version.rb → 2.0.0
   - [ ] simplecov-mcp.gemspec version check
   - [ ] Git tag created

   ## Release
   - [ ] Gem built successfully
   - [ ] Gem pushed to RubyGems
   - [ ] GitHub release created
   - [ ] Announcement drafted
   ```

5. Review all documentation files for consistency:
   - Ensure no v1.x syntax remains in examples
   - Check all internal links work
   - Verify code examples are accurate

6. Update simplecov-mcp.gemspec if needed:
   - Ensure description is current
   - Check required Ruby version
   - Verify dependencies

Please create these files and perform a comprehensive documentation review.
```

---

## Final Tasks

### Task: Run full test suite and fix any remaining issues

**Prompt:**

```
Before releasing v2.0, I need to ensure everything works correctly.

Tasks:

1. Run the full test suite:
   ```bash
   bundle exec rspec
   ```

2. Check for any failures and fix them.

3. Run RuboCop if configured:
   ```bash
   bundle exec rubocop
   ```

4. Generate coverage report and verify >95% coverage:
   ```bash
   bundle exec rspec
   simplecov-mcp  # Use the tool to analyze its own coverage!
   ```

5. Manual CLI testing - run each of these commands and verify output:
   ```bash
   # Version
   bundle exec exe/simplecov-mcp --version

   # Help
   bundle exec exe/simplecov-mcp --help

   # Default output
   bundle exec exe/simplecov-mcp

   # Staleness checking
   bundle exec exe/simplecov-mcp --staleness error

   # JSON output (new way)
   bundle exec exe/simplecov-mcp --format json list

   # JSON output (deprecated way - should show warning)
   bundle exec exe/simplecov-mcp --json list

   # Source display
   bundle exec exe/simplecov-mcp --source uncovered lib/simplecov_mcp/model.rb

   # Context lines
   bundle exec exe/simplecov-mcp --source uncovered --context 3 lib/simplecov_mcp/model.rb

   # Totals
   bundle exec exe/simplecov-mcp totals

   # Error modes
   bundle exec exe/simplecov-mcp --error-mode log
   bundle exec exe/simplecov-mcp --error-mode debug
   ```

6. Test MCP server mode (if you have a test client):
   ```bash
   echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"coverage_summary_tool","arguments":{"path":"lib/simplecov_mcp/model.rb","staleness":"off"}}}' | bundle exec exe/simplecov-mcp
   ```

7. Test success predicate if you have example predicates:
   ```bash
   bundle exec exe/simplecov-mcp --success-predicate examples/success_predicates/minimum_coverage.rb
   ```

8. Check for any deprecation warnings or errors in the output.

9. Create a GitHub issue for any bugs found.

10. Document any edge cases discovered.

Please run through this complete testing checklist and report any issues found.
```

---

### Task: Update version and prepare for release

**Prompt:**

```
Final preparation for v2.0.0 release.

Tasks:

1. Update version in lib/simplecov_mcp/version.rb:
   ```ruby
   VERSION = '2.0.0'
   ```

2. Ensure RELEASE_NOTES.md has the release date:
   ```markdown
   ## v2.0.0 (2025-XX-XX)  # Update with actual date
   ```

3. Create a git commit for the v2.0 changes:
   ```bash
   git add -A
   git commit -m "Release v2.0.0

   Breaking changes:
   - Rename stale_mode → staleness throughout API
   - Rename CLI option --stale → --staleness
   - Rename error mode on → log, trace → debug
   - Rename MCP tool parameter stale → staleness
   - Make --source require explicit mode
   - Rename --source-context → --context
   - Rename total subcommand → totals
   - Add --format option (--json deprecated)
   - Convert internal enums to symbols

   See MIGRATION_V1_TO_V2.md for upgrade guide."
   ```

4. Create a git tag:
   ```bash
   git tag -a v2.0.0 -m "Version 2.0.0 - Breaking changes for consistency"
   ```

5. Build the gem:
   ```bash
   gem build simplecov-mcp.gemspec
   ```

6. Verify the gem contents:
   ```bash
   gem unpack simplecov-mcp-2.0.0.gem
   ls -la simplecov-mcp-2.0.0/
   ```

7. Install locally and test:
   ```bash
   gem install simplecov-mcp-2.0.0.gem
   simplecov-mcp --version  # Should show 2.0.0
   simplecov-mcp --help     # Verify help text
   ```

8. When ready to release (don't do yet):
   ```bash
   # Push commits and tags
   git push origin claude/plan-v2-breaking-changes-01FWSVw6N8uhSBgPgW5u9JCH
   git push origin v2.0.0

   # Publish gem
   gem push simplecov-mcp-2.0.0.gem
   ```

Please perform steps 1-7 to prepare for release. Do NOT perform step 8 (actual release) yet.
```

---

## Notes

- Each task can be given independently to a coding assistant
- Tasks are ordered to minimize conflicts
- Run tests after each phase
- Commit after each phase completes successfully
- The prompts include context so they can be understood standalone
- Adjust timeframes based on your actual experience

## Suggested Workflow

1. Do Phase 1 tasks in order (1.1 → 1.7)
2. Run full test suite after Phase 1
3. Commit Phase 1 changes
4. Do Phase 2 tasks in order
5. Run full test suite after Phase 2
6. Commit Phase 2 changes
7. Do Phase 3 tasks
8. Run final testing
9. Prepare release

Good luck with the v2.0 release!
