# Installation Guide

[Back to main README](../README.md)

## Prerequisites

- **Ruby >= 3.2** (required by the `mcp` dependency)
- SimpleCov-generated `.resultset.json` file in your project

## Quick Install

### Via RubyGems

```sh
gem install cov-loupe
```

### Via Bundler

Add to your `Gemfile`:

```ruby
gem 'cov-loupe'
```

Then run:

```sh
bundle install
```

### From Source

```sh
git clone https://github.com/keithrbennett/cov-loupe.git
cd cov-loupe
bundle install
gem build cov-loupe.gemspec
gem install cov-loupe-*.gem
```

## Require Path

The gem uses a single require path:

```ruby
require "cov_loupe"
```

The executable is `cov-loupe` (with hyphen).

## Verification

### Test Installation

```sh
# Check version
cov-loupe version

# Show help
cov-loupe --help

# Run on current project (requires coverage data)
cov-loupe
```

### Generate Test Coverage

If you don't have coverage data yet:

```sh
# Run your tests with SimpleCov enabled
bundle exec rspec  # or your test command

# Verify coverage file exists
ls -l coverage/.resultset.json

# Now test cov-loupe
cov-loupe
```

## Platform-Specific Notes

### macOS

Works with system Ruby or any version manager. Recommended: use rbenv or asdf, not rvm (see note below).

**Note:** RVM may not work in sandboxed environments (e.g., AI coding assistants) because it requires `/bin/ps`, which sandbox restrictions often block. Use rbenv or chruby instead for sandboxed environments.

### Linux

Works with system Ruby or any version manager.

### Windows

Should work with Ruby installed via RubyInstaller. PATH configuration may differ.

## Next Steps

- **[CLI Usage](CLI_USAGE.md)** - Learn command-line options
- **[Library API](LIBRARY_API.md)** - Use in Ruby code
- **[MCP Integration](MCP_INTEGRATION.md)** - Connect to AI assistants
- **[Troubleshooting](TROUBLESHOOTING.md)** - More detailed troubleshooting
