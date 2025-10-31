# Installation Guide

[Back to main README](../README.md)

This guide covers installing simplecov-mcp in various environments and configurations.

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

## Require Paths

The gem supports multiple require paths for compatibility:

```ruby
require "simplecov_mcp"     # Primary path (recommended)
require "simple_cov/mcp"    # Legacy shim (supported)
```

The executable is always `simplecov-mcp` (with hyphen).

## Version Manager Setup

### rbenv

After installation:

```sh
rbenv rehash
which simplecov-mcp  # Should point to rbenv shim
```

For MCP server configuration, use the shim path:

```sh
which simplecov-mcp
# Example: /Users/yourname/.rbenv/shims/simplecov-mcp
```

### RVM

After installation:

```sh
rvm use 3.3.8  # or your preferred Ruby 3.2+ version
gem install simplecov-mcp
```

For MCP server configuration with RVM:

```sh
# Get the full gem path for your Ruby version
rvm use 3.3.8
which simplecov-mcp
# Example: /Users/yourname/.rvm/gems/ruby-3.3.8/bin/simplecov-mcp

# Or use RVM wrappers for stability across shell sessions:
rvm wrapper ruby-3.3.8 simplecov-mcp simplecov-mcp
# Creates: /Users/yourname/.rvm/wrappers/ruby-3.3.8/simplecov-mcp
```

**Important:** If you change Ruby versions, you'll need to reinstall the gem or update your MCP configuration.

### asdf

After installation:

```sh
asdf reshim ruby
which simplecov-mcp  # Should point to asdf shim
```

### chruby

chruby automatically adds gem bins to PATH. After installation:

```sh
which simplecov-mcp  # Should be in current Ruby's gem bin
```

## PATH Configuration

### Automatic (with Version Managers)

Most version managers (rbenv, asdf, RVM, chruby) automatically configure PATH. Verify:

```sh
which simplecov-mcp
```

If this returns a path, you're all set.

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

## Docker/Container Environments

When using in containers:

```dockerfile
FROM ruby:3.3

# Install gem
RUN gem install simplecov-mcp

# Or with Bundler
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Usage
CMD ["simplecov-mcp"]
```

Mount your project directory to access coverage data:

```sh
docker run -v $(pwd):/app -w /app ruby:3.3 simplecov-mcp
```

## CI/CD Environments

### GitHub Actions

```yaml
- name: Setup Ruby
  uses: ruby/setup-ruby@v1
  with:
    ruby-version: 3.3
    bundler-cache: true

- name: Install simplecov-mcp
  run: gem install simplecov-mcp

- name: Check coverage
  run: simplecov-mcp --stale error
```

### GitLab CI

```yaml
test:
  image: ruby:3.3
  before_script:
    - gem install simplecov-mcp
  script:
    - bundle exec rspec
    - simplecov-mcp --stale error
```

## Upgrading

### From Previous Versions

```sh
gem update simplecov-mcp
```

With Bundler:

```sh
bundle update simplecov-mcp
```

### Version Manager Considerations

After upgrading Ruby versions, reinstall:

```sh
# rbenv/asdf
gem install simplecov-mcp
rbenv rehash  # or: asdf reshim ruby

# RVM
rvm use 3.3.8
gem install simplecov-mcp
```

## Troubleshooting

### "command not found: simplecov-mcp"

1. Verify gem is installed:
   ```sh
   gem list simplecov-mcp
   ```

2. Check gem bin is in PATH:
   ```sh
   echo $PATH | grep -o "$(gem env gemdir)/bin"
   ```

3. Use full path temporarily:
   ```sh
   $(gem env gemdir)/bin/simplecov-mcp
   ```

4. Or use bundler:
   ```sh
   bundle exec simplecov-mcp
   ```

### "cannot load such file -- mcp"

Your Ruby version is too old. Verify:

```sh
ruby -v  # Should be 3.2.0 or higher
```

Upgrade Ruby and reinstall.

### "wrong number of arguments"

You may have multiple versions installed. Clean up:

```sh
gem uninstall simplecov-mcp
# Select "All versions" if prompted
gem install simplecov-mcp
```

### Version Manager Shims Not Updating

```sh
# rbenv
rbenv rehash

# asdf
asdf reshim ruby

# RVM
# Usually automatic, but try:
rvm reload
```

## Next Steps

- **[CLI Usage](CLI_USAGE.md)** - Learn command-line options
- **[Library API](LIBRARY_API.md)** - Use in Ruby code
- **[MCP Integration](MCP_INTEGRATION.md)** - Connect to AI assistants
- **[Troubleshooting](TROUBLESHOOTING.md)** - More detailed troubleshooting
