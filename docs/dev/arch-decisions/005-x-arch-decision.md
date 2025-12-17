# ADR 005: No SimpleCov Runtime Dependency

[Back to main README](../../README.md)

## Status

Replaced – cov-loupe now requires SimpleCov at runtime so that multi-suite resultsets can be merged using SimpleCov’s combine helpers.

## Context

cov-loupe provides tooling for inspecting SimpleCov coverage reports. When designing the gem, we had to decide whether to depend on SimpleCov as a runtime dependency.

### Alternative Approaches

1. **Runtime dependency on SimpleCov**: Use SimpleCov's API to read and process coverage data
2. **Development-only dependency**: Read SimpleCov's `.resultset.json` files directly without requiring SimpleCov at runtime
3. **Support multiple coverage formats**: Parse coverage data from multiple tools (SimpleCov, Coverage, etc.)

### Key Considerations

**Dependency weight**: SimpleCov itself has dependencies:
- `docile` (~> 1.1)
- `simplecov-html` (~> 0.11)
- `simplecov_json_formatter` (~> 0.1)

**Use case separation**:
- SimpleCov is needed when **running tests** to collect coverage
- cov-loupe is needed when **inspecting coverage** after tests complete
- These are temporally separated activities

**Deployment contexts**:
- CI/CD: Coverage collection happens in test job, inspection might happen in a separate analysis job
- Production: Some teams want to analyze coverage data without installing test dependencies
- Developer machines: May want to inspect coverage without full test suite dependencies

**Format stability**:
- SimpleCov's `.resultset.json` format is stable and well-documented
- The format is simple JSON with predictable structure
- Breaking changes would affect all SimpleCov users, so the format is unlikely to change

## Decision

We chose to **make SimpleCov a development dependency only** and read `.resultset.json` files directly using Ruby's standard library JSON parser.

### Implementation

cov-loupe currently depends on `amazing_print`, `mcp`, and `simplecov` at runtime.

Coverage data is read directly from JSON files by `CovLoupe::CoverageModel#load_coverage_data`:
```ruby
rs = CovUtil.find_resultset(@root, resultset: resultset)
raw = JSON.parse(File.read(rs))
# SimpleCov typically writes a single test suite entry to .resultset.json
# Find the first entry that has coverage data (skip comment entries)
_suite, data = raw.find { |k, v| v.is_a?(Hash) && v.key?('coverage') }
raise "No test suite with coverage data found in resultset file: #{rs}" unless data
cov = data['coverage'] or raise "No 'coverage' key found in resultset file: #{rs}"
@cov = cov.transform_keys { |k| File.absolute_path(k, @root) }
@cov_timestamp = (data['timestamp'] || data['created_at'] || 0).to_i
```

Coverage calculations use simple algorithms in `CovLoupe::CovUtil` (`summary`, `uncovered`, `detailed`):
```ruby
def summary(arr)
  total = 0
  covered = 0
  arr.compact.each do |hits|
    total += 1
    covered += 1 if hits.to_i > 0
  end
  percentage = total.zero? ? 100.0 : ((covered.to_f * 100.0 / total) * 100).round / 100.0
  { 'covered' => covered, 'total' => total, 'percentage' => percentage }
end

def uncovered(arr)
  out = []
  arr.each_with_index do |hits, i|
    next if hits.nil?
    out << (i + 1) if hits.to_i.zero?
  end
  out
end

def detailed(arr)
  rows = []
  arr.each_with_index do |hits, i|
    h = hits&.to_i
    rows << { 'line' => i + 1, 'hits' => h, 'covered' => h.positive? } if h
  end
  rows
end
```

### SimpleCov .resultset.json Format

The format we parse has this structure:
```json
{
  "RSpec": {
    "coverage": {
      "/absolute/path/to/file.rb": {
        "lines": [null, 1, 3, 0, null, 5, ...]
      }
    },
    "timestamp": 1633072800
  }
}
```

Where:
- Top level keys are test suite names (e.g., "RSpec", "Minitest")
- `coverage` contains file paths mapped to coverage data
- `lines` is an array where each index represents a line number (0-indexed)
- Array values: `null` = not executable, `0` = not covered, `>0` = hit count
- `timestamp` is Unix timestamp when coverage was collected

### Resultset Discovery

We implement flexible discovery of `.resultset.json` files via `CovUtil::RESULTSET_CANDIDATES`:
```ruby
RESULTSET_CANDIDATES = [
  '.resultset.json',
  'coverage/.resultset.json',
  'tmp/.resultset.json'
].freeze
```

This supports common SimpleCov configurations without requiring SimpleCov to be loaded.

## Consequences

### Positive

1. **Lightweight installation**: No transitive dependencies beyond `mcp` gem
2. **Deployment flexibility**: Can analyze coverage in environments without test dependencies
3. **Faster installation**: Fewer gems to download and install
4. **Clear separation of concerns**: Coverage collection vs. coverage analysis are independent
5. **CI/CD optimization**: Analysis jobs don't need full test suite dependencies
6. **Production-safe**: Can be deployed to production environments if needed (e.g., for monitoring)

### Negative

1. **Format dependency**: Tightly coupled to SimpleCov's JSON format
2. **Breaking changes risk**: If SimpleCov changes `.resultset.json` structure, we must adapt
3. **Limited to SimpleCov**: Cannot read coverage data from other Ruby coverage tools
4. **Duplicate logic**: Coverage percentage calculations reimplemented (though simple)
5. **Maintenance**: Must track SimpleCov format changes manually

### Trade-offs

- **Versus runtime dependency**: Lighter weight but less resilient to format changes
- **Versus multi-format support**: Simpler implementation but locked to SimpleCov ecosystem
- **Versus using SimpleCov API**: More flexible deployment but requires understanding the file format

### Risk Mitigation

1. **Format stability**: SimpleCov has maintained `.resultset.json` compatibility for years
2. **Simple format**: JSON structure is straightforward and unlikely to change dramatically
3. **Development dependency**: We still use SimpleCov in our own tests, so format changes would be detected immediately
4. **Documentation**: CLAUDE.md documents the format dependency explicitly
5. **Error handling**: Robust error messages when format doesn't match expectations

### Format Evolution Strategy

If SimpleCov's format changes:
1. **Minor additions** (new keys): Ignore unknown keys, only parse what we need
2. **Breaking changes** (structure changes): Version detection logic to support multiple formats
3. **Alternative formats**: Could add support for other coverage tools' JSON formats if needed

### Current Limitations Accepted

- Only supports SimpleCov (not Coverage gem, other tools)
- Assumes standard `.resultset.json` locations
- No support for merged coverage from multiple test runs (SimpleCov handles this before writing JSON)
- No support for branch coverage (SimpleCov feature not widely used yet)

## References

- Gemspec dependencies: `cov-loupe.gemspec` (`spec.add_dependency` entries)
- JSON parsing: `lib/cov_loupe/model.rb` (`CoverageModel#load_coverage_data`)
- Coverage calculations: `lib/cov_loupe/util.rb` (`CovUtil.summary`, `.uncovered`, `.detailed`)
- Resultset discovery: `lib/cov_loupe/util.rb` (`CovUtil::RESULTSET_CANDIDATES` and helpers)
- SimpleCov format documentation: https://github.com/simplecov-ruby/simplecov
- Development usage: Uses SimpleCov in `spec/spec_helper.rb` to test itself
