# frozen_string_literal: true

require "json"
require "time"
require "pathname"
require "mcp"
require "mcp/server/transports/stdio_transport"
require "awesome_print"

module Simplecov
  module Mcp
    RESULTSET_CANDIDATES = [
      ".resultset.json",
      "coverage/.resultset.json",
      "tmp/.resultset.json"
    ].freeze

    module CovUtil
      module_function

      def log(msg)
        path = File.expand_path("~/coverage_mcp.log")
        File.open(path, "a") { |f| f.puts "[#{Time.now.iso8601}] #{msg}" }
      rescue StandardError
        # swallow logging errors
      end

      def find_resultset(root)
        if (env = ENV["SIMPLECOV_RESULTSET"]) && !env.empty?
          path = File.absolute_path(env, root)
          return path if File.file?(path)
        end
        RESULTSET_CANDIDATES
          .map { |p| File.absolute_path(p, root) }
          .find { |p| File.file?(p) } or
          raise "Could not find .resultset.json under #{root.inspect}; run tests or set SIMPLECOV_RESULTSET"
      end

      # returns { abs_path => {"lines" => [hits|nil,...]} }
      def load_latest_coverage(root)
        rs = find_resultset(root)
        raw = JSON.parse(File.read(rs))
        _suite, data = raw.max_by { |_k, v| (v["timestamp"] || v["created_at"] || 0).to_i }
        cov = data["coverage"] or raise "No 'coverage' key in .resultset.json"
        cov.transform_keys { |k| File.absolute_path(k, root) }
      end

      def lookup_lines(cov, file_abs)
        if (h = cov[file_abs]) && h["lines"].is_a?(Array)
          return h["lines"]
        end

        # try without current working directory prefix
        cwd = Dir.pwd
        without = file_abs.sub(/\A#{Regexp.escape(cwd)}\//, "")
        if (h = cov[without]) && h["lines"].is_a?(Array)
          return h["lines"]
        end

        # fallback: basename match
        base = File.basename(file_abs)
        kv = cov.find { |k, v| File.basename(k) == base && v["lines"].is_a?(Array) }
        kv and return kv[1]["lines"]

        raise "No coverage entry found for #{file_abs}"
      end

      def summary(arr)
        total = 0
        covered = 0
        arr.each do |hits|
          next if hits.nil?
          total += 1
          covered += 1 if hits.to_i > 0
        end
        pct = total.zero? ? 100.0 : ((covered.to_f * 100.0 / total) * 100).round / 100.0
        { "covered" => covered, "total" => total, "pct" => pct }
      end

      def uncovered(arr)
        out = []
        arr.each_with_index do |hits, i|
          next if hits.nil?
          out << (i + 1) if hits.to_i.zero?
        end
        out
      end

      def detailed(arr)
        rows = []
        arr.each_with_index do |hits, i|
          next if hits.nil?
          h = hits.to_i
          rows << { line: i + 1, hits: h, covered: h.positive? }
        end
        rows
      end

      # resolve inputs → [abs_file, lines_array]
      def resolve(root, path)
        root = File.absolute_path(root || ".")
        abs  = File.absolute_path(path, root)
        cov  = load_latest_coverage(root)
        [abs, lookup_lines(cov, abs)]
      end
    end

    class BaseTool < ::MCP::Tool
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          path: { type: "string", description: "Absolute or project-relative file path" },
          root: { type: "string", description: "Project root for resolution", default: "." }
        },
        required: ["path"]
      }
      def self.input_schema_def = INPUT_SCHEMA
    end

    class CoverageRaw < BaseTool
      description "Return the original SimpleCov 'lines' array for a file"
      input_schema(**input_schema_def)
      class << self
        def call(path:, root: ".", server_context:)
          file, arr = CovUtil.resolve(root, path)
          ::MCP::Tool::Response.new([{ type: "json", json: { file: file, lines: arr } }],
                              meta: { mimeType: "application/json" })
        rescue => e
          CovUtil.log("CoverageRaw error: #{e.class}: #{e.message}")
          ::MCP::Tool::Response.new([{ type: "text", text: "Error: #{e.class}: #{e.message}" }])
        end
      end
    end

    class CoverageSummary < BaseTool
      description "Return {covered,total,pct} for a file"
      input_schema(**input_schema_def)
      class << self
        def call(path:, root: ".", server_context:)
          file, arr = CovUtil.resolve(root, path)
          sum = CovUtil.summary(arr)
          ::MCP::Tool::Response.new([{ type: "json", json: { file: file, summary: sum } }],
                              meta: { mimeType: "application/json" })
        rescue => e
          CovUtil.log("CoverageSummary error: #{e.class}: #{e.message}")
          ::MCP::Tool::Response.new([{ type: "text", text: "Error: #{e.class}: #{e.message}" }])
        end
      end
    end

    class UncoveredLines < BaseTool
      description "Return only uncovered executable line numbers plus a summary"
      input_schema(**input_schema_def)
      class << self
        def call(path:, root: ".", server_context:)
          file, arr = CovUtil.resolve(root, path)
          list = CovUtil.uncovered(arr)
          sum  = CovUtil.summary(arr)
          ::MCP::Tool::Response.new([{ type: "json", json: { file: file, uncovered: list, summary: sum } }],
                              meta: { mimeType: "application/json" })
        rescue => e
          CovUtil.log("UncoveredLines error: #{e.class}: #{e.message}")
          ::MCP::Tool::Response.new([{ type: "text", text: "Error: #{e.class}: #{e.message}" }])
        end
      end
    end

    class CoverageDetailed < BaseTool
      description "Verbose per-line objects [{line,hits,covered}] (token-heavy)"
      input_schema(**input_schema_def)
      class << self
        def call(path:, root: ".", server_context:)
          file, arr = CovUtil.resolve(root, path)
          rows = CovUtil.detailed(arr)
          sum  = CovUtil.summary(arr)
          ::MCP::Tool::Response.new([{ type: "json", json: { file: file, lines: rows, summary: sum } }],
                              meta: { mimeType: "application/json" })
        rescue => e
          CovUtil.log("CoverageDetailed error: #{e.class}: #{e.message}")
          ::MCP::Tool::Response.new([{ type: "text", text: "Error: #{e.class}: #{e.message}" }])
        end
      end
    end

    class AllFilesCoverage < ::MCP::Tool
      description "Return coverage percentage for all files in the project"
      input_schema(
        type: "object",
        properties: {
          root: { type: "string", description: "Project root for resolution", default: "." },
          sort_order: { type: "string", description: "Sort order for coverage percentage: ascending or descending", default: "ascending", enum: ["ascending", "descending"] }
        }
      )
      class << self
        def call(root: ".", sort_order: "ascending", server_context:)
          root = File.absolute_path(root || ".")
          cov = CovUtil.load_latest_coverage(root)

          file_summaries = cov.map do |abs_path, data|
            next unless data["lines"].is_a?(Array)

            summary = CovUtil.summary(data["lines"])
            {
              file: abs_path,
              covered: summary["covered"],
              total: summary["total"],
              percentage: summary["pct"]
            }
          end.compact

          # Sort by percentage (ascending/descending) then by filespec (always ascending)
          file_summaries.sort! do |a, b|
            pct_comparison = sort_order == "descending" ?
              b[:percentage] <=> a[:percentage] :
              a[:percentage] <=> b[:percentage]
            pct_comparison == 0 ? a[:file] <=> b[:file] : pct_comparison
          end

          ::MCP::Tool::Response.new([{ type: "json", json: { files: file_summaries } }],
                              meta: { mimeType: "application/json" })
        rescue => e
          CovUtil.log("AllFilesCoverage error: #{e.class}: #{e.message}")
          ::MCP::Tool::Response.new([{ type: "text", text: "Error: #{e.class}: #{e.message}" }])
        end
      end
    end

    class CoverageCLI
      def initialize
        @root = "."
      end

      def run(argv)
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

      def show_default_report
        # Reuse the all-files logic to show the report
        @root = "."
        handle_all_files
      end

      def handle_all_files
        root = File.absolute_path(@root)
        cov = CovUtil.load_latest_coverage(root)

        file_summaries = cov.map do |abs_path, data|
          next unless data["lines"].is_a?(Array)

          summary = CovUtil.summary(data["lines"])
          # Convert absolute path to relative path from current working directory
          relative_path = Pathname.new(abs_path).relative_path_from(Pathname.new(Dir.pwd)).to_s
          {
            file: relative_path,
            covered: summary["covered"],
            total: summary["total"],
            percentage: summary["pct"]
          }
        end.compact.sort_by { |f| [f[:percentage], f[:file]] }

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

    def self.run(argv)
      CoverageCLI.new.run(argv)
    end
  end
end

