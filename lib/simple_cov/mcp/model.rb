# frozen_string_literal: true

require_relative 'util'
require_relative 'errors'

module SimpleCov
  module Mcp
    class CoverageModel
      def initialize(root: '.', resultset: nil)
        @root = File.absolute_path(root || '.')
        begin
          @cov  = CovUtil.load_latest_coverage(@root, resultset: resultset)
        rescue Errno::ENOENT => e
          raise FileError.new("Coverage data not found at #{resultset || @root}")
        rescue JSON::ParserError => e
          raise CoverageDataError.new("Invalid coverage data format")
        rescue => e
          raise CoverageDataError.new("Failed to load coverage data: #{e.message}")
        end
      end

      # Returns { 'file' => <abs>, 'lines' => [hits|nil,...] }
      def raw_for(path)
        abs, arr = resolve(path)
        { 'file' => abs, 'lines' => arr }
      end

      # Returns { 'file' => <abs>, 'summary' => {'covered'=>, 'total'=>, 'pct'=>} }
      def summary_for(path)
        abs, arr = resolve(path)
        { 'file' => abs, 'summary' => CovUtil.summary(arr) }
      end

      # Returns { 'file' => <abs>, 'uncovered' => [line,...], 'summary' => {...} }
      def uncovered_for(path)
        abs, arr = resolve(path)
        { 'file' => abs, 'uncovered' => CovUtil.uncovered(arr), 'summary' => CovUtil.summary(arr) }
      end

      # Returns { 'file' => <abs>, 'lines' => [{'line'=>,'hits'=>,'covered'=>},...], 'summary' => {...} }
      def detailed_for(path)
        abs, arr = resolve(path)
        { 'file' => abs, 'lines' => CovUtil.detailed(arr), 'summary' => CovUtil.summary(arr) }
      end

      # Returns [ { 'file' =>, 'covered' =>, 'total' =>, 'percentage' => }, ... ]
      def all_files(sort_order: :ascending)
        rows = @cov.map do |abs_path, data|
          next unless data['lines'].is_a?(Array)
          s = CovUtil.summary(data['lines'])
          { 'file' => abs_path, 'covered' => s['covered'], 'total' => s['total'], 'percentage' => s['pct'] }
        end.compact

        rows.sort! do |a, b|
          pct_cmp = (sort_order.to_s == 'descending') ? (b['percentage'] <=> a['percentage']) : (a['percentage'] <=> b['percentage'])
          pct_cmp == 0 ? (a['file'] <=> b['file']) : pct_cmp
        end
        rows
      end

      private

      def resolve(path)
        abs = File.absolute_path(path, @root)
        lines = CovUtil.lookup_lines(@cov, abs)
        if lines.nil?
          raise FileError.new("No coverage data found for file: #{path}")
        end
        [abs, lines]
      rescue Errno::ENOENT => e
        raise FileError.new("File not found: #{path}")
      end
    end
  end
end
