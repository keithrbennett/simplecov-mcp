# lib/cov_loupe Directory Reorganization Plan

## Overview

This document outlines a reorganization plan for the `lib/cov_loupe` directory to improve code organization, maintainability, and developer experience.

## Current State

The `lib/cov_loupe` directory currently contains **37 files at the root level**, with some good existing subdirectories already in place:
- `commands/` - CLI command implementations
- `tools/` - MCP tool implementations
- `presenters/` - Presentation layer
- `repositories/` - Data access layer
- `resolvers/` - Path and data resolution
- `option_parsers/` - CLI option parsing
- `formatters/` - Output formatting
- `scripts/` - Development scripts

## Proposed Reorganization

### 1. Enhance `formatters/` Directory

Move all formatter-related files into the existing `formatters/` directory:

| Current Location | New Location |
|-----------------|--------------|
| `coverage_table_formatter.rb` | `formatters/coverage_table_formatter.rb` |
| `table_formatter.rb` | `formatters/table_formatter.rb` |
| `formatters.rb` | `formatters.rb` (stays) |

**Rationale:** All formatting logic should be grouped together for consistency.

### 2. Create `config/` Directory

Group configuration-related files:

| Current Location | New Location |
|-----------------|--------------|
| `app_config.rb` | `config/app_config.rb` |
| `app_context.rb` | `config/app_context.rb` |
| `config_parser.rb` | `config/config_parser.rb` |
| `constants.rb` | `config/constants.rb` |

**Rationale:** Configuration, context, and constants are closely related and should be grouped together.

### 3. Create `errors/` Directory

Group error handling components:

| Current Location | New Location |
|-----------------|--------------|
| `error_handler.rb` | `errors/error_handler.rb` |
| `error_handler_factory.rb` | `errors/error_handler_factory.rb` |
| `errors.rb` | `errors/errors.rb` |

**Rationale:** Error handling is a distinct concern that should be isolated.

### 4. Create `loaders/` Directory

Group bootstrap and module loading files:

| Current Location | New Location |
|-----------------|--------------|
| `all_cli.rb` | `loaders/all_cli.rb` |
| `all_mcp.rb` | `loaders/all_mcp.rb` |
| `all.rb` | `loaders/all.rb` |

**Rationale:** These files are only used for module loading and should be separated from business logic.

### 5. Create `model/` Directory

Group model-related files:

| Current Location | New Location |
|-----------------|--------------|
| `model.rb` | `model/model.rb` |
| `model_data.rb` | `model/model_data.rb` |
| `model_data_cache.rb` | `model/model_data_cache.rb` |

**Rationale:** The core coverage model and its data structures should be grouped together.

### 6. Create `staleness/` Directory

Group staleness-related files:

| Current Location | New Location |
|-----------------|--------------|
| `staleness_checker.rb` | `staleness/staleness_checker.rb` |
| `stale_status.rb` | `staleness/stale_status.rb` |
| `staleness_message_formatter.rb` | `staleness/staleness_message_formatter.rb` |

**Rationale:** Staleness detection is a specific domain concern that should be isolated.

### 7. Create `coverage/` Directory

Group coverage-specific logic:

| Current Location | New Location |
|-----------------|--------------|
| `coverage_calculator.rb` | `coverage/coverage_calculator.rb` |
| `coverage_reporter.rb` | `coverage/coverage_reporter.rb` |

**Rationale:** Coverage calculation and reporting are core business logic.

### 8. Create `paths/` Directory

Group path-related utilities:

| Current Location | New Location |
|-----------------|--------------|
| `path_utils.rb` | `paths/path_utils.rb` |
| `path_relativizer.rb` | `paths/path_relativizer.rb` |

**Rationale:** Path manipulation and resolution should be grouped together.

### 9. Move Files to Existing Directories

Move related files to appropriate existing directories:

| Current Location | New Location |
|-----------------|--------------|
| `option_normalizers.rb` | `option_parsers/option_normalizers.rb` |
| `option_parser_builder.rb` | `option_parsers/option_parser_builder.rb` |
| `resultset_loader.rb` | `repositories/resultset_loader.rb` |
| `predicate_evaluator.rb` | `tools/predicate_evaluator.rb` |
| `boolean_type.rb` | `option_parsers/boolean_option_parser_type.rb` (renamed) |

**Rationale:** These files belong logically with their related components. BooleanType is specifically for option parsing and should be renamed to BooleanOptionParserType to reflect its purpose.

## Files to Keep at Root Level

These files will remain at `lib/cov_loupe/` root:

- `cli.rb` - Main CLI entry point
- `mcp_server.rb` - Main MCP server entry point
- `base_tool.rb` - Base class used across the codebase
- `glob_utils.rb` - General utility
- `logger.rb` - General utility
- `version.rb` - Version information
- `cov_loupe.rb` - Main module file

**Rationale:** These are either entry points or truly global utilities.

## Benefits

1. **Clearer Structure** - Related files are grouped together by concern
2. **Easier Navigation** - Developers can quickly find files by their domain
3. **Better Separation of Concerns** - Each directory has a clear, single responsibility
4. **Scalability** - Easier to add new files in the appropriate location
5. **Reduced Root Clutter** - Root directory reduced from 37 files to 8 files

## Impact Assessment

### Files to Move

**Total:** 29 files to be reorganized (including 1 rename)

### Requires Updates

1. **All `require_relative` statements** throughout the codebase
2. **Loader files:** `all_cli.rb`, `all_mcp.rb`, `all.rb`, `cov_loupe.rb`
3. **Test files** in `spec/` that require these files
4. **Documentation** that references file paths

### Migration Strategy

1. Update all `require_relative` statements first
2. Move files using `git mv` to preserve history
3. Update test requires
4. Verify all tests pass
5. Update documentation as needed

## Directory Structure After Reorganization

```
lib/cov_loupe/
├── all_cli.rb         → loaders/all_cli.rb
├── all_mcp.rb         → loaders/all_mcp.rb
├── all.rb             → loaders/all.rb
├── app_config.rb      → config/app_config.rb
├── app_context.rb     → config/app_context.rb
├── base_tool.rb       (stays)
├── boolean_type.rb    → option_parsers/boolean_option_parser_type.rb (renamed)
├── cli.rb             (stays)
├── config_parser.rb   → config/config_parser.rb
├── constants.rb       → config/constants.rb
├── coverage_calculator.rb  → coverage/coverage_calculator.rb
├── coverage_reporter.rb     → coverage/coverage_reporter.rb
├── coverage_table_formatter.rb → formatters/coverage_table_formatter.rb
├── error_handler.rb         → errors/error_handler.rb
├── error_handler_factory.rb → errors/error_handler_factory.rb
├── errors.rb                 → errors/errors.rb
├── formatters.rb       (stays in formatters/)
├── glob_utils.rb       (stays)
├── logger.rb           (stays)
├── mcp_server.rb       (stays)
├── model.rb            → model/model.rb
├── model_data.rb       → model/model_data.rb
├── model_data_cache.rb → model/model_data_cache.rb
├── option_normalizers.rb   → option_parsers/option_normalizers.rb
├── option_parser_builder.rb → option_parsers/option_parser_builder.rb
├── path_relativizer.rb → paths/path_relativizer.rb
├── path_utils.rb       → paths/path_utils.rb
├── predicate_evaluator.rb → tools/predicate_evaluator.rb
├── resultset_loader.rb → repositories/resultset_loader.rb
├── staleness_checker.rb → staleness/staleness_checker.rb
├── stale_status.rb        → staleness/stale_status.rb
├── staleness_message_formatter.rb → staleness/staleness_message_formatter.rb
├── table_formatter.rb   → formatters/table_formatter.rb
├── version.rb           (stays)
├── cov_loupe.rb         (stays)
├── config/              (new)
├── coverage/            (new)
├── errors/              (new)
├── loaders/             (new)
├── model/               (new)
├── paths/               (new)
├── staleness/           (new)
├── commands/            (existing, unchanged)
├── formatters/          (existing, enhanced)
├── option_parsers/      (existing, enhanced)
├── presenters/          (existing, unchanged)
├── repositories/        (existing, enhanced)
├── resolvers/           (existing, unchanged)
├── scripts/             (existing, unchanged)
└── tools/               (existing, enhanced)
```

## Testing Plan

After reorganization:

1. Run full test suite: `bundle exec rspec`
2. Run RuboCop: `bundle exec rubocop`
3. Verify CLI commands work: `bundle exec exe/cov-loupe list`
4. Verify MCP server loads: `echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | bundle exec exe/cov-loupe -m mcp`

## Rollback Plan

If issues arise, rollback can be done by:
1. Reverting the `git mv` commands with `git mv` in reverse
2. Reverting require statement changes from git history

## Implementation Steps

1. Update all `require_relative` statements in source files
2. Update all `require_relative` statements in test files
3. Move files using `git mv` commands
4. Run tests to verify
5. Update any documentation references

---

**Status:** Proposed  
**Created:** 2026-01-09  
**Author:** Cline AI Assistant