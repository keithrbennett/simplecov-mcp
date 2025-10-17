# frozen_string_literal: true

require_relative 'option_normalizers'

module SimpleCovMcp
  class OptionParserBuilder
    HORIZONTAL_RULE = '-' * 79
    SUBCOMMANDS = %w[list summary raw uncovered detailed version].freeze

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
        Usage:      simplecov-mcp [subcommand] [options] [args]
        Repository: https://github.com/keithrbennett/simplecov-mcp
        Version:    #{SimpleCovMcp::VERSION}
        #{HORIZONTAL_RULE}

        BANNER
    end

    def define_subcommands_help(o)
      o.separator <<~SUBCOMMANDS
        Subcommands:
          list                    Show files coverage (table or --json)
          summary <path>          Show covered/total/% for a file
          raw <path>              Show the SimpleCov 'lines' array
          uncovered <path>        Show uncovered lines and a summary
          detailed <path>         Show per-line rows with hits/covered
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
      o.on('-j', '--json', 'Output JSON for machine consumption') { config.json = true }
      o.on('-o', '--sort-order ORDER', String,
        'Sort order for list: a[scending]|d[escending] (default ascending)') do |v|
        config.sort_order = normalize_sort_order(v)
      end
      o.on('-s', '--source[=MODE]', String,
        'Include source (MODE: f[ull]|u[ncovered]; default full)') do |v|
        config.source_mode = normalize_source_mode(v)
      end
      o.on('-c', '--source-context N', Integer,
        'For --source=uncovered, show N context lines (default: 2)') do |v|
         config.source_context = v
      end
      o.on('--color', 'Enable ANSI colors for source output') { config.color = true }
      o.on('--no-color', 'Disable ANSI colors') { config.color = false }
      o.on('-S', '--stale MODE', String,
        'Staleness mode: o[ff]|e[rror] (default off)') do |v|
        config.stale_mode = normalize_stale_mode(v)
      end
      o.on('-g', '--tracked-globs x,y,z', Array,
        'Globs for filtering files (list subcommand)') do |v|
        config.tracked_globs = v
      end
      o.on('-l', '--log-file PATH', String,
        'Log file path (default ./simplecov_mcp.log, use stdout/stderr for streams)') do |v|
        config.log_file = v
      end
      o.on('--error-mode MODE', String,
        'Error handling mode: off|on|t[trace] (default on)') do |v|
        config.error_mode = normalize_error_mode(v)
      end
      o.on('--force-cli', 'Force CLI mode (useful in scripts where auto-detection fails)') do
        # This flag is mainly for mode detection - no action needed here
      end
      o.on('--success-predicate FILE', String,
        'Ruby file returning callable; exits 0 if truthy, 1 if falsy') do |v|
        config.success_predicate = v
      end
    end

    def define_examples(o)
      o.separator <<~EXAMPLES

        Examples:
          simplecov-mcp list --resultset coverage
          simplecov-mcp summary lib/foo.rb --json --resultset coverage
          simplecov-mcp uncovered lib/foo.rb --source=uncovered --source-context 2
        EXAMPLES
    end

    def add_help_handler(o)
      o.on('-h', '--help', 'Show help') do
        puts o
        exit 0
      end
    end

    def normalize_sort_order(v)
      OptionNormalizers.normalize_sort_order(v, strict: true)
    end

    def normalize_source_mode(v)
      OptionNormalizers.normalize_source_mode(v, strict: true)
    end

    def normalize_stale_mode(v)
      OptionNormalizers.normalize_stale_mode(v, strict: true)
    end

    def normalize_error_mode(v)
      OptionNormalizers.normalize_error_mode(v, strict: true)
    end
  end
end
