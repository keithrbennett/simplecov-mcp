# frozen_string_literal: true

module Simplecov
  module Mcp
    class CoverageCLI
      def initialize
        @root = "."
        @resultset = nil
        @force_cli = false
      end

      def run(argv)
        parse_options!(argv)
        if prefer_cli?
          show_default_report
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
        # If interactive TTY, prefer CLI; else (e.g., pipes), run MCP.
        STDIN.tty?
      end

      def parse_options!(argv)
        require "optparse"

        op = OptionParser.new do |o|
          o.banner = "Usage: simplecov-mcp [--cli] [--resultset PATH]"
          o.separator ""
          o.separator "Modes:"
          o.on("--cli", "Force CLI mode (table report)") { @force_cli = true }
          o.on("--report", "Alias for --cli") { @force_cli = true }

          o.separator ""
          o.separator "Options:"
          o.on("--resultset PATH", String, "Path or directory for .resultset.json") { |v| @resultset = v }
          o.on("--root PATH", String, "Project root (default '.')") { |v| @root = v }
          o.on("-h", "--help", "Show help") do
            puts o
            exit 0
          end
        end
        op.parse!(argv)
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
