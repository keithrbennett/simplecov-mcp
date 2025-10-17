# frozen_string_literal: true

require_relative 'lib/simplecov_mcp/version'

Gem::Specification.new do |spec|
  spec.name          = 'simplecov-mcp'
  spec.version       = SimpleCovMcp::VERSION
  spec.authors       = ['Keith R. Bennett']
  spec.email         = ['keithrbennett@gmail.com']

  spec.summary       = 'MCP server + CLI for SimpleCov coverage data'
  spec.description   = 'Provides an MCP (Model Context Protocol) server and a CLI to inspect ' \
                       'SimpleCov coverage, including per-file summaries and uncovered lines.'
  spec.license       = 'MIT'

  spec.homepage      = 'https://github.com/keithrbennett/simplecov-mcp'
  spec.required_ruby_version = '>= 3.2'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['lib/**/*', 'README.md', 'docs/**/*.md', 'LICENSE*', 'exe/*', 'spec/**/*']
  end
  spec.bindir        = 'exe'
  spec.executables   = ['simplecov-mcp']
  spec.require_paths = ['lib']

  # Runtime deps (stdlib: json, time, pathname)
  spec.add_dependency 'mcp', '~> 0.3'
  spec.add_dependency 'simplecov', '>= 0.21', '< 1.0'
end
