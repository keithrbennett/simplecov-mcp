# Contributing to simplecov-mcp

Thank you for your interest in contributing! 
This project welcomes bug reports, improvements, and suggestions that make it more useful and reliable for the Ruby community.

---

## How to Contribute

### 1. Reporting Issues
- Check existing issues before opening a new one.  
- Include clear reproduction steps, expected vs. actual results, and your Ruby version (`ruby -v`) and OS.  
- Keep discussion technical and respectful — see the [Code of Conduct](CODE_OF_CONDUCT.md).

### 2. Submitting Changes
1. **Fork** the repository on GitHub.  
1. **Create a branch** for your work:  
   ```bash
   git checkout -b feature/my-change
   ```
1. **Install dependencies**:  
   ```bash
   bundle install
   ```
1. Make your changes, conforming to the project's coding style.
1. **Run tests** to verify your changes:  
   ```bash
   bundle exec rspec
   ```
1. **Lint the code**:  
   ```bash
   bundle exec rubocop
   ```
1. Commit changes with clear, concise messages following conventional commit style (e.g. `fix: handle missing file gracefully`).
1. **Push** your branch and open a **Pull Request** against `main`.

PRs should:
- Include or update tests for new/changed behavior.  
- Pass all existing tests and RuboCop checks.  
- Update documentation or README examples if behavior changes.

---

## Development Setup

This project supports modern Ruby versions (3.1+). Typical workflow:

```bash
git clone https://github.com/keithrbennett/simplecov-mcp.git
cd simplecov-mcp
bundle install
rspec
```

Optional tools:
- `rake` as an alternate way to run `rspec` and `rubocop`
- `exe/simplecov-mcp` the CLI and MCP entry point, use for end-to-end runs

---

## Release Process (maintainer only)

1. Update version in `lib/simplecov/mcp/version.rb`
2. Update `CHANGELOG.md`
3. Tag and push:
   ```bash
   git commit -m "Release v1.0.0"
   git tag -a v1.0.0
   # Include release notes summary in tag text
   git push origin main --tags
   ```
4. Build and publish:
   ```bash
   gem build simplecov-mcp.gemspec
   gem push simplecov-mcp-#{version-string}.gem
   ```
---

## Code of Conduct

Please review and follow the [Code of Conduct](CODE_OF_CONDUCT.md). 
Instances of unacceptable behavior may be reported through GitHub’s [Report Abuse form](https://github.com/contact/report-abuse).

---

Thank you for helping improve **simplecov-mcp**!
