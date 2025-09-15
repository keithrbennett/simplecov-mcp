# frozen_string_literal: true

module Simplecov
  module Mcp
    class CoverageCLI
      SUBCOMMANDS = %w[list summary raw uncovered detailed].freeze

      def initialize
        @root = "."
        @resultset = nil
        @force_cli = false
        @json = false
        @sort_order = "ascending"
        @cmd = nil
        @cmd_args = []
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
      rescue => e
        CovUtil.log("CLI fatal error: #{e.class}: #{e.message}\n#{e.backtrace&.join("\n")}")
        raise
      end

      private

      def prefer_cli?
        return true if ENV["COVERAGE_MCP_CLI"] == "1"
        return true if @force_cli
        return true if @cmd # subcommand provided → CLI
        # If interactive TTY, prefer CLI; else (e.g., pipes), run MCP.
        STDIN.tty?
      end

      def parse_options!(argv)
        require "optparse"

        if !argv.empty? && SUBCOMMANDS.include?(argv[0])
          @cmd = argv.shift
        end

        op = OptionParser.new do |o|
          o.banner = "Usage: simplecov-mcp [subcommand] [options] [args]\n\nSubcommands: list | summary <path> | raw <path> | uncovered <path> | detailed <path>"
          o.separator ""
          o.separator "Modes:"
          o.on("--cli", "Force CLI mode (table report)") { @force_cli = true }
          o.on("--report", "Alias for --cli") { @force_cli = true }

          o.separator ""
          o.separator "Options:"
          o.on("--resultset PATH", String, "Path or directory for .resultset.json") { |v| @resultset = v }
          o.on("--root PATH", String, "Project root (default '.')") { |v| @root = v }
          o.on("--json", "Output JSON for machine consumption") { @json = true }
          o.on("--sort-order ORDER", String, ["ascending", "descending"], "Sort order for 'list' (ascending|descending)") { |v| @sort_order = v }
          o.on("-h", "--help", "Show help") do
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
          puts JSON.pretty_generate({ files: rows })
          return
        end

        file_summaries = rows.map do |row|
          row.dup.tap do |h|
            h[:file] = Pathname.new(h[:file]).relative_path_from(Pathname.new(Dir.pwd)).to_s
          end
        end

        # Format as table with box-style borders
        max_file_length = file_summaries.map { |f| f[:file].length }.max.to_i
        max_file_length = [max_file_length, "File".length].max

        # Calculate maximum numeric values for proper column widths
        max_covered = file_summaries.map { |f| f[:covered].to_s.length }.max
        max_total = file_summaries.map { |f| f[:total].to_s.length }.max

        # Define column widths
        file_width = max_file_length + 2  # Extra padding
        pct_width = 8
        covered_width = [max_covered, "Covered".length].max + 2
        total_width = [max_total, "Total".length].max + 2

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
        puts border_line.call("┌", "┬", "┐")

        # Header row
        printf "│ %-#{file_width}s │ %#{pct_width}s │ %#{covered_width}s │ %#{total_width}s │\n",
               "File", " %", "Covered", "Total"

        # Header separator
        puts border_line.call("├", "┼", "┤")

        # Data rows
        file_summaries.each do |file_data|
          printf "│ %-#{file_width}s │ %#{pct_width - 1}.2f%% │ %#{covered_width}d │ %#{total_width}d │\n",
                 file_data[:file],
                 file_data[:percentage],
                 file_data[:covered],
                 file_data[:total]
        end

        # Bottom border
        puts border_line.call("└", "┴", "┘")
      end

      def run_mcp_server
        server = ::MCP::Server.new(
          name:    "ruby_coverage_server",
          version: Simplecov::Mcp::VERSION,
          tools:   [CoverageRaw, CoverageSummary, UncoveredLines, CoverageDetailed, AllFilesCoverage]
        )
        ::MCP::Server::Transports::StdioTransport.new(server).open
      end

      def run_subcommand(cmd, args)
        model = CoverageModel.new(root: @root, resultset: @resultset)
        case cmd
        when "list"      then handle_list(model)
        when "summary"   then handle_summary(model, args)
        when "raw"       then handle_raw(model, args)
        when "uncovered" then handle_uncovered(model, args)
        when "detailed"  then handle_detailed(model, args)
        else sub_usage("list | summary <path> | raw <path> | uncovered <path> | detailed <path>")
        end
      rescue => e
        CovUtil.log("CLI subcommand error (#{cmd}): #{e.class}: #{e.message}")
        raise
      end

      def sub_usage(usage)
        warn "Usage: simplecov-mcp #{usage}"
        exit 1
      end

      def format_detailed_rows(rows)
        # Simple aligned columns: line, hits, covered
        out = []
        out << sprintf("%6s  %6s  %7s", "Line", "Hits", "Covered")
        out << sprintf("%6s  %6s  %7s", "-----", "----", "-------")
        rows.each do |r|
          out << sprintf("%6d  %6d  %7s", r[:line], r[:hits], r[:covered] ? "yes" : "no")
        end
        out.join("\n")
      end

      def handle_list(model)
        show_default_report(sort_order: @sort_order)
      end

      def handle_summary(model, args)
        handle_with_path(args, "summary") do |path|
          data = model.summary_for(path)
          break if maybe_output_json(data)
          rel = rel_path(data[:file])
          s = data[:summary]
          printf "%8.2f%%  %6d/%-6d  %s\n", s["pct"], s["covered"], s["total"], rel
        end
      end

      def handle_raw(model, args)
        handle_with_path(args, "raw") do |path|
          data = model.raw_for(path)
          break if maybe_output_json(data)
          rel = rel_path(data[:file])
          puts "File: #{rel}"
          puts data[:lines].inspect
        end
      end

      def handle_uncovered(model, args)
        handle_with_path(args, "uncovered") do |path|
          data = model.uncovered_for(path)
          break if maybe_output_json(data)
          rel = rel_path(data[:file])
          puts "File: #{rel}"
          puts "Uncovered lines: #{data[:uncovered].join(', ')}"
          s = data[:summary]
          printf "Summary: %8.2f%%  %6d/%-6d\n", s["pct"], s["covered"], s["total"]
        end
      end

      def handle_detailed(model, args)
        handle_with_path(args, "detailed") do |path|
          data = model.detailed_for(path)
          break if maybe_output_json(data)
          rel = rel_path(data[:file])
          puts "File: #{rel}"
          puts format_detailed_rows(data[:lines])
        end
      end

      def handle_with_path(args, name)
        path = args.shift or return sub_usage("#{name} <path>")
        yield(path)
      end

      def rel_path(abs)
        Pathname.new(abs).relative_path_from(Pathname.new(Dir.pwd)).to_s
      end

      def maybe_output_json(obj)
        return false unless @json
        puts JSON.pretty_generate(obj)
        true
      end
    end
  end
end
