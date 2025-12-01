# frozen_string_literal: true

require 'time'
require 'json'

require_relative 'util'
require_relative 'errors'
require_relative 'error_handler'
require_relative 'staleness_checker'
require_relative 'path_relativizer'
require_relative 'resultset_loader'

module SimpleCovMcp
  class CoverageModel
    RELATIVIZER_SCALAR_KEYS = %w[file file_path].freeze
    RELATIVIZER_ARRAY_KEYS = %w[newer_files missing_files deleted_files].freeze

    attr_reader :relativizer

    # Create a CoverageModel
    #
    # Params:
    # - root: project root directory (default '.')
    # - resultset: path or directory to .resultset.json
    # - staleness: :off or :error (default :off). When :error, raises
    #   stale errors if sources are newer than coverage or line counts mismatch.
    # - tracked_globs: only used for all_files project-level staleness.
    def initialize(root: '.', resultset: nil, staleness: :off, tracked_globs: nil)
      @root = File.absolute_path(root || '.')
      @resultset = resultset
      @relativizer = PathRelativizer.new(
        root: @root,
        scalar_keys: RELATIVIZER_SCALAR_KEYS,
        array_keys: RELATIVIZER_ARRAY_KEYS
      )

      load_coverage_data(resultset, staleness, tracked_globs)
    end

    # Returns { 'file' => <absolute_path>, 'lines' => [hits|nil,...] }
    def raw_for(path)
      file_abs, coverage_lines = coverage_data_for(path)
      { 'file' => file_abs, 'lines' => coverage_lines }
    end

    def relativize(payload)
      relativizer.relativize(payload)
    end

    # Returns { 'file' => <absolute_path>, 'summary' => {'covered'=>, 'total'=>, 'percentage'=>} }
    def summary_for(path)
      file_abs, coverage_lines = coverage_data_for(path)
      { 'file' => file_abs, 'summary' => CovUtil.summary(coverage_lines) }
    end

    # Returns { 'file' => <absolute_path>, 'uncovered' => [line,...], 'summary' => {...} }
    def uncovered_for(path)
      file_abs, coverage_lines = coverage_data_for(path)
      {
        'file' => file_abs,
        'uncovered' => CovUtil.uncovered(coverage_lines),
        'summary' => CovUtil.summary(coverage_lines)
      }
    end

    # Returns { 'file' => <absolute_path>, 'lines' => [{'line'=>,'hits'=>,'covered'=>},...], 'summary' => {...} }
    def detailed_for(path)
      file_abs, coverage_lines = coverage_data_for(path)
      {
        'file' => file_abs,
        'lines' => CovUtil.detailed(coverage_lines),
        'summary' => CovUtil.summary(coverage_lines)
      }
    end

    # Returns [ { 'file' =>, 'covered' =>, 'total' =>, 'percentage' =>, 'stale' => }, ... ]
    def all_files(sort_order: :ascending, check_stale: !@checker.off?, tracked_globs: nil)
      stale_checker = build_staleness_checker(mode: :off, tracked_globs: tracked_globs)

      rows = @cov.map do |abs_path, _data|
        begin
          coverage_lines = CovUtil.lookup_lines(@cov, abs_path)
        rescue FileError
          next
        end

        s = CovUtil.summary(coverage_lines)
        stale = stale_checker.stale_for_file?(abs_path, coverage_lines)
        {
          'file' => abs_path,
          'covered' => s['covered'],
          'total' => s['total'],
          'percentage' => s['percentage'],
          'stale' => stale
        }
      end.compact

      rows = filter_rows_by_globs(rows, tracked_globs)

      if check_stale
        build_staleness_checker(mode: :error, tracked_globs: tracked_globs).check_project!(@cov)
      end

      sort_rows(rows, sort_order: sort_order)
    end

    def project_totals(tracked_globs: nil, check_stale: !@checker.off?)
      rows = all_files(sort_order: :ascending, check_stale: check_stale,
        tracked_globs: tracked_globs)
      totals_from_rows(rows)
    end

    def staleness_for(path)
      file_abs = File.absolute_path(path, @root)
      coverage_lines = CovUtil.lookup_lines(@cov, file_abs)
      @checker.stale_for_file?(file_abs, coverage_lines)
    rescue StandardError => e
      CovUtil.safe_log("Failed to check staleness for #{path}: #{e.message}")
      false
    end

    # Returns formatted table string for all files coverage data
    def format_table(rows = nil, sort_order: :ascending, check_stale: !@checker.off?,
      tracked_globs: nil)
      rows = prepare_rows(rows, sort_order: sort_order, check_stale: check_stale,
        tracked_globs: tracked_globs)
      return 'No coverage data found' if rows.empty?

      widths = compute_table_widths(rows)
      lines = []
      lines << border_line(widths, '┌', '┬', '┐')
      lines << header_row(widths)
      lines << border_line(widths, '├', '┼', '┤')
      rows.each { |file_data| lines << data_row(file_data, widths) }
      lines << border_line(widths, '└', '┴', '┘')
      lines << summary_counts(rows)
      if rows.any? { |f| f['stale'] }
        lines <<
          'Staleness: M = Missing file, T = Timestamp (source newer), L = Line count mismatch'
      end
      lines.join("\n")
    end

    private def load_coverage_data(resultset, staleness, tracked_globs)
      rs = CovUtil.find_resultset(@root, resultset: resultset)
      loaded = ResultsetLoader.load(resultset_path: rs)
      coverage_map = loaded.coverage_map or raise(CoverageDataError, "No 'coverage' key found in resultset file: #{rs}")

      @cov = coverage_map.transform_keys { |k| File.absolute_path(k, @root) }
      @cov_timestamp = loaded.timestamp

      @checker = StalenessChecker.new(
        root: @root,
        resultset: @resultset,
        mode: staleness,
        tracked_globs: tracked_globs,
        timestamp: @cov_timestamp
      )
    rescue SimpleCovMcp::Error
      raise # Re-raise our own errors as-is
    rescue => e
      raise ErrorHandler.new.convert_standard_error(e, context: :coverage_loading)
    end

    private def build_staleness_checker(mode:, tracked_globs:)
      StalenessChecker.new(
        root: @root,
        resultset: @resultset,
        mode: mode,
        tracked_globs: tracked_globs,
        timestamp: @cov_timestamp
      )
    end

    private def prepare_rows(rows, sort_order:, check_stale:, tracked_globs:)
      if rows.nil?
        all_files(sort_order: sort_order, check_stale: check_stale, tracked_globs: tracked_globs)
      else
        rows = sort_rows(rows.dup, sort_order: sort_order)
        filter_rows_by_globs(rows, tracked_globs)
      end
    end

    private def sort_rows(rows, sort_order: :ascending)
      rows.sort do |a, b|
        pct_cmp = (sort_order == :descending) \
                    ? (b['percentage'] <=> a['percentage'])
                    : (a['percentage'] <=> b['percentage'])
        pct_cmp == 0 ? (a['file'] <=> b['file']) : pct_cmp
      end
    end

    private def compute_table_widths(rows)
      max_file_length = rows.map { |f| f['file'].length }.max.to_i
      file_width = [max_file_length, 'File'.length].max + 2
      pct_width = 8
      max_covered = rows.map { |f| f['covered'].to_s.length }.max
      max_total = rows.map { |f| f['total'].to_s.length }.max
      covered_width = [max_covered, 'Covered'.length].max + 2
      total_width = [max_total, 'Total'.length].max + 2
      stale_width = 'Stale'.length
      {
        file: file_width,
        pct: pct_width,
        covered: covered_width,
        total: total_width,
        stale: stale_width
      }
    end

    private def border_line(widths, left, middle, right)
      h_line = ->(col_width) { '─' * (col_width + 2) }
      left +
        h_line.call(widths[:file]) +
        middle + h_line.call(widths[:pct]) +
        middle + h_line.call(widths[:covered]) +
        middle + h_line.call(widths[:total]) +
        middle + h_line.call(widths[:stale]) +
        right
    end

    private def header_row(widths)
      format(
        "│ %-#{widths[:file]}s │ %#{widths[:pct]}s │ %#{widths[:covered]}s │ %#{widths[:total]}s │ %#{widths[:stale]}s │",
        'File', ' %', 'Covered', 'Total', 'Stale'.center(widths[:stale])
      )
    end

    private def data_row(file_data, widths)
      stale_text_str = file_data['stale'] ? file_data['stale'].to_s : ''
      format(
        "│ %-#{widths[:file]}s │ %#{widths[:pct] - 1}.2f%% │ %#{widths[:covered]}d │ %#{widths[:total]}d │ %#{widths[:stale]}s │",
        file_data['file'],
        file_data['percentage'],
        file_data['covered'],
        file_data['total'],
        stale_text_str.center(widths[:stale])
      )
    end

    private def summary_counts(rows)
      total = rows.length
      stale_count = rows.count { |f| f['stale'] }
      ok_count = total - stale_count
      "Files: total #{total}, ok #{ok_count}, stale #{stale_count}"
    end

    # Filters coverage rows to only include files matching the given glob patterns.
    #
    # @param rows [Array<Hash>] coverage rows with 'file' keys containing absolute paths
    # @param tracked_globs [Array<String>, String, nil] glob patterns to match against
    # @return [Array<Hash>] rows whose files match at least one pattern (or all rows if no patterns)
    private def filter_rows_by_globs(rows, tracked_globs)
      patterns = Array(tracked_globs).compact.map(&:to_s).reject(&:empty?)
      return rows if patterns.empty?

      absolute_patterns = patterns.map { |p| absolutize_pattern(p) }
      rows.select { |row| matches_any_pattern?(row['file'], absolute_patterns) }
    end

    # Converts a relative pattern to absolute by joining with root.
    # Absolute patterns are returned unchanged.
    #
    # @param pattern [String] glob pattern (e.g., "lib/**/*.rb")
    # @return [String] absolute pattern
    private def absolutize_pattern(pattern)
      absolute_pattern?(pattern) ? pattern : File.join(@root, pattern)
    end

    # Checks if a pattern is absolute, handling both Unix and Windows-style paths.
    # On Unix, Pathname won't recognize "C:/" as absolute, so we check explicitly.
    #
    # @param pattern [String] glob pattern
    # @return [Boolean] true if pattern is absolute
    private def absolute_pattern?(pattern)
      Pathname.new(pattern).absolute? || pattern.match?(/\A[A-Za-z]:/)
    end

    # Tests if a file path matches any of the given absolute glob patterns.
    # Uses File.fnmatch? for pure string matching without filesystem access,
    # which is faster and works for paths that may no longer exist on disk.
    #
    # @param abs_path [String] absolute file path to test
    # @param patterns [Array<String>] absolute glob patterns
    # @return [Boolean] true if the path matches at least one pattern
    private def matches_any_pattern?(abs_path, patterns)
      flags = File::FNM_PATHNAME | File::FNM_EXTGLOB
      patterns.any? { |pattern| File.fnmatch?(pattern, abs_path, flags) }
    end

    # Retrieves coverage data for a file path.
    # Converts the path to absolute form and performs staleness checking if enabled.
    #
    # @param path [String] relative or absolute file path
    # @return [Array(String, Array)] tuple of [absolute_path, coverage_lines]
    # @raise [FileError] if no coverage data exists for the file
    # @raise [FileNotFoundError] if the file does not exist
    # @raise [CoverageDataStaleError] if staleness checking is enabled and data is stale
    private def coverage_data_for(path)
      file_abs = File.absolute_path(path, @root)
      begin
        coverage_lines = CovUtil.lookup_lines(@cov, file_abs)
      rescue RuntimeError
        raise FileError, "No coverage data found for file: #{path}"
      end
      @checker.check_file!(file_abs, coverage_lines) unless @checker.off?
      if coverage_lines.nil?
        raise FileError, "No coverage data found for file: #{path}"
      end

      [file_abs, coverage_lines]
    rescue Errno::ENOENT
      raise FileNotFoundError, "File not found: #{path}"
    end

    private def totals_from_rows(rows)
      covered = rows.sum { |row| row['covered'].to_i }
      total = rows.sum { |row| row['total'].to_i }
      uncovered = total - covered
      percentage = total.zero? ? 100.0 : ((covered.to_f * 100.0 / total) * 100).round / 100.0
      stale_count = rows.count { |row| row['stale'] }
      files_total = rows.length

      {
        'lines' => {
          'covered' => covered,
          'uncovered' => uncovered,
          'total' => total
        },
        'percentage' => percentage,
        'files' => {
          'total' => files_total,
          'ok' => files_total - stale_count,
          'stale' => stale_count
        }
      }
    end
  end
end
