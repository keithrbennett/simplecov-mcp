# frozen_string_literal: true

require_relative 'util'
require_relative 'errors'
require_relative 'staleness_checker'

module SimpleCovMcp
  class CoverageModel
    # Create a CoverageModel
    #
    # Params:
    # - root: project root directory (default '.')
    # - resultset: path or directory to .resultset.json
      # - staleness: 'off' or 'error' (default 'off'). When 'error', raises
      #   stale errors if sources are newer than coverage or line counts mismatch.
      # - tracked_globs: only used for all_files project-level staleness.
      def initialize(root: '.', resultset: nil, staleness: 'off', tracked_globs: nil)
        @root = File.absolute_path(root || '.')
        @resultset = resultset
        @checker = StalenessChecker.new(root: @root, resultset: @resultset, mode: staleness, tracked_globs: tracked_globs)
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

    # Returns [ { 'file' =>, 'covered' =>, 'total' =>, 'percentage' =>, 'stale' => }, ... ]
      def all_files(sort_order: :ascending, check_stale: !@checker.off?, tracked_globs: nil)
        stale_checker = StalenessChecker.new(root: @root, resultset: @resultset, mode: 'off', tracked_globs: tracked_globs)
        rows = @cov.map do |abs_path, data|
          next unless data['lines'].is_a?(Array)
          s = CovUtil.summary(data['lines'])
          stale = stale_checker.stale_for_file?(abs_path, data['lines'])
          { 'file' => abs_path, 'covered' => s['covered'], 'total' => s['total'], 'percentage' => s['pct'], 'stale' => stale }
        end.compact

        if check_stale
          StalenessChecker.new(root: @root, resultset: @resultset, mode: 'error', tracked_globs: tracked_globs)
                           .check_project!(@cov)
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
        @checker.check_file!(file_abs, coverage_lines) unless @checker.off?
      if coverage_lines.nil?
        raise FileError.new("No coverage data found for file: #{path}")
      end
      [file_abs, coverage_lines]
      rescue Errno::ENOENT => e
        raise FileNotFoundError.new("File not found: #{path}")
    end

      # staleness handled by StalenessChecker

      def check_all_files_staleness!(cov_timestamp, tracked_globs: nil)
        # handled by StalenessChecker
      end

      def rel_to_root(path)
        Pathname.new(path).relative_path_from(Pathname.new(File.absolute_path(@root))).to_s
      end

    # Detailed stale message construction moved to CoverageDataStaleError
  end
end
