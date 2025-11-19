# Installation Guide

[Back to main README](../README.md)

## Prerequisites

- **Ruby >= 3.2** (required by the `mcp` dependency)
- SimpleCov-generated `.resultset.json` file in your project

## Quick Install

### Via RubyGems

```sh
gem install simplecov-mcp
```

### Via Bundler

Add to your `Gemfile`:

```ruby
gem 'simplecov-mcp'
```

Then run:

```sh
bundle install
```

### From Source

```sh
git clone https://github.com/keithrbennett/simplecov-mcp.git
cd simplecov-mcp
bundle install
gem build simplecov-mcp.gemspec
gem install simplecov-mcp-*.gem
```

## Require Path

The gem uses a single require path:

```ruby
require "simplecov_mcp"
```

The executable is `simplecov-mcp` (with hyphen).

## PATH Configuration

### With Version Managers

Most version managers (rbenv, asdf, RVM, chruby) automatically configure PATH. After installation:

```sh
# Refresh shims if needed
rbenv rehash      # rbenv
asdf reshim ruby  # asdf

# Verify executable is accessible
which simplecov-mcp
```

**Important:** When changing Ruby versions, reinstall the gem and update any MCP configurations that use absolute paths.

### Manual PATH Setup

If you're not using a version manager, add the gem bin directory to your PATH:

1. Find your gem bin directory:
   ```sh
   gem env | grep "EXECUTABLE DIRECTORY"
   # or
   ruby -e 'puts Gem.bindir'
   ```

2. Add to your shell profile (`.bashrc`, `.zshrc`, etc.):
   ```sh
   export PATH="$(ruby -e 'puts Gem.bindir'):$PATH"
   ```

3. Reload your shell:
   ```sh
   source ~/.zshrc  # or ~/.bashrc
   ```

### Bundler Execution

If PATH setup is problematic, use bundler:

```sh
bundle exec simplecov-mcp
```

This works from any project directory that has simplecov-mcp in its Gemfile.

## Verification

### Test Installation

```sh
# Check version
simplecov-mcp version

# Show help
simplecov-mcp --help

# Run on current project (requires coverage data)
simplecov-mcp
```

### Generate Test Coverage

If you don't have coverage data yet:

```sh
# Run your tests with SimpleCov enabled
bundle exec rspec  # or your test command

# Verify coverage file exists
ls coverage/.resultset.json

# Now test simplecov-mcp
simplecov-mcp
```

## Platform-Specific Notes

### macOS

Works with system Ruby or any version manager. Recommended: use rbenv or asdf.

### Linux

Works with system Ruby or any version manager. May need to install Ruby development headers:

```sh
# Debian/Ubuntu
sudo apt-get install ruby-dev

# RHEL/CentOS
sudo yum install ruby-devel
```

### Windows

Should work with Ruby installed via RubyInstaller. PATH configuration may differ.

## Next Steps

- **[CLI Usage](CLI_USAGE.md)** - Learn command-line options
- **[Library API](LIBRARY_API.md)** - Use in Ruby code
- **[MCP Integration](MCP_INTEGRATION.md)** - Connect to AI assistants
- **[Troubleshooting](TROUBLESHOOTING.md)** - More detailed troubleshooting
