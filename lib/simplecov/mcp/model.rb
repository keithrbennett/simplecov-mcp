# frozen_string_literal: true

module Simplecov
  module Mcp
    class CoverageModel
      def initialize(root: ".", resultset: nil)
        @root = File.absolute_path(root || ".")
        @cov  = CovUtil.load_latest_coverage(@root, resultset: resultset)
      end

      # Returns { file: <abs>, lines: [hits|nil,...] }
      def raw_for(path)
        abs, arr = resolve(path)
        { file: abs, lines: arr }
      end

      # Returns { file: <abs>, summary: {"covered"=>, "total"=>, "pct"=>} }
      def summary_for(path)
        abs, arr = resolve(path)
        { file: abs, summary: CovUtil.summary(arr) }
      end

      # Returns { file: <abs>, uncovered: [line,...], summary: {...} }
      def uncovered_for(path)
        abs, arr = resolve(path)
        { file: abs, uncovered: CovUtil.uncovered(arr), summary: CovUtil.summary(arr) }
      end

      # Returns { file: <abs>, lines: [{line:,hits:,covered:},...], summary: {...} }
      def detailed_for(path)
        abs, arr = resolve(path)
        { file: abs, lines: CovUtil.detailed(arr), summary: CovUtil.summary(arr) }
      end

      # Returns [ { file:, covered:, total:, percentage: }, ... ]
      def all_files(sort_order: :ascending)
        rows = @cov.map do |abs_path, data|
          next unless data["lines"].is_a?(Array)
          s = CovUtil.summary(data["lines"])
          { file: abs_path, covered: s["covered"], total: s["total"], percentage: s["pct"] }
        end.compact

        rows.sort! do |a, b|
          pct_cmp = (sort_order.to_s == "descending") ? (b[:percentage] <=> a[:percentage]) : (a[:percentage] <=> b[:percentage])
          pct_cmp == 0 ? (a[:file] <=> b[:file]) : pct_cmp
        end
        rows
      end

      private

      def resolve(path)
        abs = File.absolute_path(path, @root)
        [abs, CovUtil.lookup_lines(@cov, abs)]
      end
    end
  end
end
