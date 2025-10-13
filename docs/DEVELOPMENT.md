# Development Guide

> **Note:** Commands like `simplecov-mcp` assume the gem is installed globally. If not, substitute `bundle exec exe/simplecov-mcp`.

## Setup

```sh
git clone https://github.com/keithrbennett/simplecov-mcp.git
cd simplecov-mcp
bundle install
gem build simplecov-mcp.gemspec && gem install simplecov-mcp-*.gem  # optional
simplecov-mcp version  # verify it works
```

## Running Tests

```sh
bundle exec rspec
```

## Project-Specific Patterns

**All Ruby files start with:**
```ruby
# frozen_string_literal: true
```

**Error handling uses custom exceptions from `errors.rb`:**
```ruby
rescue Errno::ENOENT => e
  raise FileError.new("Coverage data not found: #{e.message}")
rescue JSON::ParserError => e
  raise CoverageDataError.new("Invalid coverage format: #{e.message}")
```

**MCP tools extend `BaseTool` and follow this pattern:**
```ruby
module SimpleCovMcp::Tools
  class MyTool < BaseTool
    def self.name = 'my_tool'
    def self.description = 'What this tool does'
    
    def self.call(path:, root: '.', resultset: nil, stale: 'off', error_mode: 'on', **)
      model = CoverageModel.new(root: root, resultset: resultset, staleness: stale)
      data = model.my_method_for(path)
      respond_json(model.relativize(data), name: 'my_tool_output.json')
    rescue => e
      handle_mcp_error(e, name, error_mode: error_mode.to_sym)
    end
  end
end
```

**Use test fixtures for consistency:**
```ruby
let(:project_root) { (FIXTURES_DIR / 'project1').to_s }
let(:coverage_dir) { File.join(project_root, 'coverage') }
```

**MCP tool tests need setup:**
```ruby
let(:server_context) { instance_double('ServerContext').as_null_object }
before { setup_mcp_response_stub }
```

## Adding Features

**CLI commands:** Add to `SUBCOMMANDS` in `cli.rb`, implement handler, add tests

**MCP tools:** Create `*_tool.rb` in `lib/simplecov_mcp/tools/`, register in `mcp_server.rb`

**Coverage features:** Add to `CoverageModel` in `model.rb` or `CovUtil` in `util.rb`

## Troubleshooting

**RVM + Codex macOS:** Currently not possible for Codex to run rspec when running on macOS with rvm-managed rubies - see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

**MCP server testing:**
```sh
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"version_tool","arguments":{}}}' | simplecov-mcp
```

