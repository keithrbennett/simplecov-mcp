# frozen_string_literal: true

module SimpleCovMcp
  class CoverageCLI
      SUBCOMMANDS = %w[list summary raw uncovered detailed version].freeze

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
      end

      def run(argv)
        # Prepend environment options to command line arguments
        full_argv = parse_env_opts + argv
        parse_options!(full_argv)

        # Create error handler AFTER parsing options to respect user's --error-mode choice
        ensure_error_handler

        # Set global log file if specified
        SimpleCovMcp.log_file = @log_file if @log_file

        if @cmd
          run_subcommand(@cmd, @cmd_args)
        else
          show_default_report(sort_order: @sort_order)
        end
      rescue SimpleCovMcp::Error => e
        handle_user_facing_error(e)
      rescue => e
        @error_handler.handle_error(e, context: 'CLI execution')
      end

      def show_default_report(sort_order: :ascending, output: $stdout)
        model = CoverageModel.new(root: @root, resultset: @resultset, staleness: @stale_mode, tracked_globs: @tracked_globs)
        rows = model.all_files(sort_order: sort_order, check_stale: (@stale_mode == 'error'), tracked_globs: @tracked_globs)
        if @json
          files = rows.map { |row| row.merge('file' => rel_to_root(row['file'])) }
          total = files.length
          stale_count = files.count { |f| f['stale'] }
          ok_count = total - stale_count
          output.puts JSON.pretty_generate({ files: files, counts: { total: total, ok: ok_count, stale: stale_count } })
          return
        end

        file_summaries = rows.map do |row|
          row.dup.tap do |h|
            h['file'] = rel_to_root(h['file'])
          end
        end

        output.puts model.format_table(file_summaries, sort_order: sort_order)
      end

      private

      def parse_options!(argv)
        require 'optparse'
        extract_subcommand!(argv)
        build_option_parser.parse!(argv)
        @cmd_args = argv
      end

      def extract_subcommand!(argv)
        if !argv.empty? && SUBCOMMANDS.include?(argv[0])
          @cmd = argv.shift
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
        o.banner = 'Usage: simplecov-mcp [subcommand] [options] [args]'
        o.separator ''
      end

      def define_subcommands_help(o)
        o.separator 'Subcommands:'
        o.separator '  list                    Show table of all files'
        o.separator '  summary <path>          Show covered/total/% for a file'
        o.separator "  raw <path>              Show the SimpleCov 'lines' array"
        o.separator '  uncovered <path>        Show uncovered lines and a summary'
        o.separator '  detailed <path>         Show per-line rows with hits/covered'
        o.separator '  version                 Show version information'
        o.separator ''
      end

      def define_options(o)
        o.separator ''
        o.separator 'Options:'
        o.on('--resultset PATH', String, 'Path or directory that contains .resultset.json') { |v| @resultset = v }
        o.on('--root PATH', String, "Project root (default '.')") { |v| @root = v }
        o.on('--json', 'Output JSON for machine consumption') { @json = true }
        o.on('--sort-order ORDER', String, ['ascending', 'descending'], "Sort order for 'list' (ascending|descending)") { |v| @sort_order = v }
        o.on('--source[=MODE]', [:full, :uncovered], 'Include source in output for summary/uncovered/detailed (MODE: full|uncovered; default full)') do |v|
          @source_mode = (v || :full).to_s
        end
        o.on('--source-context N', Integer, 'For --source=uncovered, show N context lines (default 2)') { |v| @source_context = v }
        o.on('--color', 'Enable ANSI colors for source output') { @color = true }
        o.on('--no-color', 'Disable ANSI colors') { @color = false }
        o.on('--stale MODE', [:off, :error], "Staleness mode: off|error (default off)") { |v| @stale_mode = v.to_s }
        o.on('--tracked-globs x,y,z', Array, 'Globs for files that should be covered (list only)') { |v| @tracked_globs = v }
        o.on('--log-file PATH', String, 'Log file path (default ~/simplecov_mcp.log, use - to disable)') { |v| @log_file = v }
        o.on('--error-mode MODE', [:off, :on, :on_with_trace], "Error handling mode: off|on|on_with_trace (default on)") do |v|
          @error_mode = v
          # Don't create error handler here - it will be created after all options are parsed
        end
        o.on('--force-cli', 'Force CLI mode (useful in scripts where auto-detection fails)') do
          # This flag is mainly for mode detection - no action needed here
        end
      end

      def define_examples(o)
        o.separator ''
        o.separator 'Examples:'
        o.separator '  simplecov-mcp list --resultset coverage'
        o.separator '  simplecov-mcp summary lib/foo.rb --json --resultset coverage'
        o.separator '  simplecov-mcp uncovered lib/foo.rb --source=uncovered --source-context 2'
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
          rel = rel_path(data['file'])
          s = data['summary']
          printf "%8.2f%%  %6d/%-6d  %s\n\n", s['pct'], s['covered'], s['total'], rel
          print_source_for(model, path) if @source_mode
        end
      end

      def handle_raw(model, args)
        handle_with_path(args, 'raw') do |path|
          data = model.raw_for(path)
          break if maybe_output_json(relativize_file(data))
          rel = rel_path(data['file'])
          puts "File: #{rel}"
          puts data['lines'].inspect
        end
      end

      def handle_uncovered(model, args)
        handle_with_path(args, 'uncovered') do |path|
          data = model.uncovered_for(path)
          break if emit_json_with_optional_source(data, model, path)
          rel = rel_path(data['file'])
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
          rel = rel_path(data['file'])
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

      def rel_path(abs)
        rel_to_root(abs)
      end

      def maybe_output_json(obj)
        return false unless @json
        puts JSON.pretty_generate(obj)
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
        if @source_mode
          payload = relativize_file(data).merge('source' => build_source_payload(model, path))
          puts JSON.pretty_generate(payload)
        else
          puts JSON.pretty_generate(relativize_file(data))
        end
        true
      end

      def print_source_for(model, path)
        raw = model.raw_for(path)
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
        raw = model.raw_for(path)
        abs = raw['file']
        lines_cov = raw['lines']
        src = File.file?(abs) ? File.readlines(abs, chomp: true) : nil
        return nil unless src
        build_source_rows(src, lines_cov, mode: @source_mode, context: @source_context)
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

      def rel_to_root(path)
        Pathname.new(path).relative_path_from(Pathname.new(File.absolute_path(@root))).to_s
      end

      def relativize_file(h)
        return h unless h.is_a?(Hash) && h['file']
        dup = h.dup
        dup['file'] = rel_to_root(dup['file'])
        dup
      end


      def handle_user_facing_error(error)
        warn error.user_friendly_message
        exit 1
      end
  end
end
