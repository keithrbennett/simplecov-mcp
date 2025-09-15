# frozen_string_literal: true

module Simplecov
  module Mcp
    class CoverageCLI
      def initialize
        @root = "."
        @resultset = nil
      end

      def run(argv)
        @resultset = extract_resultset(argv)
        if force_cli?(argv)
          show_default_report
        else
          run_mcp_server
        end
      rescue => e
        CovUtil.log("CLI fatal error: #{e.class}: #{e.message}\n#{e.backtrace&.join("\n")}")
        raise
      end

      private

      def force_cli?(argv)
        return true  if ENV["COVERAGE_MCP_CLI"] == "1"
        return true  if argv.include?("--cli") || argv.include?("--report")
        # If interactive TTY, prefer CLI; else (e.g., pipes), run MCP.
        return STDIN.tty?
      end

      # Supports --resultset=<path> or --resultset <path>
      def extract_resultset(argv)
        argv.each_with_index do |arg, i|
          if arg.start_with?("--resultset=")
            return arg.split("=", 2)[1]
          elsif arg == "--resultset" && i + 1 < argv.length
            return argv[i + 1]
          end
        end
        nil
      end

      def show_default_report
        model = CoverageModel.new(root: @root, resultset: @resultset)
        file_summaries = model.all_files(sort_order: :ascending).map do |row|
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
    end
  end
end
