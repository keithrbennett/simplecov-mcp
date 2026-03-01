# Prompt: Unify I/O Capture Helpers in the Test Suite

## Background

The test suite currently captures and suppresses stdout/stderr in several inconsistent ways.
Your task is to consolidate all of these into a small, coherent set of helpers defined in
`spec/support/io_helpers.rb` and update every caller.

---

## Current State — What Exists and Where

### `spec/support/io_helpers.rb` — the canonical helper file

```ruby
module TestIOHelpers
  # Suppress stdout/stderr; yields the two StringIOs to the block.
  def silence_output
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield $stdout, $stderr
  ensure
    $stdout = original_stdout
    $stderr = original_stderr
  end

  # Run a command and return its stdout string (stderr is silenced).
  def capture_command_output(command, args)
    output = nil
    silence_output do
      command.execute(args.dup)
      output = $stdout.string
    end
    output
  end
end
```

`TestIOHelpers` is `include`d globally via `RSpec.configure` in `spec/spec_helper.rb`.

### `spec/cov_loupe/option_parsers/error_helper_spec.rb:30-42` — a *local* private method

```ruby
def capture_stderr
  captured = StringIO.new
  original = $stderr
  $stderr = captured
  begin
    yield
  rescue SystemExit
    # Ignore exit calls
  ensure
    $stderr = original
  end
  captured.string
end
```

This is defined inside the `RSpec.describe` block and used at lines 111, 145, 159, 172, 211, 223.
It duplicates what `silence_output` already provides, but returns only the stderr string and
silently swallows `SystemExit`.

### RSpec built-in matchers (`to_stderr`, `to_stdout`)

Used in a few places (e.g. `error_helper_spec.rb:50`, `error_helper_spec.rb:193`,
`env_options_spec.rb:15`) via the `expect { }.to output(pattern).to_stderr` form.
These work differently from the `$stderr = StringIO.new` approach and do not need to change.

---

## Patterns Found Across the Suite (and Their Problems)

| Pattern | Files | Problem |
|---|---|---|
| `silence_output { ... }` (ignore all output) | `cov_loupe_opts_spec.rb`, `logging_fallback_spec.rb`, etc. | Fine as-is |
| `silence_output do \|stdout, _stderr\| ... stdout.string ... end` | `show_default_report_spec.rb:21` | Fine as-is; yields the IOs so callers can choose whether to inspect them |
| `silence_output do ... $stderr.string ... end` | `show_default_report_spec.rb:64-66`, `logging_fallback_spec.rb`, `totals_command_spec.rb:159-161`, `command_execution_spec.rb`, `pre_release_check_spec.rb`, etc. | Requires caller to reach into global `$stderr` inside block |
| `silence_output do ... $stdout.string + $stderr.string ... end` | `cov_loupe_opts_spec.rb:120-124`, `cov_loupe_opts_spec.rb:151-153` | Same problem, both streams |
| `capture_command_output(command, args)` | `version_command_spec.rb`, `list_command_spec.rb`, `raw_command_spec.rb`, `detailed_command_spec.rb`, etc. | Command-specific wrapper; only returns stdout |
| Local `capture_stderr` | `error_helper_spec.rb:30-42` | Should not be local; already handled by `silence_output` |
| `$stderr.reopen(StringIO.new)` mid-block | `logging_fallback_spec.rb:66` | Special case — clearing stderr inside a silence block; keep as-is |

---

## Desired Outcome — Unified API

Replace everything in `spec/support/io_helpers.rb` with the following three methods and update
all callers.

### Method 1: `capture_io` — primary capture helper

```ruby
# Redirect stdout and stderr to StringIOs for the duration of the block.
# Returns [block_return_value, stdout_string, stderr_string].
# If swallow_exit: true, SystemExit is caught and the exit object is returned
# as the block return value instead of re-raising.
def capture_io(swallow_exit: false)
  old_out, old_err = $stdout, $stderr
  $stdout = StringIO.new
  $stderr = StringIO.new
  result = begin
    yield
  rescue SystemExit => e
    raise unless swallow_exit
    e
  end
  [result, $stdout.string, $stderr.string]
ensure
  $stdout = old_out
  $stderr = old_err
end
```

### Method 2: `suppress_io` — when callers only want to silence output

```ruby
# Redirect stdout and stderr for the duration of the block and discard them.
# Returns the block's return value.
# This replaces the old silence_output usages where the captured strings
# are never inspected.
def suppress_io
  _result, _out, _err = capture_io { yield }
  _result
end
```

### Method 3: `capture_command_output` — retained for command-specific tests

```ruby
# Run a BaseCommand and return its stdout string (stderr is discarded).
def capture_command_output(command, args)
  _result, out, _err = capture_io { command.execute(args.dup) }
  out
end
```

Do **not** keep `silence_output`. All callers of `silence_output` must be migrated.

---

## Migration Instructions

### `spec/support/io_helpers.rb`

Replace the entire file content with the three methods above (inside `module TestIOHelpers`).
Keep the `# frozen_string_literal: true` header.

### `spec/cov_loupe/option_parsers/error_helper_spec.rb`

1. Delete the local `capture_stderr` method definition (lines 30–42).
2. Replace every call to `capture_stderr { ... }` with:
   ```ruby
   _result, _out, stderr_output = capture_io(swallow_exit: true) { ... }
   ```
   Then use `stderr_output` instead of `stderr_output = capture_stderr { ... }`.
3. The `expect_error_output` helper (lines 44–51) uses `expect { }.to output(pattern).to_stderr`
   which is fine — leave it unchanged.

### All files using `silence_output`

For each call site, choose the appropriate replacement:

**Case A — output is never inspected (pure suppression):**
```ruby
# Before
silence_output { some_call }
silence_output do
  some_call
end

# After
suppress_io { some_call }
suppress_io do
  some_call
end
```

**Case B — stderr (or stdout) is inspected inside the block via `$stderr.string` / `$stdout.string`:**
```ruby
# Before
silence_output do
  some_call
  warnings = $stderr.string
end

# After
_result, _out, warnings = capture_io { some_call }
```

```ruby
# Before
output = nil
silence_output do
  some_call
  output = $stdout.string
end

# After
_result, output, _err = capture_io { some_call }
```

```ruby
# Before — both streams
silence_output do
  some_call
  output = $stdout.string + $stderr.string
end

# After
_result, out, err = capture_io { some_call }
output = out + err
```

**Case C — the block yields `|stdout, _stderr|` and passes the IO to a method:**
```ruby
# Before (show_default_report_spec.rb:21)
output = nil
silence_output do |stdout, _stderr|
  cli.show_default_report(sort_order: :ascending, output: stdout)
  output = stdout.string
end

# After
_result, output, _err = capture_io do
  cli.show_default_report(sort_order: :ascending, output: $stdout)
end
```

**Case D — `SystemExit` is expected to be raised (keep the raise_error expectation):**
```ruby
# Before
silence_output do
  expect { some_call }.to raise_error(SystemExit)
end

# After
suppress_io do
  expect { some_call }.to raise_error(SystemExit)
end
```

**Case E — special mid-block reset (`$stderr.reopen`) in `logging_fallback_spec.rb:66`:**
This test explicitly clears stderr between two calls to verify a warning is emitted exactly once.
Keep this test's structure using `capture_io`, but be careful: calling `$stderr.reopen` on the
captured `StringIO` is the correct technique. The test should look like:

```ruby
_result, _out, _err = capture_io do
  CovLoupe.logger.info('first failure')
  first_stderr = $stderr.string.dup
  $stderr.reopen(StringIO.new)          # clear the captured buffer

  CovLoupe.logger.info('second failure')
  second_stderr = $stderr.string

  stderr_output = first_stderr + second_stderr
  # ... rest of assertions using stderr_output ...
end
```

Or, since the assertions happen inside the block anyway, the outer return values can be ignored.

---

## Files to Touch (Complete List)

Work through these files in order; use `bundle exec rubocop --cache false` to keep style clean
after each group.

1. `spec/support/io_helpers.rb` — replace with new API
2. `spec/cov_loupe/option_parsers/error_helper_spec.rb` — remove local `capture_stderr`, migrate callers
3. `spec/cov_loupe/cli/show_default_report_spec.rb` — migrate `silence_output` usages
4. `spec/cov_loupe/config/logging_fallback_spec.rb` — migrate all `silence_output` usages (including the mid-block reopen case)
5. `spec/cov_loupe/config/cov_loupe_opts_spec.rb` — migrate all `silence_output` usages
6. `spec/cov_loupe/commands/totals_command_spec.rb` — migrate `silence_output` at lines ~159–161
7. `spec/cov_loupe/scripts/command_execution_spec.rb` — migrate all `silence_output` usages
8. `spec/cov_loupe/scripts/latest_ci_status_spec.rb` — migrate all `silence_output` usages
9. `spec/cov_loupe/scripts/pre_release_check_spec.rb` — migrate all `silence_output` usages
10. `spec/cov_loupe_spec.rb` — migrate `silence_output` at line ~36

---

## Constraints and Conventions

- **Do not** change any production code (`lib/`).
- **Do not** change `spec/spec_helper.rb` (the `include TestIOHelpers` line stays).
- **Do not** rename or change `capture_command_output` — it is used widely and its signature is fine.
- **Do not** replace RSpec's `expect { }.to output(pattern).to_stderr` usages — those are idiomatic.
- Keep `# frozen_string_literal: true` at the top of every Ruby file you touch.
- Follow the project's two-space indentation style.
- After completing all changes, run `bundle exec rubocop --cache false` and fix any offences,
  then run `bundle exec rspec` to confirm all tests pass.
- Stage only the files listed above; propose a commit message rather than committing directly.
