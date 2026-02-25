[Back to main README](../../index.md)

---
marp: true
theme: default
class: lead
paginate: true
backgroundColor: #fff
color: #333
---

# CovLoupe
### MCP Server, CLI, and Library for SimpleCov Ruby Test Coverage 

- Keith Bennett
- First presented to PhRUG (Philippines Ruby User Group), 2025-10-01

---

## What is cov-loupe?

A **three-in-one** gem that makes SimpleCov coverage data accessible to:

- 🤖 **AI agents** via Model Context Protocol (MCP)
- 💻 **Command line** via its command line interface
- 📚 **Ruby scripts and applications** as a library

**Lazy dependency** on SimpleCov - single-suite resultsets avoid loading it; multi-suite files trigger a merge via SimpleCov’s combine helpers.

What is it *not*? It is not a replacement for SimpleCov's generated web presentation of the coverage data.


This code base requires a Ruby version >= 3.2.0, because this is required by the mcp gem it uses.

---

## High Level Objectives

- Query coverage programmatically
- Integrate with AI tools
- Automate coverage analysis
- Focus on specific files/patterns

---

## Key Features

- **Lazy SimpleCov dependency** - only loaded when multi-suite resultsets need merging
- **Flexible resultset location** - via CLI flags, passed parameter, or env var
- **Staleness detection** - warns or optionally errors when files newer than coverage
- **JSON output** - perfect for jq, scripts, CI/CD
- **Source code integration** - show uncovered lines with or without context
- **Colored output** - readable terminal display

---

## Demo 1: MCP Server Mode
### AI Coverage Assistant

```bash
# Test the MCP server manually
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"coverage_summary_tool","arguments":{"path":"lib/cov_loupe/model.rb"}}}' | cov-loupe -m mcp
```

**What AI agents can do:**
- Analyze coverage gaps
- Suggest testing priorities  
- Generate ad-hoc coverage reports

---

## MCP Tools (Functions) Available

| Tool                      | Purpose                    | Example CLI Command                                  |
|---------------------------|----------------------------|------------------------------------------------------|
| `list_tool` | Project-wide coverage data | `cov-loupe list`                                 |
| `coverage_detailed_tool`  | Per-line hit counts        | `cov-loupe detailed lib/cov_loupe/model.rb`  |
| `coverage_raw_tool`       | Raw SimpleCov lines array  | `cov-loupe raw lib/cov_loupe/model.rb`       |
| `coverage_summary_tool`   | Get coverage % for a file  | `cov-loupe summary lib/cov_loupe/model.rb`   |
| `coverage_table_tool`     | Formatted coverage table   | `cov-loupe list`                                 |
| `coverage_totals_tool`    | Aggregated line totals     | `cov-loupe totals`                               |
| `validate_tool`           | Validate coverage policy   | `cov-loupe validate coverage_policy.rb`          |
| `help_tool`               | Tool usage guidance        | `cov-loupe --help`                               |
| `uncovered_lines_tool`    | Find missing test coverage | `cov-loupe uncovered lib/cov_loupe/cli.rb`   |
| `version_tool`            | Display version info       | `cov-loupe version`                              |

---

## Demo 2: CLI Tool
### 

```bash
# Show all files, best coverage first
cov-loupe
# or use the 'l' abbreviation for 'list'
cov-loupe l

# Focus on a specific file ('summary' or 's')
cov-loupe summary lib/cov_loupe/cli.rb
cov-loupe s lib/cov_loupe/cli.rb

# Find untested lines with source context ('uncovered' or 'u')
cov-loupe uncovered lib/cov_loupe/cli.rb --source=uncovered --context-lines 3
cov-loupe u lib/cov_loupe/cli.rb --source=uncovered --context-lines 3

# JSON for scripts
cov-loupe -fJ | jq '.files[] | select(.percentage < 80)'
cov-loupe -fJl | jq '.files[] | select(.percentage < 80)'
```

---

## Demo 2: CLI Tool (cont'd.)

```bash
# Custom resultset location
cov-loupe --resultset coverage-all/

# Sort by highest coverage
cov-loupe --sort-order d

# Staleness checking (file newer than coverage?)
cov-loupe --raise-on-stale true

# Track new files missing from coverage
cov-loupe --tracked-globs "lib/**/tools/*.rb"
```

---

## Demo 3: Ruby Library
### Programmatic Integration

```ruby
require 'cov_loupe'

model = CovLoupe::CoverageModel.new

# Get project overview
files = model.list
puts "Lowest coverage: #{files.first['percentage']}%"

# Focus on specific concerns
uncovered = model.uncovered_for("lib/wifi-wand/models/ubuntu_model.rb")
puts "Uncovered hash's keys: #{uncovered.keys.inspect}" 
puts "Missing lines: #{uncovered['uncovered'].inspect}"

# Output:
# Lowest coverage: 17.0%
# Uncovered hash's keys: ["file", "uncovered", "summary"]
# Missing lines: [13, 17, 21,...200, 203]
```

---

## Custom Threshold Git Pre-Commit Hook

```ruby
require 'cov_loupe'

files = CovLoupe::CoverageModel.new.list
critical, other = files.partition { |f| f['file'].include?('/lib/critical/') }

fails = critical.select { |f| f['percentage'] < 100.0 } + 
        other.select { |f| f['percentage'] < 90.0 }

if fails.any?
  puts "❌ Coverage failures:"
  fails.each { |f| puts "  #{f['file']}: #{f['percentage']}%" }
  exit 1
else
  puts "✅ All thresholds met!"
end
```

---

## Architecture Overview

```
lib/cov_loupe
├── base_tool.rb
├── cli.rb
├── error_handler_factory.rb
├── error_handler.rb
├── errors.rb
├── mcp_server.rb
├── model.rb
├── path_relativizer.rb
├── staleness_checker.rb
├── version.rb
├── tools
│ ├── list_tool.rb
│ ├── coverage_detailed_tool.rb
│ ├── coverage_raw_tool.rb
│ ├── coverage_summary_tool.rb
│ ├── coverage_table_tool.rb
│ ├── coverage_totals_tool.rb
│ ├── validate_tool.rb
│ ├── help_tool.rb
│ ├── uncovered_lines_tool.rb
│ └── version_tool.rb
└── util.rb
```

**Clean separation:** CLI ↔ Model ↔ MCP Tools

---

## MCP Plumbing - the MCP Gem

#### BaseTool subclasses the `mcp` gem's Tool class and defines a schema (see base_tool.rb):
```ruby
class BaseTool < ::MCP::Tool
  # ...
end
```

* [BaseTool source](https://github.com/keithrbennett/cov-loupe/blob/main/lib/cov_loupe/base_tool.rb)
* [BaseTool subclass source](https://github.com/keithrbennett/cov-loupe/blob/main/lib/cov_loupe/tools/coverage_detailed_tool.rb)

The MCP tools available to the model subclass BaseTool and implement their respective tasks.

#### mcp_server.rb creates an instance of the mcp gem's Server class and runs it:

```ruby
server = ::MCP::Server.new(
  name:    'cov-loupe',
  version: CovLoupe::VERSION,
  tools:   tools
)
::MCP::Server::Transports::StdioTransport.new(server).open
```


----

## Questions?

**Demo requests:**
- Specific MCP tool usage?
- CLI workflow examples?  
- Library integration patterns?
- AI assistant setup?

**Contact:**
- GitHub issues for bugs/features
- Ruby community discussions

**Thank you!** 🙏

*Making test coverage accessible to humans and AI alike*
