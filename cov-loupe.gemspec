# frozen_string_literal: true

require_relative 'lib/cov_loupe/version'

Gem::Specification.new do |spec|
  spec.name          = 'cov-loupe'
  spec.version       = CovLoupe::VERSION
  spec.authors       = ['Keith R. Bennett']
  spec.email         = ['keithrbennett@gmail.com']

  spec.summary       = 'MCP server + CLI for SimpleCov coverage data'
  spec.description   = 'Provides an MCP (Model Context Protocol) server and a CLI to inspect ' \
                       'SimpleCov coverage, including per-file summaries and uncovered lines.'
  spec.license       = 'MIT'

  spec.homepage      = 'https://github.com/keithrbennett/cov-loupe'
  spec.required_ruby_version = '>= 3.2'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['lib/**/*', 'README.md', 'docs/**/*.md', 'LICENSE*', 'exe/*', 'spec/**/*']
  end
  spec.bindir        = 'exe'
  spec.executables   = ['cov-loupe']
  spec.require_paths = ['lib']

  # Runtime deps (stdlib: json, time, pathname, yaml)
  spec.add_dependency 'awesome_print', '~> 1.9'
  spec.add_dependency 'mcp', '~> 0.3'
  spec.add_dependency 'simplecov', '>= 0.21', '< 1.0'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.post_install_message = <<~MESSAGE
    ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    ┃ V3.0.0 - GEM RENAMED: simplecov-mcp → cov-loupe                         ┃
    ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
    ┃                                                                         ┃
    ┃ This gem has been renamed! If upgrading from simplecov-mcp:             ┃
    ┃                                                                         ┃
    ┃  • Executable: simplecov-mcp → cov-loupe                                ┃
    ┃  • Environment: SIMPLECOV_MCP_OPTS → COV_LOUPE_OPTS                     ┃
    ┃  • Log file: simplecov_mcp.log → cov_loupe.log                          ┃
    ┃  • Alias: smcp → clp (in documentation)                                 ┃
    ┃                                                                         ┃
    ┃ Module name (CovLoupe) and require path (cov_loupe) unchanged.          ┃
    ┃                                                                         ┃
    ┃ Uninstall old gem: gem uninstall simplecov-mcp                          ┃
    ┃                                                                         ┃
    ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
    ┃ V2.0.0 BREAKING CHANGES (if upgrading from v1.x)                        ┃
    ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
    ┃                                                                         ┃
    ┃  • Options must now come BEFORE subcommands                             ┃
    ┃  • --stale renamed to --staleness (-S still works)                      ┃
    ┃  • --json replaced with --format json                                   ┃
    ┃  • Error modes renamed: 'on' → 'log', 'trace' → 'debug'                 ┃
    ┃  • --success-predicate moved to 'validate' subcommand                   ┃
    ┃  • Default sort order changed from ascending to descending              ┃
    ┃                                                                         ┃
    ┃ See docs/user/V2-BREAKING-CHANGES.md for complete migration guide.      ┃
    ┃                                                                         ┃
    ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
  MESSAGE
end
