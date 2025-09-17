# frozen_string_literal: true

require_relative 'util'
require_relative 'errors'

module SimpleCovMcp
  class CoverageModel
    # Create a CoverageModel
    #
    # Params:
    # - root: project root directory (default '.')
    # - resultset: path or directory to .resultset.json
    # - strict_staleness: when true, raise CoverageDataError if the source
    #   file appears newer than the coverage timestamp or if line counts
    #   mismatch; defaults from ENV['SIMPLECOV_MCP_STRICT_STALENESS'] == '1'
    def initialize(root: '.', resultset: nil, strict_staleness: ENV['SIMPLECOV_MCP_STRICT_STALENESS'] == '1')
      @root = File.absolute_path(root || '.')
      @resultset = resultset
      @strict_staleness = !!strict_staleness
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
      def all_files(sort_order: :ascending, check_stale: @strict_staleness, tracked_globs: nil)
        rows = @cov.map do |abs_path, data|
          next unless data['lines'].is_a?(Array)
          s = CovUtil.summary(data['lines'])
          { 'file' => abs_path, 'covered' => s['covered'], 'total' => s['total'], 'percentage' => s['pct'] }
        end.compact

        if check_stale
          cov_timestamp = CovUtil.latest_timestamp(@root, resultset: @resultset)
          check_all_files_staleness!(cov_timestamp, tracked_globs: tracked_globs)
        end

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
      @strict_staleness && File.file?(file_abs)
    end

    def check_staleness!(file_abs, coverage_lines, path)
      src_len    = File.foreach(file_abs).count
      cov_len    = coverage_lines.respond_to?(:length) ? coverage_lines.length : 0
      cov_timestamp = CovUtil.latest_timestamp(@root, resultset: @resultset)
      file_mtime = File.mtime(file_abs)

      if coverage_line_count_mismatch?(cov_len, src_len) || source_newer_than_coverage?(file_mtime, cov_timestamp)
        rs_path = begin
          SimpleCovMcp::CovUtil.find_resultset(@root, resultset: @resultset)
        rescue StandardError
          nil
        end
        raise CoverageDataStaleError.new(
          nil,
          nil,
          file_path: path,
          file_mtime: file_mtime,
          cov_timestamp: cov_timestamp,
          src_len: src_len,
          cov_len: cov_len,
          resultset_path: rs_path
        )
      end
    rescue SimpleCovMcp::Error
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

      def check_all_files_staleness!(cov_timestamp, tracked_globs: nil)
        begin
          resultset_path = SimpleCovMcp::CovUtil.find_resultset(@root, resultset: @resultset)
        rescue StandardError
          resultset_path = nil
        end

        coverage_files = @cov.keys
        newer = []
        deleted = []
        coverage_files.each do |abs|
          if File.file?(abs)
            newer << rel_to_root(abs) if File.mtime(abs).to_i > cov_timestamp.to_i
          else
            deleted << rel_to_root(abs)
          end
        end

        missing = []
        if tracked_globs && !Array(tracked_globs).empty?
          patterns = Array(tracked_globs).map { |g| File.absolute_path(g, @root) }
          tracked = patterns.flat_map { |p| Dir.glob(p, File::FNM_EXTGLOB | File::FNM_PATHNAME) }
                            .select { |p| File.file?(p) }
          covered_set = coverage_files.to_set rescue coverage_files
          tracked.each do |abs|
            missing << rel_to_root(abs) unless covered_set.include?(abs)
          end
        end

        if !newer.empty? || !missing.empty? || !deleted.empty?
          raise CoverageDataProjectStaleError.new(
            nil,
            nil,
            cov_timestamp: cov_timestamp,
            newer_files: newer,
            missing_files: missing,
            deleted_files: deleted,
            resultset_path: resultset_path
          )
        end
      rescue SimpleCovMcp::Error
        raise
      rescue StandardError
        # swallow staleness calculation issues during all_files
      end

      def rel_to_root(path)
        Pathname.new(path).relative_path_from(Pathname.new(File.absolute_path(@root))).to_s
      end

    # Detailed stale message construction moved to CoverageDataStaleError
  end
end
