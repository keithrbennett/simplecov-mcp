# frozen_string_literal: true

require 'time'
require 'pathname'
require 'set' # rubocop:disable Lint/RedundantRequireStatement -- Ruby >= 3.4 requires explicit require for set; RuboCop targets 3.2
require_relative 'errors'
require_relative 'resolvers/resolver_helpers'

module CovLoupe
  # Lightweight service object to check staleness of coverage vs. sources
  class StalenessChecker
    MODES = [:off, :error].freeze

    def initialize(root:, resultset:, mode: :off, tracked_globs: nil, timestamp: nil)
      @root = File.expand_path(root || '.')
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

    # Compute and return project staleness details (newer, missing, deleted files).
    # If in error mode, raises CoverageDataProjectStaleError when issues are found.
    # Returns a hash { newer_files: [], missing_files: [], deleted_files: [] }
    def check_project!(coverage_map)
      ts = coverage_timestamp
      coverage_files = coverage_map.keys

      newer, deleted = compute_newer_and_deleted_files(coverage_files, ts)
      missing = compute_missing_files(coverage_files)

      staleness_details = {
        newer_files: newer,
        missing_files: missing,
        deleted_files: deleted
      }

      if @mode == :error && (newer.any? || missing.any? || deleted.any?)
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

      staleness_details
    end

    # Compute and return project staleness details including line-count mismatches.
    # If in error mode, raises CoverageDataProjectStaleError when issues are found.
    # Returns a hash with newer/missing/deleted/mismatched files and per-file statuses.
    def check_project_with_lines!(coverage_lines_by_path, coverage_files:)
      coverage_lines_by_path ||= {}
      ts = coverage_timestamp

      newer, deleted = compute_newer_and_deleted_files(coverage_files, ts)
      missing = compute_missing_files(coverage_files)

      file_statuses = {}
      length_mismatch = []

      coverage_lines_by_path.each do |abs_path, coverage_lines|
        details = compute_file_staleness_details(abs_path, coverage_lines)
        status = if !details[:exists]
          'M'
        elsif details[:newer]
          'T'
        elsif details[:len_mismatch]
          'L'
        else
          false
        end
        file_statuses[abs_path] = status
        length_mismatch << rel(abs_path) if details[:len_mismatch] && details[:exists]
      end

      # Ensure files are not reported as both "newer" and "length mismatch"
      # Length mismatch is the stronger signal for staleness
      newer -= length_mismatch

      staleness_details = {
        newer_files: newer,
        missing_files: missing,
        deleted_files: deleted,
        length_mismatch_files: length_mismatch,
        file_statuses: file_statuses
      }

      if @mode == :error && (newer.any? || missing.any? || deleted.any? || length_mismatch.any?)
        raise CoverageDataProjectStaleError.new(
          nil,
          nil,
          cov_timestamp: ts,
          newer_files: newer,
          missing_files: missing,
          deleted_files: deleted,
          length_mismatch_files: length_mismatch,
          resultset_path: resultset_path
        )
      end

      staleness_details
    end

    private def compute_newer_and_deleted_files(coverage_files, timestamp)
      existing, deleted_abs = coverage_files.partition { |abs| File.file?(abs) }

      newer = existing
        .select { |abs| File.mtime(abs).to_i > timestamp.to_i }
        .map { |abs| rel(abs) }
      deleted = deleted_abs.map { |abs| rel(abs) }

      [newer, deleted]
    end

    # Identifies tracked files that are missing from coverage.
    # Returns array of relative paths for files matched by tracked_globs but not in coverage.
    private def compute_missing_files(coverage_files)
      return [] unless @tracked_globs && Array(@tracked_globs).any?

      patterns = Array(@tracked_globs).map { |g| File.expand_path(g, @root) }
      tracked = patterns
        .flat_map { |p| Dir.glob(p, File::FNM_EXTGLOB | File::FNM_PATHNAME) }
        .select { |p| File.file?(p) }

      covered_set = coverage_files.to_set
      tracked.reject { |abs| covered_set.include?(abs) }.map { |abs| rel(abs) }
    end

    private def coverage_timestamp
      @cov_timestamp || 0
    end

    private def resultset_path
      @resultset_path ||= Resolvers::ResolverHelpers.find_resultset(@root, resultset: @resultset)
    rescue
      nil
    end

    private def safe_count_lines(path)
      return 0 unless File.file?(path)

      File.foreach(path).count
    rescue
      0
    end

    private def missing_trailing_newline?(path)
      return false unless File.file?(path)

      File.open(path, 'rb') do |f|
        size = f.size
        return false if size.zero?

        f.seek(-1, IO::SEEK_END)
        f.getbyte != 0x0A
      end
    rescue
      false
    end

    private def rel(path)
      # Handle relative vs absolute path mismatches that cause ArgumentError
      Pathname.new(path).relative_path_from(Pathname.new(@root)).to_s
    rescue ArgumentError
      # Path is outside the project root or has a different prefix type, fall back to absolute path
      path.to_s
    end

    # Centralized computation of staleness-related details for a single file.
    # Returns a Hash with keys:
    #  :exists, :file_mtime, :coverage_timestamp, :cov_len, :src_len, :newer, :len_mismatch
    private def compute_file_staleness_details(file_abs, coverage_lines)
      coverage_ts = coverage_timestamp

      exists = File.file?(file_abs)
      file_mtime = exists ? File.mtime(file_abs) : nil

      cov_len = coverage_lines.respond_to?(:length) ? coverage_lines.length : 0
      src_len = exists ? safe_count_lines(file_abs) : 0

      # Adjust source line count to handle edge cases with missing trailing newlines
      adjusted_src_len = adjust_line_count_for_missing_newline(
        file_abs: file_abs,
        exists: exists,
        cov_len: cov_len,
        src_len: src_len
      )

      # Check if the source file has been modified since coverage was generated
      len_mismatch = length_mismatch?(cov_len, adjusted_src_len)
      newer = check_file_newer_than_coverage(file_mtime, coverage_ts, len_mismatch)

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

    # Adjusts the source line count to account for files missing trailing newlines.
    #
    # Why this edge case exists:
    # - File.foreach counts lines by separator (typically \n)
    # - For a file with no trailing newline, File.foreach still counts all lines correctly
    # - However, some editors or file operations may report one extra line when checking
    #   if the file doesn't end with a newline
    # - SimpleCov's coverage array length matches the logical line count (excluding trailing newline)
    # - If src_len is exactly one more than cov_len AND the file is missing a trailing newline,
    #   we adjust src_len down by 1 to match SimpleCov's convention
    #
    # Example: A file with "line1\nline2\nline3" (no final \n)
    # - File.foreach counts: 3 lines
    # - SimpleCov coverage array length: 3
    # - No adjustment needed
    #
    # However, in certain edge cases where the file system or parsing reports an extra line:
    # - Reported line count: 4
    # - SimpleCov coverage array length: 3
    # - Missing trailing newline: true
    # - Adjustment: 4 - 1 = 3 (now matches)
    private def adjust_line_count_for_missing_newline(file_abs:, exists:, cov_len:, src_len:)
      # Only adjust if:
      # 1. File exists (can't check newlines for missing files)
      # 2. Coverage data is present (cov_len > 0)
      # 3. Source has exactly one more line than coverage
      # 4. File is missing a trailing newline
      needs_adjusting =
        exists && cov_len.positive? && src_len == cov_len + 1 && missing_trailing_newline?(file_abs)
      needs_adjusting ? src_len - 1 : src_len
    end

    # Checks if the source line count differs from the coverage line count.
    #
    # Why this check exists:
    # - When a file is modified after coverage is generated, the line count often changes
    # - A mismatch indicates the coverage data is stale and no longer represents the current file
    # - We only flag as mismatch when coverage data exists (cov_len > 0)
    #
    # Note: Empty coverage (cov_len == 0) is not considered a mismatch, as it may represent
    # files that were never executed or files that are legitimately empty.
    private def length_mismatch?(cov_len, adjusted_src_len)
      cov_len.positive? && adjusted_src_len != cov_len
    end

    # Determines if a file has been modified more recently than the coverage timestamp.
    #
    # Why this check exists:
    # - Files modified after coverage generation may have behavioral changes not captured
    # - However, if there's already a length mismatch, we prioritize that as the staleness indicator
    # - This prevents double-flagging: if lines changed, the file is already stale (length mismatch)
    #
    # The logic: newer &&= !len_mismatch means:
    # - If len_mismatch is true, set newer to false (length mismatch takes precedence)
    # - This way, staleness is categorized as either 'T' (time-based) OR 'L' (length-based), not both
    private def check_file_newer_than_coverage(file_mtime, coverage_ts, len_mismatch)
      newer = !!(file_mtime && file_mtime.to_i > coverage_ts.to_i)
      # If there's a length mismatch, don't also flag as "newer" - the mismatch is more specific
      newer &&= !len_mismatch
      newer
    end
  end
end
