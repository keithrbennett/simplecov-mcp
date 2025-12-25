# Path Resolution Strategy

[Back to ADR Index](README.md)

## Cross-OS Coverage Data Support

### Status
**Accepted** (2025-12-26)

### Context

SimpleCov's `.resultset.json` files contain file paths as keys in the coverage data hash. These paths are typically absolute paths from the machine where tests were run. Different operating systems use different path separators:
- Unix/Linux/macOS: `/`
- Windows: `\` (backslash)

Early versions of cov-loupe included path normalization logic that converted backslashes to forward slashes, enabling cross-platform path matching. This was motivated by a theoretical use case: analyzing a `.resultset.json` file generated on one OS (e.g., Windows) on a different OS (e.g., Linux/macOS).

Upon closer examination, this cross-OS scenario is unrealistic for several reasons:

1. **CI/CD workflows** – While coverage files might be generated in CI (often Linux), developers typically either:
   - Re-run tests locally to generate fresh coverage
   - View coverage reports rendered by SimpleCov's HTML formatter
   - Use hosted coverage services (Codecov, Coveralls)

2. **Docker development** – When tests run in containers, volume mounting ensures paths already match the host environment

3. **Path structure differences** – Cross-OS paths differ in more ways than just separators (drive letters, root paths, etc.), making simple separator normalization insufficient

4. **Same-machine path variations** – The legitimate use case is handling different working directories or relative vs absolute paths on the *same* machine, not across different OSes

### Decision

**Do not support analyzing `.resultset.json` files across different operating systems.**

Specifically:
- Normalize backslashes to forward slashes on Windows only
- Apply case-insensitive path matching on Windows (filesystem is case-insensitive)
- Apply case-sensitive path matching on Unix (filesystem is case-sensitive)
- Keep path resolution focused on same-OS scenarios:
  - Exact absolute path matching
  - Relative path matching (stripping project root)
  - Basename fallback (with ambiguity detection)
- Trust that paths in coverage data use the native separator for the OS where cov-loupe runs

### Consequences

**Benefits:**
- **Simpler code** – No need for path separator normalization logic
- **Clearer semantics** – Path matching behavior is more predictable
- **Fewer edge cases** – No ambiguity around mixed separator styles
- **Honest API** – We don't promise cross-OS compatibility we can't fully deliver

**Trade-offs:**
- Users cannot analyze Windows `.resultset.json` files on Linux/macOS or vice versa
  - This is acceptable because this scenario is impractical anyway
  - Users who encounter this should re-run tests in their current environment

**No impact on:**
- Same-OS path resolution (absolute, relative, basename fallback)
- Normal development workflows
- CI/CD integration
- Docker/container-based development

### Implementation

Path normalization uses a strategy pattern to minimize runtime branching:
- A normalization lambda is built once at resolver initialization based on `RUBY_PLATFORM`
- Windows normalizer: converts backslashes to forward slashes and downcases for case-insensitive matching
- Unix normalizer: returns path as-is (no conversion needed)
- All path operations use the injected normalizer without platform checks at the call site

This approach keeps the code clean and avoids scattered `if windows?` checks throughout the resolver.

### References

- Implementation: `lib/cov_loupe/resolvers/coverage_line_resolver.rb` (build_path_normalizer method)
- Related tests removed: `spec/resolvers/coverage_line_resolver_spec.rb` (cross-OS separator normalization context)
