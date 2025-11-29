# frozen_string_literal: true

require_relative 'option_normalizers'
require_relative 'version'

module SimpleCovMcp
  class OptionParserBuilder
    HORIZONTAL_RULE = '-' * 79
    SUBCOMMANDS = %w[list summary raw uncovered detailed totals validate version].freeze

    attr_reader :config

    def initialize(config)
      @config = config
    end

    def build_option_parser
      require 'optparse'
      OptionParser.new do |o|
        configure_banner(o)
        define_subcommands_help(o)
        define_options(o)
        define_examples(o)
        add_help_handler(o)
      end
    end

    private

    def configure_banner(o)
      o.banner = <<~BANNER
        #{HORIZONTAL_RULE}
        Usage:      simplecov-mcp [options] [subcommand] [args]
        Repository: https://github.com/keithrbennett/simplecov-mcp
        Version:    #{SimpleCovMcp::VERSION}
        #{HORIZONTAL_RULE}

        BANNER
    end

    def define_subcommands_help(o)
      o.separator <<~SUBCOMMANDS
        Subcommands:
          list                    Show files coverage (default: table, or use --format)
          summary <path>          Show covered/total/% for a file
          raw <path>              Show the SimpleCov 'lines' array
          uncovered <path>        Show uncovered lines and a summary
          detailed <path>         Show per-line rows with hits/covered
          totals                  Show aggregated line totals and average %
          validate <file>         Evaluate coverage policy from file (exit 0=pass, 1=fail, 2=error)
          validate -e <code>      Evaluate coverage policy from code string
          version                 Show version information

        SUBCOMMANDS
    end

    def define_options(o)
      o.separator 'Options:'
      o.on('-r', '--resultset PATH', String,
        'Path or directory that contains .resultset.json (default: coverage/.resultset.json)') \
      do |v|
        config.resultset = v
      end
      o.on('-R', '--root PATH', String, 'Project root (default: .)') { |v| config.root = v }
      o.on('-f', '--format FORMAT', String,
        'Output format: t[able]|j[son]|pretty-json|y[aml]|a[wesome-print] (default: table)') do |v|
        config.format = normalize_format(v)
      end
      o.on('-o', '--sort-order ORDER', String,
        'Sort order for list: a[scending]|d[escending] (default ascending)') do |v|
        config.sort_order = normalize_sort_order(v)
      end
      o.on('-s', '--source MODE', String,
        'Source display: f[ull]|u[ncovered]') do |v|
        config.source_mode = normalize_source_mode(v)
      end
      o.on('-c', '--context-lines N', Integer,
        'Context lines around uncovered lines (default: 2)') do |v|
        config.source_context = v
      end
      o.on('--color', 'Enable ANSI colors for source output') { config.color = true }
      o.on('--no-color', 'Disable ANSI colors') { config.color = false }
      o.on('-S', '--staleness MODE', String,
        'Staleness detection: o[ff]|e[rror] (default off)') do |v|
        config.staleness = normalize_staleness(v)
      end
      o.on('-g', '--tracked-globs x,y,z', Array,
        'Globs for filtering files (list/totals subcommands)') do |v|
        config.tracked_globs = v
      end
      o.on('-l', '--log-file PATH', String,
        'Log file path (default ./simplecov_mcp.log, use stdout/stderr for streams)') do |v|
        config.log_file = v
      end
      o.on('--error-mode MODE', String,
        'Error handling mode: o[ff]|l[og]|d[ebug] (default log). ' \
        'off (silent), log (log errors to file), debug (verbose with backtraces)') do |v|
        config.error_mode = normalize_error_mode(v)
      end
      o.on('--force-cli', 'Force CLI mode (useful in scripts where auto-detection fails)') do
        # This flag is mainly for mode detection - no action needed here
      end
      o.on('-v', '--version', 'Show version information and exit') do
        config.show_version = true
      end
    end

    def define_examples(o)
      o.separator <<~EXAMPLES

        Examples:
          simplecov-mcp --resultset coverage list
          simplecov-mcp --format json --resultset coverage summary lib/foo.rb
          simplecov-mcp --source uncovered --context-lines 2 uncovered lib/foo.rb
          simplecov-mcp totals --format json
        EXAMPLES
    end

    def add_help_handler(o)
      o.on('-h', '--help', 'Show help') do
        puts o
        gem_root = File.expand_path('../..', __dir__)
        puts "\nFor more detailed help, consult README.md and docs/user/**/*.md"
        puts "in the installed gem at: #{gem_root}"
        exit 0
      end
    end

    def normalize_sort_order(v)
      OptionNormalizers.normalize_sort_order(v, strict: true)
    end

    def normalize_source_mode(v)
      OptionNormalizers.normalize_source_mode(v, strict: true)
    end

    def normalize_staleness(v)
      OptionNormalizers.normalize_staleness(v, strict: true)
    end

    def normalize_error_mode(v)
      OptionNormalizers.normalize_error_mode(v, strict: true)
    end

    def normalize_format(v)
      OptionNormalizers.normalize_format(v, strict: true)
    end
  end
end
