# frozen_string_literal: true

require 'time'

module SimpleCovMcp
  # Lightweight service object to check staleness of coverage vs. sources
  class StalenessChecker
    MODES = %w[off error].freeze

    def initialize(root:, resultset:, mode: 'off', tracked_globs: nil)
      @root = File.absolute_path(root || '.')
      @resultset = resultset
      @mode = (mode || 'off').to_s
      @tracked_globs = tracked_globs
      @cov_timestamp = nil
      @resultset_path = nil
    end

    def off?
      @mode == 'off'
    end

    # Raise CoverageDataStaleError if stale (only in error mode)
    def check_file!(file_abs, coverage_lines)
      return if off?
      ts = coverage_timestamp
      fm = File.mtime(file_abs) if File.file?(file_abs)
      cov_len = coverage_lines.respond_to?(:length) ? coverage_lines.length : 0
      src_len = safe_count_lines(file_abs)
      if (fm && fm.to_i > ts.to_i) || (cov_len.positive? && src_len != cov_len)
        raise CoverageDataStaleError.new(
          nil,
          nil,
          file_path: rel(file_abs),
          file_mtime: fm,
          cov_timestamp: ts,
          src_len: src_len,
          cov_len: cov_len,
          resultset_path: resultset_path
        )
      end
    end

    # Compute whether a specific file appears stale relative to coverage.
    # Ignores mode and never raises; returns true when:
    # - the file is missing/deleted, or
    # - the file mtime is newer than the coverage timestamp, or
    # - the source line count differs from the coverage lines array length (when present).
    def stale_for_file?(file_abs, coverage_lines)
      ts = coverage_timestamp
      return true unless File.file?(file_abs)

      fm = File.mtime(file_abs)
      cov_len = coverage_lines.respond_to?(:length) ? coverage_lines.length : 0
      src_len = safe_count_lines(file_abs)
      (fm && fm.to_i > ts.to_i) || (cov_len.positive? && src_len != cov_len)
    rescue StandardError
      # Be conservative: if we cannot determine, mark as stale
      true
    end

    # Raise CoverageDataProjectStaleError if any covered file is newer or if
    # tracked files are missing from coverage, or coverage includes deleted files.
    def check_project!(coverage_map)
      return if off?
      ts = coverage_timestamp
      newer = []
      deleted = []
      coverage_files = coverage_map.keys
      coverage_files.each do |abs|
        if File.file?(abs)
          newer << rel(abs) if File.mtime(abs).to_i > ts.to_i
        else
          deleted << rel(abs)
        end
      end

      missing = []
      if @tracked_globs && !Array(@tracked_globs).empty?
        patterns = Array(@tracked_globs).map { |g| File.absolute_path(g, @root) }
        tracked = patterns.flat_map { |p| Dir.glob(p, File::FNM_EXTGLOB | File::FNM_PATHNAME) }
                          .select { |p| File.file?(p) }
        covered_set = coverage_files.to_set rescue coverage_files
        tracked.each do |abs|
          missing << rel(abs) unless covered_set.include?(abs)
        end
      end

      if !newer.empty? || !missing.empty? || !deleted.empty?
        raise CoverageDataProjectStaleError.new(
          nil,
          nil,
          cov_timestamp: ts,
          newer_files: newer,
          missing_files: missing,
          deleted_files: deleted,
          resultset_path: resultset_path
        )
      end
    end

    private

    def coverage_timestamp
      @cov_timestamp ||= CovUtil.latest_timestamp(@root, resultset: @resultset)
    end

    def resultset_path
      @resultset_path ||= CovUtil.find_resultset(@root, resultset: @resultset)
    rescue StandardError
      nil
    end

    def safe_count_lines(path)
      return 0 unless File.file?(path)
      File.foreach(path).count
    rescue StandardError
      0
    end

    def rel(path)
      Pathname.new(path).relative_path_from(Pathname.new(@root)).to_s
    end
  end
end
