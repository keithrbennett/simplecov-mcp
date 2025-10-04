# frozen_string_literal: true

module SimpleCovMcp
  class CoverageCLI
    SUBCOMMANDS = %w[list summary raw uncovered detailed version].freeze
    HORIZONTAL_RULE = '-' * 79

      # Initialize CLI for pure CLI usage only.
      # Always runs as CLI, no mode detection needed.
    def initialize(error_handler: nil)
      @root = '.'
      @resultset = nil
      @json = false
      @sort_order = 'ascending'
      @cmd = nil
      @cmd_args = []
      @source_mode = nil   # nil, 'full', or 'uncovered'
      @source_context = 2  # lines of context for uncovered mode
      @color = STDOUT.tty?
      @error_mode = :on
      @custom_error_handler = error_handler  # Store custom handler if provided
      @error_handler = nil  # Will be created after parsing options
      @stale_mode = 'off'
      @tracked_globs = nil
      @log_file = nil
      @success_predicate = nil
    end

    def run(argv)
      # Prepend environment options to command line arguments
      full_argv = parse_env_opts + argv
      # Pre-scan for error-mode to ensure early errors are logged with correct verbosity
      pre_scan_error_mode(full_argv)
      parse_options!(full_argv)

      # Create error handler AFTER parsing options to respect user's --error-mode choice
      ensure_error_handler

      # Set global log file if specified
      SimpleCovMcp.log_file = @log_file if @log_file

      # If success predicate specified, run it and exit
      if @success_predicate
        run_success_predicate
        return
      end

      if @cmd
        run_subcommand(@cmd, @cmd_args)
      else
        show_default_report(sort_order: @sort_order)
      end
    rescue OptionParser::ParseError => e
      # Handle any option parsing errors (invalid option/argument) without relying on
      # @error_handler, which is not guaranteed to be initialized yet.
      handle_option_parser_error(e, argv: full_argv)
    rescue SimpleCovMcp::Error => e
      handle_user_facing_error(e)
    rescue => e
      @error_handler.handle_error(e, context: 'CLI execution')
    end

    def show_default_report(sort_order: :ascending, output: $stdout)
      model = CoverageModel.new(root: @root, resultset: @resultset, staleness: @stale_mode, tracked_globs: @tracked_globs)
      rows = model.all_files(sort_order: sort_order, check_stale: (@stale_mode == 'error'), tracked_globs: @tracked_globs)

      if @json
        files = model.relativize(rows)
        total = files.length
        stale_count = files.count { |f| f['stale'] }
        ok_count = total - stale_count
        output.puts JSON.pretty_generate({ files: files, counts: { total: total, ok: ok_count, stale: stale_count } })
        return
      end

      file_summaries = model.relativize(rows)
      # Delegate to model for consistent formatting and avoid duplicate logic
      output.puts model.format_table(file_summaries, sort_order: sort_order, check_stale: (@stale_mode == 'error'), tracked_globs: @tracked_globs)
    end

      private

    def parse_options!(argv)
      require 'optparse'
      extract_subcommand!(argv)
      build_option_parser.parse!(argv)
      @cmd_args = argv
    end

    def extract_subcommand!(argv)
      return if argv.empty?

      first_arg = argv[0]

      # If it's a flag/option, no subcommand
      return if first_arg.start_with?('-')

      # If it's a valid subcommand, extract it
      if SUBCOMMANDS.include?(first_arg)
        @cmd = argv.shift
      else
        # It's not a flag and not a valid subcommand - likely a typo
        raise UsageError.new("Unknown subcommand: '#{first_arg}'. Valid subcommands: #{SUBCOMMANDS.join(', ')}")
      end
    end

    def ensure_error_handler
      @error_handler ||= @custom_error_handler || ErrorHandlerFactory.for_cli(error_mode: @error_mode)
    end

    def parse_env_opts
      require 'shellwords'
      opts_string = ENV['SIMPLECOV_MCP_OPTS']
      return [] unless opts_string && !opts_string.empty?

      begin
        Shellwords.split(opts_string)
      rescue ArgumentError => e
        raise SimpleCovMcp::ConfigurationError, "Invalid SIMPLECOV_MCP_OPTS format: #{e.message}"
      end
    end

    def pre_scan_error_mode(argv)
      # Quick scan for --error-mode to ensure early errors are logged correctly
      argv.each_with_index do |arg, i|
        if arg == '--error-mode' && argv[i + 1]
          @error_mode = normalize_error_mode(argv[i + 1])
          break
        elsif arg.start_with?('--error-mode=')
          value = arg.split('=', 2)[1]
          @error_mode = normalize_error_mode(value) if value
          break
        end
      end
    rescue StandardError
      # Ignore errors during pre-scan; they'll be caught during actual parsing
    end

    def build_option_parser
      OptionParser.new do |o|
        configure_banner(o)
        define_subcommands_help(o)
        define_options(o)
        define_examples(o)
        add_help_handler(o)
      end
    end

    def configure_banner(o)
      o.banner = <<~BANNER
          #{HORIZONTAL_RULE}
          Usage:      simplecov-mcp [subcommand] [options] [args]
          Repository: https://github.com/keithrbennett/simplecov-mcp
          Version:    #{VERSION}
          #{HORIZONTAL_RULE}

        BANNER
      # o.banner = 'Usage: simplecov-mcp [subcommand] [options] [args]'
      # o.separator ''
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
      o.on('-r', '--resultset PATH', String, 'Path or directory that contains .resultset.json (default: coverage/.resultset.json)') { |v| @resultset = v }
      o.on('-R', '--root PATH', String, 'Project root (default: .)') { |v| @root = v }
      o.on('-j', '--json', 'Output JSON for machine consumption') { @json = true }
      o.on('-o', '--sort-order ORDER', String,
           'Sort order for list: a[scending]|d[escending] (default ascending)') do |v|
        @sort_order = normalize_sort_order(v)
      end
      o.on('-s', '--source[=MODE]', String,
           'Include source (MODE: f[ull]|u[ncovered]; default full)') do |v|
        @source_mode = normalize_source_mode(v)
      end
      o.on('-c', '--source-context N', Integer, 'For --source=uncovered, show N context lines (default: 2)') { |v| @source_context = v }
      o.on('--color', 'Enable ANSI colors for source output') { @color = true }
      o.on('--no-color', 'Disable ANSI colors') { @color = false }
      o.on('-S', '--stale MODE', String,
           'Staleness mode: o[ff]|e[rror] (default off)') do |v|
        @stale_mode = normalize_stale_mode(v)
      end
      o.on('-g', '--tracked-globs x,y,z', Array, 'Globs for filtering files (list subcommand)') { |v| @tracked_globs = v }
      o.on('-l', '--log-file PATH', String, 'Log file path (default ./simplecov_mcp.log, use - to disable)') { |v| @log_file = v }
      o.on('--error-mode MODE', String,
           'Error handling mode: off|on|t[race] (default on)') do |v|
        @error_mode = normalize_error_mode(v)
        # Don't create error handler here - it will be created after all options are parsed
      end
      o.on('--force-cli', 'Force CLI mode (useful in scripts where auto-detection fails)') do
        # This flag is mainly for mode detection - no action needed here
      end
      o.on('--success-predicate FILE', String, 'Ruby file returning callable; exits 0 if truthy, 1 if falsy') { |v| @success_predicate = v }
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

    def run_subcommand(cmd, args)
      model = CoverageModel.new(root: @root, resultset: @resultset, staleness: @stale_mode)
      case cmd
      when 'list'      then handle_list(model)
      when 'summary'   then handle_summary(model, args)
      when 'raw'       then handle_raw(model, args)
      when 'uncovered' then handle_uncovered(model, args)
      when 'detailed'  then handle_detailed(model, args)
      when 'version'   then handle_version
      else raise UsageError.for_subcommand('list | summary <path> | raw <path> | uncovered <path> | detailed <path> | version')
      end
    rescue SimpleCovMcp::Error => e
      handle_user_facing_error(e)
    rescue => e
      @error_handler.handle_error(e, context: "subcommand '#{cmd}'")
    end


    def format_detailed_rows(rows)
      # Simple aligned columns: line, hits, covered
      out = []
      out << sprintf('%6s  %6s  %7s', 'Line', 'Hits', 'Covered')
      out << sprintf('%6s  %6s  %7s', '-----', '----', '-------')
      rows.each do |r|
        out << sprintf('%6d  %6d  %7s', r['line'], r['hits'], r['covered'] ? 'yes' : 'no')
      end
      out.join("\n")
    end

    def handle_list(model)
      show_default_report(sort_order: @sort_order)
    end

    def handle_version
      if @json
        puts JSON.pretty_generate({ version: SimpleCovMcp::VERSION })
      else
        puts "SimpleCovMcp version #{SimpleCovMcp::VERSION}"
      end
    end

    def handle_summary(model, args)
      handle_with_path(args, 'summary') do |path|
        data = model.summary_for(path)
        break if emit_json_with_optional_source(data, model, path)
        rel = model.relativize(data)['file']
        s = data['summary']
        printf "%8.2f%%  %6d/%-6d  %s\n\n", s['pct'], s['covered'], s['total'], rel
        print_source_for(model, path) if @source_mode
      end
    end

    def handle_raw(model, args)
      handle_with_path(args, 'raw') do |path|
        data = model.raw_for(path)
        break if maybe_output_json(data, model)
        rel = model.relativize(data)['file']
        puts "File: #{rel}"
        puts data['lines'].inspect
      end
    end

    def handle_uncovered(model, args)
      handle_with_path(args, 'uncovered') do |path|
        data = model.uncovered_for(path)
        break if emit_json_with_optional_source(data, model, path)
        rel = model.relativize(data)['file']
        puts "File:            #{rel}"
        puts "Uncovered lines: #{data['uncovered'].join(', ')}"
        s = data['summary']
        printf "Summary:      %8.2f%%  %6d/%-6d\n\n", s['pct'], s['covered'], s['total']
        print_source_for(model, path) if @source_mode
      end
    end

    def handle_detailed(model, args)
      handle_with_path(args, 'detailed') do |path|
        data = model.detailed_for(path)
        break if emit_json_with_optional_source(data, model, path)
        rel = model.relativize(data)['file']
        puts "File: #{rel}"
        puts format_detailed_rows(data['lines'])
        print_source_for(model, path) if @source_mode
      end
    end

    def handle_with_path(args, name)
      path = args.shift or raise UsageError.for_subcommand("#{name} <path>")
      yield(path)
    rescue Errno::ENOENT => e
      raise FileNotFoundError.new("File not found: #{path}")
    rescue Errno::EACCES => e
      raise FilePermissionError.new("Permission denied: #{path}")
    end

    def maybe_output_json(obj, model)
      return false unless @json
      puts JSON.pretty_generate(model.relativize(obj))
      true
    end

      # Emits JSON for a file-oriented command, optionally including source rows.
      #
      # @param data [Hash] Command result including a 'file' key (absolute path).
      # @param model [SimpleCovMcp::CoverageModel] Used to fetch raw lines when
      #   embedding source rows.
      # @param path [String] Original user-provided path for the file.
      # @return [Boolean] True if JSON was emitted; false otherwise.
      # @example With --json and --source
      #   emit_json_with_optional_source({ 'file' => '/abs/foo.rb', 'summary' => {...} }, model, 'lib/foo.rb')
      #   # => prints JSON including a 'source' field and returns true
    def emit_json_with_optional_source(data, model, path)
      return false unless @json
      relativized = model.relativize(data)
      if @source_mode
        payload = relativized.merge('source' => build_source_payload(model, path))
        puts JSON.pretty_generate(payload)
      else
        puts JSON.pretty_generate(relativized)
      end
      true
    end

    def print_source_for(model, path)
      raw = fetch_raw(model, path)
      unless raw
        puts '[source not available]'
        return
      end

      abs = raw['file']
      lines_cov = raw['lines']
      src = File.file?(abs) ? File.readlines(abs, chomp: true) : nil
      unless src
        puts '[source not available]'
        return
      end
      begin
        rows = build_source_rows(src, lines_cov, mode: @source_mode, context: @source_context)
        puts format_source_rows(rows)
      rescue StandardError
        # If any unexpected formatting/indexing error occurs, avoid crashing the CLI
        # and fall back to a neutral message rather than raising.
        puts '[source not available]'
      end
    end

    def build_source_payload(model, path)
      raw = fetch_raw(model, path)
      return nil unless raw

      abs = raw['file']
      lines_cov = raw['lines']
      src = File.file?(abs) ? File.readlines(abs, chomp: true) : nil
      return nil unless src
      build_source_rows(src, lines_cov, mode: @source_mode, context: @source_context)
    end

    def fetch_raw(model, path)
      @raw_cache ||= {}
      return @raw_cache[path] if @raw_cache.key?(path)

      raw = model.raw_for(path)
      @raw_cache[path] = raw
    rescue StandardError
      nil
    end

    def build_source_rows(src_lines, cov_lines, mode:, context: 2)
      # Normalize inputs defensively to avoid type errors in formatting
      coverage_lines = cov_lines || []
      context_line_count = context.to_i rescue 2
      context_line_count = 0 if context_line_count.negative?

      n = src_lines.length
      include_line = Array.new(n, mode == 'full')
      if mode == 'uncovered'
        misses = []
        coverage_lines.each_with_index do |hits, i|
          misses << i if !hits.nil? && hits.to_i == 0
        end
        misses.each do |i|
          a = [0, i - context_line_count].max
          b = [n - 1, i + context_line_count].min
          (a..b).each { |j| include_line[j] = true }
        end
      end
      out = []
      src_lines.each_with_index do |code, i|
        next unless include_line[i]
        hits = coverage_lines[i]
        covered = hits.nil? ? nil : hits.to_i > 0
        # Use string keys consistently across CLI formatting and JSON payloads
        out << { 'line' => i + 1, 'code' => code, 'hits' => hits, 'covered' => covered }
      end
      out
    end

    def format_source_rows(rows)
      marker = ->(covered, hits) do
        case covered
        when true then colorize('✓', :green)
        when false then colorize('·', :red)
        else colorize(' ', :dim)
        end
      end
      lines = []
      lines << sprintf('%6s  %2s | %s', 'Line', ' ', 'Source')
      lines << sprintf('%6s  %2s-+-%s', '------', '--', '-' * 60)
      rows.each do |r|
        m = marker.call(r['covered'], r['hits'])
        lines << sprintf('%6d  %2s | %s', r['line'], m, r['code'])
      end
      lines.join("\n")
    end

    def colorize(text, color)
      return text unless @color
      codes = { green: 32, red: 31, dim: 2 }
      code = codes[color] || 0
      "\e[#{code}m#{text}\e[0m"
    end

    def handle_option_parser_error(error, argv: [])
      message = error.message.to_s
      # Suggest a subcommand when an invalid option matches a known subcommand
      option = message.match(/invalid option: (.+)/)[1] rescue nil
      if option && option.start_with?('--') && SUBCOMMANDS.include?(option[2..-1])
        subcommand = option[2..-1]
        warn "Error: '#{option}' is not a valid option. Did you mean the '#{subcommand}' subcommand?"
        warn "Try: simplecov-mcp #{subcommand} [args]"
      else
        # Generic message from OptionParser
        warn "Error: #{message}"
        # Attempt to derive a helpful hint for enumerated options
        if (hint = build_enum_value_hint(argv))
          warn hint
        end
      end
      warn "Run 'simplecov-mcp --help' for usage information."
      exit 1
    end

    def build_enum_value_hint(argv)
      rules = enumerated_option_rules
      tokens = Array(argv)
      rules.each do |rule|
        switches = rule[:switches]
        allowed = rule[:values]
        display = rule[:display] || allowed.join(', ')
        preferred = switches.find { |s| s.start_with?('--') } || switches.first
        tokens.each_with_index do |tok, i|
          # --opt=value form
          if tok.start_with?(preferred + '=') || switches.any? { |s| tok.start_with?(s + '=') }
            sw = switches.find { |s| tok.start_with?(s + '=') } || preferred
            val = tok.split('=', 2)[1]
            return "Valid values for #{sw}: #{display}" if val && !allowed.include?(val)
          end
          # --opt value or -o value form
          if switches.include?(tok)
            val = tokens[i + 1]
            # If missing value, provide hint; if present and invalid, also hint
            if val.nil? || val.start_with?('-') || !allowed.include?(val)
              return "Valid values for #{preferred}: #{display}"
            end
          end
        end
      end
      nil
    end

    def normalize_sort_order(v)
      map = {
        'a' => 'ascending', 'ascending' => 'ascending',
        'd' => 'descending', 'descending' => 'descending'
      }
      v = v.to_s.downcase
      map[v] or raise OptionParser::InvalidArgument, "invalid argument: #{v}"
    end

    def normalize_source_mode(v)
      return 'full' if v.nil? || v == ''
      map = { 'full' => 'full', 'f' => 'full', 'uncovered' => 'uncovered', 'u' => 'uncovered' }
      key = v.to_s.downcase
      map[key] or raise OptionParser::InvalidArgument, "invalid argument: #{v}"
    end

    def normalize_stale_mode(v)
      map = { 'off' => 'off', 'o' => 'off', 'error' => 'error', 'e' => 'error' }
      key = v.to_s.downcase
      map[key] or raise OptionParser::InvalidArgument, "invalid argument: #{v}"
    end

    def normalize_error_mode(v)
      map = {
        'off' => :off,
        'on' => :on,
        'on_with_trace' => :on_with_trace, 'with_trace' => :on_with_trace, 'trace' => :on_with_trace, 't' => :on_with_trace
      }
      key = v.to_s.downcase
      map[key] or raise OptionParser::InvalidArgument, "invalid argument: #{v}"
    end

    def enumerated_option_rules
      [
        { switches: ['-S', '--stale'], values: %w[off o error e], display: 'o[ff]|e[rror]' },
        { switches: ['-s', '--source'], values: %w[full f uncovered u], display: 'f[ull]|u[ncovered]' },
        { switches: ['--error-mode'], values: %w[off on on_with_trace with_trace trace t], display: 'off|on|t[race]' },
        { switches: ['-o', '--sort-order'], values: %w[a d ascending descending], display: 'a[scending]|d[escending]' }
      ]
    end

    def run_success_predicate
      predicate = load_success_predicate(@success_predicate)
      model = CoverageModel.new(root: @root, resultset: @resultset, staleness: @stale_mode, tracked_globs: @tracked_globs)

      result = predicate.call(model)
      exit(result ? 0 : 1)
    rescue => e
      warn "Success predicate error: #{e.message}"
      warn e.backtrace.first(5).join("\n") if @error_mode == :on_with_trace
      exit 2  # Exit code 2 for predicate errors
    end

    def load_success_predicate(path)
      unless File.exist?(path)
        raise "Success predicate file not found: #{path}"
      end

      content = File.read(path)
      predicate = eval(content, binding, path)

      unless predicate.respond_to?(:call)
        raise "Success predicate must be callable (lambda, proc, or object with #call method)"
      end

      predicate
    rescue SyntaxError => e
      raise "Syntax error in success predicate file: #{e.message}"
    end

    def handle_user_facing_error(error)
      # Ensure error handler exists (may not be initialized if error occurs during option parsing)
      ensure_error_handler
      # Log the error if error_mode allows it
      @error_handler.handle_error(error, context: 'CLI', reraise: false)
      # Show user-friendly message
      warn error.user_friendly_message
      exit 1
    end
  end
end
