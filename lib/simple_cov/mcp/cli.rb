# frozen_string_literal: true

module SimpleCov
  module Mcp
    class CoverageCLI
      SUBCOMMANDS = %w[list summary raw uncovered detailed].freeze

      # Initialize CLI with optional custom error handler for library usage.
      # When error_handler is nil, creates a default handler suitable for CLI usage
      # with user-friendly error messages and optional debug stack traces.
      def initialize(error_handler: nil)
        @root = '.'
        @resultset = nil
        @force_cli = false
        @json = false
        @sort_order = 'ascending'
        @cmd = nil
        @cmd_args = []
        @source_mode = nil   # nil, 'full', or 'uncovered'
        @source_context = 2  # lines of context for uncovered mode
        @color = STDOUT.tty?
        @error_handler = error_handler || create_cli_error_handler
      end

      def run(argv)
        parse_options!(argv)
        if prefer_cli?
          if @cmd
            run_subcommand(@cmd, @cmd_args)
          else
            show_default_report(sort_order: @sort_order)
          end
        else
          run_mcp_server
        end
      rescue SimpleCov::Mcp::Error => e
        handle_user_facing_error(e)
      rescue => e
        @error_handler.handle_error(e, context: 'CLI execution')
      end

      private

      def prefer_cli?
        return true if ENV['COVERAGE_MCP_CLI'] == '1'
        return true if @force_cli
        return true if @cmd # subcommand provided → CLI
        # If interactive TTY, prefer CLI; else (e.g., pipes), run MCP.
        STDIN.tty?
      end

      def parse_options!(argv)
        require 'optparse'

        if !argv.empty? && SUBCOMMANDS.include?(argv[0])
          @cmd = argv.shift
        end

        op = OptionParser.new do |o|
          o.banner = 'Usage: simplecov-mcp [subcommand] [options] [args]'
          o.separator ''
          o.separator 'Subcommands:'
          o.separator '  list                    Show table of all files'
          o.separator '  summary <path>          Show covered/total/% for a file'
          o.separator "  raw <path>              Show the SimpleCov 'lines' array"
          o.separator '  uncovered <path>        Show uncovered lines and a summary'
          o.separator '  detailed <path>         Show per-line rows with hits/covered'
          o.separator ''
          o.separator 'Modes:'
          o.on('--cli', 'Force CLI mode (table report)') { @force_cli = true }
          o.on('--report', 'Alias for --cli') { @force_cli = true }

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
          o.separator ''
          o.separator 'Examples:'
          o.separator '  simplecov-mcp list --resultset coverage'
          o.separator '  simplecov-mcp summary lib/foo.rb --json --resultset coverage'
          o.separator '  simplecov-mcp uncovered lib/foo.rb --source=uncovered --source-context 2'
          o.on('-h', '--help', 'Show help') do
            puts o
            exit 0
          end
        end
        op.parse!(argv)
        @cmd_args = argv
      end

      def show_default_report(sort_order: :ascending)
        model = CoverageModel.new(root: @root, resultset: @resultset)
        rows = model.all_files(sort_order: sort_order)
        if @json
          files = rows.map { |row| row.merge('file' => rel_to_root(row['file'])) }
          puts JSON.pretty_generate({ files: files })
          return
        end

        file_summaries = rows.map do |row|
          row.dup.tap do |h|
            h['file'] = rel_to_root(h['file'])
          end
        end

        # Format as table with box-style borders
        max_file_length = file_summaries.map { |f| f['file'].length }.max.to_i
        max_file_length = [max_file_length, 'File'.length].max

        # Calculate maximum numeric values for proper column widths
        max_covered = file_summaries.map { |f| f['covered'].to_s.length }.max
        max_total = file_summaries.map { |f| f['total'].to_s.length }.max

        # Define column widths
        file_width = max_file_length + 2  # Extra padding
        pct_width = 8
        covered_width = [max_covered, 'Covered'.length].max + 2
        total_width = [max_total, 'Total'.length].max + 2

        # Horizontal line for each column span
        h_line = ->(col_width) { '─' * (col_width + 2) }

        # Border line lambda
        border_line = ->(left, middle, right) {
          left   + h_line.(file_width) +
          middle + h_line.(pct_width) +
          middle + h_line.(covered_width) +
          middle + h_line.(total_width) +
          right
        }

        # Top border
        puts border_line.call('┌', '┬', '┐')

        # Header row
        printf "│ %-#{file_width}s │ %#{pct_width}s │ %#{covered_width}s │ %#{total_width}s │\n",
               'File', ' %', 'Covered', 'Total'

        # Header separator
        puts border_line.call('├', '┼', '┤')

        # Data rows
        file_summaries.each do |file_data|
          printf "│ %-#{file_width}s │ %#{pct_width - 1}.2f%% │ %#{covered_width}d │ %#{total_width}d │\n",
                 file_data['file'],
                 file_data['percentage'],
                 file_data['covered'],
                 file_data['total']
        end

        # Bottom border
        puts border_line.call('└', '┴', '┘')
      end

      def run_mcp_server
        # Configure error handling for MCP server mode
        # MCP framework handles error responses, so we want:
        # - Logging enabled for server debugging
        # - Clean error messages (no stack traces unless debug mode)
        # - Let MCP framework handle the actual error responses to clients
        SimpleCov::Mcp.configure_error_handling do |handler|
          handler.log_errors = true
          handler.show_stack_traces = ENV['SIMPLECOV_MCP_DEBUG'] == '1'
        end

        server = ::MCP::Server.new(
          name:    'simplecov_mcp',
          version: SimpleCov::Mcp::VERSION,
          tools:   [AllFilesCoverageTool, CoverageDetailedTool, CoverageRawTool, CoverageSummaryTool, UncoveredLinesTool]
        )
        ::MCP::Server::Transports::StdioTransport.new(server).open
      end

      def run_subcommand(cmd, args)
        model = CoverageModel.new(root: @root, resultset: @resultset)
        case cmd
        when 'list'      then handle_list(model)
        when 'summary'   then handle_summary(model, args)
        when 'raw'       then handle_raw(model, args)
        when 'uncovered' then handle_uncovered(model, args)
        when 'detailed'  then handle_detailed(model, args)
        else raise UsageError.for_subcommand('list | summary <path> | raw <path> | uncovered <path> | detailed <path>')
        end
      rescue SimpleCov::Mcp::Error => e
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

      def handle_summary(model, args)
        handle_with_path(args, 'summary') do |path|
          data = model.summary_for(path)
          if @source_mode && @json
            data = relativize_file(data)
            src = build_source_payload(model, path)
            data['source'] = src
            break puts(JSON.pretty_generate(data))
          end
          break if maybe_output_json(relativize_file(data))
          rel = rel_path(data['file'])
          s = data['summary']
          printf '%8.2f%%  %6d/%-6d  %s\n', s['pct'], s['covered'], s['total'], rel
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
          if @source_mode && @json
            data = relativize_file(data)
            src = build_source_payload(model, path)
            data['source'] = src
            break puts(JSON.pretty_generate(data))
          end
          break if maybe_output_json(relativize_file(data))
          rel = rel_path(data['file'])
          puts "File: #{rel}"
          puts "Uncovered lines: #{data['uncovered'].join(', ')}"
          s = data['summary']
          printf 'Summary: %8.2f%%  %6d/%-6d\n', s['pct'], s['covered'], s['total']
          print_source_for(model, path) if @source_mode
        end
      end

      def handle_detailed(model, args)
        handle_with_path(args, 'detailed') do |path|
          data = model.detailed_for(path)
          if @source_mode && @json
            data = relativize_file(data)
            src = build_source_payload(model, path)
            data['source'] = src
            break puts(JSON.pretty_generate(data))
          end
          break if maybe_output_json(relativize_file(data))
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
        raise FileError.new("File not found: #{path}")
      rescue Errno::EACCES => e
        raise FileError.new("Permission denied: #{path}")
      end

      def rel_path(abs)
        rel_to_root(abs)
      end

      def maybe_output_json(obj)
        return false unless @json
        puts JSON.pretty_generate(obj)
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
        rows = build_source_rows(src, lines_cov, mode: @source_mode, context: @source_context)
        puts format_source_rows(rows)
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
        n = src_lines.length
        include_line = Array.new(n, mode == 'full')
        if mode == 'uncovered'
          misses = []
          cov_lines.each_with_index do |hits, i|
            misses << i if !hits.nil? && hits.to_i == 0
          end
          misses.each do |i|
            a = [0, i - context].max
            b = [n - 1, i + context].min
            (a..b).each { |j| include_line[j] = true }
          end
        end
        out = []
        src_lines.each_with_index do |code, i|
          next unless include_line[i]
          hits = cov_lines[i]
          covered = hits.nil? ? nil : hits.to_i > 0
          out << { line: i + 1, code: code, hits: hits, covered: covered }
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

      def create_cli_error_handler
        # For CLI usage, we want logging enabled and stack traces for debugging
        show_traces = ENV['SIMPLECOV_MCP_DEBUG'] == '1'
        ErrorHandler.new(
          log_errors: true,
          show_stack_traces: show_traces
        )
      end

      def handle_user_facing_error(error)
        if running_as_cli?
          warn error.user_friendly_message
          exit 1
        else
          # When used as library, re-raise the custom error
          raise error
        end
      end

      def running_as_cli?
        # We're running as CLI if we have a command or forced CLI mode
        @cmd || @force_cli || prefer_cli?
      end
    end
  end
end
