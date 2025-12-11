# frozen_string_literal: true

require_relative 'option_normalizers'
require_relative 'version'

module CovLoupe
  class OptionParserBuilder
    HORIZONTAL_RULE = '-' * 79
    SUBCOMMANDS = %w[list summary raw uncovered detailed totals validate version].freeze

    attr_reader :config

    def initialize(config)
      @config = config
    end

    def build_option_parser
      require 'optparse'
      OptionParser.new do |parser|
        configure_banner(parser)
        define_subcommands_help(parser)
        define_options(parser)
        define_examples(parser)
      end
    end

    private def configure_banner(parser)
      parser.banner = <<~BANNER
        #{HORIZONTAL_RULE}
        Usage:      cov-loupe [options] [subcommand] [args]  (default subcommand: list)
        Repository: https://github.com/keithrbennett/cov-loupe
        Version:    #{CovLoupe::VERSION}
        #{HORIZONTAL_RULE}

        BANNER
    end

    private def define_subcommands_help(parser)
      parser.separator <<~SUBCOMMANDS
        Subcommands:
          detailed <path>          Show per-line rows with hits/covered
          list                     Show files coverage (default: table, or use --format)
          raw <path>               Show the SimpleCov 'lines' array
          summary <path>           Show covered/total/% for a file
          totals                   Show aggregated line totals and average %
          uncovered <path>         Show uncovered lines and a summary
          validate <file>          Evaluate coverage policy from file (exit 0=pass, 1=fail, 2=error)
          validate -e <code>       Evaluate coverage policy from code string
          version                  Show version information

        SUBCOMMANDS
    end

    private def define_options(parser)
      parser.separator 'Options:'
      parser.on('-r', '--resultset PATH', String,
        'Path or directory that contains .resultset.json (default: coverage/.resultset.json)') \
      do |value|
        config.resultset = value
      end
      parser.on('-R', '--root PATH', String, 'Project root (default: .)') do |value|
        config.root = value
      end
      parser.on(
        '-f', '--format FORMAT', String,
        'Output format: t[able]|j[son]|pretty-json|y[aml]|a[wesome-print] (default: table)'
      ) do |value|
        config.format = normalize_format(value)
      end
      parser.on('-o', '--sort-order ORDER', String,
        'Sort order for list: a[scending]|d[escending] (default descending)') do |value|
        config.sort_order = normalize_sort_order(value)
      end
      parser.on('-s', '--source MODE', String,
        'Source display: f[ull]|u[ncovered]') do |value|
        config.source_mode = normalize_source_mode(value)
      end
      parser.on('-c', '--context-lines N', Integer,
        'Context lines around uncovered lines (non-negative, default: 2)') do |value|
        config.source_context = value
      end
      parser.on('--color', 'Enable ANSI colors for source output') { config.color = true }
      parser.on('--no-color', 'Disable ANSI colors') { config.color = false }
      parser.on('-S', '--[no-]raise-on-stale',
        'Raise error if coverage is stale (default false). Use --raise-on-stale for true, ' \
        '--no-raise-on-stale for false.') do |value|
        config.raise_on_stale = value
      end
      parser.on('-g', '--tracked-globs x,y,z', Array,
        'Globs for filtering files (list/totals subcommands)') do |value|
        config.tracked_globs = value
      end
      parser.on('-h', '--help', 'Show help') do
        puts parser
        gem_root = File.expand_path('../..', __dir__)
        puts "\nFor more detailed help, consult README.md and docs/user/**/*.md"
        puts "in the installed gem at: #{gem_root}"
        exit 0
      end
      parser.on('-l', '--log-file PATH', String,
        'Log file path (default ./cov_loupe.log, use stdout/stderr for streams)') do |value|
        config.log_file = value
      end
      parser.on('--error-mode MODE', String,
        'Error handling mode: o[ff]|l[og]|d[ebug] (default log). ' \
        'off (silent), log (log errors to file), debug (verbose with backtraces)') do |value|
        config.error_mode = normalize_error_mode(value)
      end
      parser.on('--force-cli', 'Force CLI mode (useful in scripts where auto-detection fails)') do
        # This flag is mainly for mode detection - no action needed here
      end
      parser.on('-v', '--version', 'Show version information and exit') do
        config.show_version = true
      end
    end

    private def define_examples(parser)
      parser.separator <<~EXAMPLES

        Examples:
          cov-loupe --resultset coverage list
          cov-loupe --format json --resultset coverage summary lib/foo.rb
          cov-loupe --source uncovered --context-lines 2 uncovered lib/foo.rb
          cov-loupe totals --format json
        EXAMPLES
    end

    private def normalize_sort_order(value)
      OptionNormalizers.normalize_sort_order(value, strict: true)
    end

    private def normalize_source_mode(value)
      OptionNormalizers.normalize_source_mode(value, strict: true)
    end

    private def normalize_error_mode(value)
      OptionNormalizers.normalize_error_mode(value, strict: true)
    end

    private def normalize_format(value)
      OptionNormalizers.normalize_format(value, strict: true)
    end
  end
end
