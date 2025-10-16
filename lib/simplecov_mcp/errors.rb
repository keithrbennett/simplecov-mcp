# frozen_string_literal: true

module SimpleCovMcp
  # Base error class for all SimpleCov MCP errors
  class Error < StandardError
    attr_reader :original_error

    def initialize(message = nil, original_error = nil)
      @original_error = original_error
      super(message)
    end

    def user_friendly_message
      message
    end

    protected

    def format_epoch_both(epoch_seconds)
      return [nil, nil] unless epoch_seconds

      t = Time.at(epoch_seconds.to_i)
      [t.utc.iso8601, t.getlocal.iso8601]
    rescue StandardError
      [epoch_seconds.to_s, epoch_seconds.to_s]
    end

    def format_time_both(time)
      return [nil, nil] unless time

      t = time.is_a?(Time) ? time : Time.parse(time.to_s)
      [t.utc.iso8601, t.getlocal.iso8601]
    rescue StandardError
      [time.to_s, time.to_s]
    end

    def format_delta_seconds(file_mtime, cov_timestamp)
      return nil unless file_mtime && cov_timestamp

      seconds = file_mtime.to_i - cov_timestamp.to_i
      sign = seconds >= 0 ? '+' : '-'
      "#{sign}#{seconds.abs}s"
    rescue StandardError
      nil
    end
  end

  # Configuration or setup related errors
  class ConfigurationError < Error
    def user_friendly_message
      "Configuration error: #{message}"
    end
  end

  # File or path related errors
  class FileError < Error
    def user_friendly_message
      "File error: #{message}"
    end
  end

  # More specific file errors
  class FileNotFoundError < FileError; end
  class FilePermissionError < FileError; end
  class NotAFileError < FileError; end
  class ResultsetNotFoundError < FileError; end

  # Coverage data related errors
  class CoverageDataError < Error
    def user_friendly_message
      "Coverage data error: #{message}"
    end
  end

  # Coverage data is present but appears stale compared to source files
  class CoverageDataStaleError < CoverageDataError
    attr_reader :file_path, :file_mtime, :cov_timestamp, :src_len, :cov_len, :resultset_path

    def initialize(message = nil, original_error = nil, file_path: nil, file_mtime: nil, 
      cov_timestamp: nil, src_len: nil, cov_len: nil, resultset_path: nil)
      super(message, original_error)
      @file_path = file_path
      @file_mtime = file_mtime
      @cov_timestamp = cov_timestamp
      @src_len = src_len
      @cov_len = cov_len
      @resultset_path = resultset_path
    end

    def user_friendly_message
      base = "Coverage data stale: #{message || default_message}"
      base + build_details
    end

    private

    def default_message
      fp = file_path || 'file'
      "Coverage data appears stale for #{fp}"
    end

    def build_details
      file_utc, file_local = format_time_both(@file_mtime)
      cov_utc,  cov_local  = format_epoch_both(@cov_timestamp)
      delta_str = format_delta_seconds(@file_mtime, @cov_timestamp)

      details = <<~DETAILS

        File     - time: #{file_utc || 'not found'} (local #{file_local || 'n/a'}), lines: #{@src_len}
        Coverage - time: #{cov_utc  || 'not found'} (local #{cov_local  || 'n/a'}), lines: #{@cov_len}
        DETAILS

      details += "\nDelta    - file is #{delta_str} newer than coverage" if delta_str
      details += "\nResultset - #{@resultset_path}" if @resultset_path
      details.chomp
    end
  end

  # Project-level stale coverage (global) — coverage timestamp older than
  # one or more source files, or new tracked files missing from coverage.
  class CoverageDataProjectStaleError < CoverageDataError
    attr_reader :cov_timestamp, :newer_files, :missing_files, :deleted_files, :resultset_path

    def initialize(message = nil, original_error = nil, cov_timestamp: nil, newer_files: [], 
      missing_files: [], deleted_files: [], resultset_path: nil)
      super(message, original_error)
      @cov_timestamp = cov_timestamp
      @newer_files = Array(newer_files)
      @missing_files = Array(missing_files)
      @deleted_files = Array(deleted_files)
      @resultset_path = resultset_path
    end

    def user_friendly_message
      base = "Coverage data stale (project): #{message || default_message}"
      base + build_details
    end

    private

    def default_message
      'Coverage data appears stale for project'
    end

    def build_details
      cov_utc, cov_local = format_epoch_both(@cov_timestamp)
      parts = []
      parts << "\nCoverage  - time: #{cov_utc || 'not found'} (local #{cov_local || 'n/a'})"
      unless @newer_files.empty?
        parts << "\nNewer files (#{@newer_files.size}):"
        parts.concat(@newer_files.first(10).map { |f| "  - #{f}" })
        parts << '  ...' if @newer_files.size > 10
      end
      unless @missing_files.empty?
        parts << "\nMissing files (new in project, not in coverage, #{@missing_files.size}):"
        parts.concat(@missing_files.first(10).map { |f| "  - #{f}" })
        parts << '  ...' if @missing_files.size > 10
      end
      unless @deleted_files.empty?
        parts << "\nCoverage-only files (deleted or moved in project, #{@deleted_files.size}):"
        parts.concat(@deleted_files.first(10).map { |f| "  - #{f}" })
        parts << '  ...' if @deleted_files.size > 10
      end
      parts << "\nResultset - #{@resultset_path}" if @resultset_path
      parts.join
    end
  end

  # Command line usage errors
  class UsageError < Error
    def self.for_subcommand(usage_fragment)
      new("Usage: simplecov-mcp #{usage_fragment}")
    end

    def user_friendly_message
      message
    end
  end
end
