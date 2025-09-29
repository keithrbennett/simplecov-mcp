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

      begin
        # Parse resultset once to get both coverage data and timestamp
        rs = CovUtil.find_resultset(@root, resultset: resultset)
        raw = JSON.parse(File.read(rs))
        # SimpleCov typically writes a single test suite entry to .resultset.json
        # Find the first entry that has coverage data (skip comment entries)
        _suite, data = raw.find { |k, v| v.is_a?(Hash) && v.key?('coverage') }
        raise "No test suite with coverage data found in resultset file: #{rs}" unless data
        cov = data['coverage'] or raise "No 'coverage' key found in resultset file: #{rs}"
        @cov = cov.transform_keys { |k| File.absolute_path(k, @root) }
        @cov_timestamp = (data['timestamp'] || data['created_at'] || 0).to_i

        @checker = StalenessChecker.new(
          root: @root,
          resultset: @resultset,
          mode: staleness,
          tracked_globs: tracked_globs,
          timestamp: @cov_timestamp
        )
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
        stale_checker = StalenessChecker.new(
          root: @root,
          resultset: @resultset,
          mode: 'off',
          tracked_globs: tracked_globs,
          timestamp: @cov_timestamp
        )
        rows = @cov.map do |abs_path, data|
          next unless data['lines'].is_a?(Array)
          s = CovUtil.summary(data['lines'])
          stale = stale_checker.stale_for_file?(abs_path, data['lines'])
          { 'file' => abs_path, 'covered' => s['covered'], 'total' => s['total'], 'percentage' => s['pct'], 'stale' => stale }
        end.compact

        if check_stale
          StalenessChecker.new(
            root: @root,
            resultset: @resultset,
            mode: 'error',
            tracked_globs: tracked_globs,
            timestamp: @cov_timestamp
          ).check_project!(@cov)
        end

        rows.sort! do |a, b|
          pct_cmp = (sort_order.to_s == 'descending') ? (b['percentage'] <=> a['percentage']) : (a['percentage'] <=> b['percentage'])
          pct_cmp == 0 ? (a['file'] <=> b['file']) : pct_cmp
        end
        rows
      end

      # Returns formatted table string for all files coverage data
      def format_table(rows = nil, sort_order: :ascending, check_stale: !@checker.off?, tracked_globs: nil)
        rows = prepare_rows(rows, sort_order: sort_order, check_stale: check_stale, tracked_globs: tracked_globs)
        return "No coverage data found" if rows.empty?

        widths = compute_table_widths(rows)
        lines = []
        lines << border_line(widths, '┌', '┬', '┐')
        lines << header_row(widths)
        lines << border_line(widths, '├', '┼', '┤')
        rows.each { |file_data| lines << data_row(file_data, widths) }
        lines << border_line(widths, '└', '┴', '┘')
        lines << summary_counts(rows)
        lines.join("\n")
      end

    private

    def prepare_rows(rows, sort_order:, check_stale:, tracked_globs:)
      rows = if rows.nil?
               all_files(sort_order: sort_order, check_stale: check_stale, tracked_globs: tracked_globs)
             else
               sort_rows(rows.dup, sort_order: sort_order)
             end
      rows
    end

    def sort_rows(rows, sort_order: :ascending)
      rows.sort do |a, b|
        pct_cmp = (sort_order.to_s == 'descending') ? (b['percentage'] <=> a['percentage']) : (a['percentage'] <=> b['percentage'])
        pct_cmp == 0 ? (a['file'] <=> b['file']) : pct_cmp
      end
    end

    def compute_table_widths(rows)
      max_file_length = rows.map { |f| f['file'].length }.max.to_i
      file_width = [max_file_length, 'File'.length].max + 2
      pct_width = 8
      max_covered = rows.map { |f| f['covered'].to_s.length }.max
      max_total = rows.map { |f| f['total'].to_s.length }.max
      covered_width = [max_covered, 'Covered'.length].max + 2
      total_width = [max_total, 'Total'.length].max + 2
      stale_width = 'Stale'.length
      { file: file_width, pct: pct_width, covered: covered_width, total: total_width, stale: stale_width }
    end

    def border_line(widths, left, middle, right)
      h_line = ->(col_width) { '─' * (col_width + 2) }
      left +
        h_line.call(widths[:file]) +
        middle + h_line.call(widths[:pct]) +
        middle + h_line.call(widths[:covered]) +
        middle + h_line.call(widths[:total]) +
        middle + h_line.call(widths[:stale]) +
        right
    end

    def header_row(widths)
      sprintf(
        "│ %-#{widths[:file]}s │ %#{widths[:pct]}s │ %#{widths[:covered]}s │ %#{widths[:total]}s │ %#{widths[:stale]}s │",
        'File', ' %', 'Covered', 'Total', 'Stale'.center(widths[:stale])
      )
    end

    def data_row(file_data, widths)
      stale_text_str = file_data['stale'] ? '!' : ''
      sprintf(
        "│ %-#{widths[:file]}s │ %#{widths[:pct] - 1}.2f%% │ %#{widths[:covered]}d │ %#{widths[:total]}d │ %#{widths[:stale]}s │",
        file_data['file'],
        file_data['percentage'],
        file_data['covered'],
        file_data['total'],
        stale_text_str.center(widths[:stale])
      )
    end

    def summary_counts(rows)
      total = rows.length
      stale_count = rows.count { |f| f['stale'] }
      ok_count = total - stale_count
      "Files: total #{total}, ok #{ok_count}, stale #{stale_count}"
    end

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
