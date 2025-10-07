# frozen_string_literal: true

require 'time'
require 'json'

module SimpleCovMcp
  # Lightweight service object to check staleness of coverage vs. sources
  class StalenessChecker
    MODES = [:off, :error].freeze

    def initialize(root:, resultset:, mode: :off, tracked_globs: nil, timestamp: nil)
      @root = File.absolute_path(root || '.')
      @resultset = resultset
      @mode = (mode || :off).to_sym
      @tracked_globs = tracked_globs
      @cov_timestamp = timestamp
      @resultset_path = nil
    end

    def off?
      @mode == :off
    end

    # Raise CoverageDataStaleError if stale (only in error mode)
    def check_file!(file_abs, coverage_lines)
      return if off?
      d = compute_file_staleness_details(file_abs, coverage_lines)
      # For single-file checks, missing files with recorded coverage count as stale
      # via length mismatch; project-level checks also handle deleted files explicitly.
      if d[:newer] || d[:len_mismatch]
        raise CoverageDataStaleError.new(
          nil,
          nil,
          file_path: rel(file_abs),
          file_mtime: d[:file_mtime],
          cov_timestamp: d[:coverage_timestamp],
          src_len: d[:src_len],
          cov_len: d[:cov_len],
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
      d = compute_file_staleness_details(file_abs, coverage_lines)
      return 'M' unless d[:exists]
      return 'T' if d[:newer]
      return 'L' if d[:len_mismatch]
      false
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
      @cov_timestamp || 0
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

    def missing_trailing_newline?(path)
      return false unless File.file?(path)

      File.open(path, 'rb') do |f|
        size = f.size
        return false if size.zero?

        f.seek(-1, IO::SEEK_END)
        f.getbyte != 0x0A
      end
    rescue StandardError
      false
    end

    def rel(path)
      Pathname.new(path).relative_path_from(Pathname.new(@root)).to_s
    end

    # Centralized computation of staleness-related details for a single file.
    # Returns a Hash with keys:
    #  :exists, :file_mtime, :coverage_timestamp, :cov_len, :src_len, :newer, :len_mismatch
    def compute_file_staleness_details(file_abs, coverage_lines)
      coverage_ts = coverage_timestamp

      exists = File.file?(file_abs)
      file_mtime = exists ? File.mtime(file_abs) : nil

      cov_len = coverage_lines.respond_to?(:length) ? coverage_lines.length : 0

      src_len = exists ? safe_count_lines(file_abs) : 0

      newer = !!(file_mtime && file_mtime.to_i > coverage_ts.to_i)

      adjusted_src_len = src_len
      if exists && cov_len.positive? && src_len == cov_len + 1 && missing_trailing_newline?(file_abs)
        adjusted_src_len -= 1
      end

      len_mismatch = (cov_len.positive? && adjusted_src_len != cov_len)

      {
        exists: exists,
        file_mtime: file_mtime,
        coverage_timestamp: coverage_ts,
        cov_len: cov_len,
        src_len: src_len,
        newer: newer,
        len_mismatch: len_mismatch
      }
    end
  end
end
