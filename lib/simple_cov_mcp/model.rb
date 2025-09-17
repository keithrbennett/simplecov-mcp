# frozen_string_literal: true

require_relative 'util'
require_relative 'errors'

module SimpleCovMcp
  class CoverageModel
      def initialize(root: '.', resultset: nil)
        @root = File.absolute_path(root || '.')
        @resultset = resultset
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

      # Returns { 'file' => <absolute_path>, 'lines' => [hits|nil,...] }
      def raw_for(path)
        file_abs, coverage_lines = resolve(path)
        { 'file' => file_abs, 'lines' => coverage_lines }
      end

      # Returns { 'file' => <absolute_path>, 'summary' => {'covered'=>, 'total'=>, 'pct'=>} }
      def summary_for(path)
        file_abs, coverage_lines = resolve(path)
        { 'file' => file_abs, 'summary' => CovUtil.summary(coverage_lines) }
      end

      # Returns { 'file' => <absolute_path>, 'uncovered' => [line,...], 'summary' => {...} }
      def uncovered_for(path)
        file_abs, coverage_lines = resolve(path)
        { 'file' => file_abs, 'uncovered' => CovUtil.uncovered(coverage_lines), 'summary' => CovUtil.summary(coverage_lines) }
      end

      # Returns { 'file' => <absolute_path>, 'lines' => [{'line'=>,'hits'=>,'covered'=>},...], 'summary' => {...} }
      def detailed_for(path)
        file_abs, coverage_lines = resolve(path)
        { 'file' => file_abs, 'lines' => CovUtil.detailed(coverage_lines), 'summary' => CovUtil.summary(coverage_lines) }
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
        file_abs = File.absolute_path(path, @root)
        coverage_lines = CovUtil.lookup_lines(@cov, file_abs)
        check_staleness!(file_abs, coverage_lines, path) if stale_check_enabled?(file_abs)
        if coverage_lines.nil?
          raise FileError.new("No coverage data found for file: #{path}")
        end
        [file_abs, coverage_lines]
      rescue Errno::ENOENT => e
        raise FileError.new("File not found: #{path}")
      end

      def stale_check_enabled?(file_abs)
        ENV['SIMPLECOV_MCP_STRICT_STALENESS'] == '1' && File.file?(file_abs)
      end

      def check_staleness!(file_abs, coverage_lines, path)
        src_len    = File.foreach(file_abs).count
        cov_len    = coverage_lines.respond_to?(:length) ? coverage_lines.length : 0
        cov_timestamp = CovUtil.latest_timestamp(@root, resultset: @resultset)
        file_mtime = File.mtime(file_abs)

        if coverage_line_count_mismatch?(cov_len, src_len) || source_newer_than_coverage?(file_mtime, cov_timestamp)
          details = build_stale_detail_string(file_mtime, cov_timestamp, src_len, cov_len)
          raise CoverageDataError.new("Coverage data appears stale for #{path}:#{details}")
        end
      rescue CoverageDataError
        raise
      rescue StandardError
        # Ignore staleness check failures; proceed without blocking
      end

      def coverage_line_count_mismatch?(cov_len, src_len)
        cov_len > 0 && cov_len != src_len
      end

      def source_newer_than_coverage?(file_mtime, cov_timestamp)
        cov_timestamp && file_mtime && file_mtime.to_i > cov_timestamp.to_i
      end

      def build_stale_detail_string(file_mtime, cov_timestamp, src_len, cov_len)
        source_ts = format_source_file_timestamp(file_mtime) || 'not found'
        cov_ts  = format_coverage_file_timestamp(cov_timestamp) || 'not found'
        "\nFile     - time: #{source_ts}, lines: #{src_len}" \
        "\nCoverage - time: #{cov_ts}, lines: #{cov_len}"
      end

      def format_coverage_file_timestamp(cov_timestamp)
        return nil unless cov_timestamp
        Time.at(cov_timestamp.to_i).utc.iso8601
      rescue StandardError
        cov_timestamp.to_s
      end

      def format_source_file_timestamp(file_mtime)
        return nil unless file_mtime
        file_mtime.is_a?(Time) ? file_mtime.utc.iso8601 : file_mtime.to_s
      rescue StandardError
        file_mtime.to_s
      end
  end
end
