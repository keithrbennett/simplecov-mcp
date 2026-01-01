# frozen_string_literal: true

require_relative 'staleness_message_formatter'

module CovLoupe
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
  end

  # Configuration or setup related errors
  class ConfigurationError < Error
    def user_friendly_message
      "Configuration error: #{message}"
    end
  end

  # Error wrapper when the root cause is unknown or unclassified.
  class UnknownError < Error
    def user_friendly_message
      "An unexpected error occurred: #{message}"
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

  class ResultsetNotFoundError < FileError
    def user_friendly_message
      base = "File error: #{message}"

      # Only add helpful tips in CLI and library modes, not MCP mode
      unless CovLoupe.context.mcp_mode?
        base += <<~HELP


          Try one of the following:
            - cd to a directory containing coverage/.resultset.json
            - Specify a resultset: cov-loupe -r PATH
            - Use -h for help: cov-loupe -h
        HELP
      end

      base
    end
  end

  # Coverage data related errors
  class CoverageDataError < Error
    def user_friendly_message
      "Coverage data error: #{message}"
    end
  end

  class CorruptCoverageDataError < CoverageDataError
    def user_friendly_message
      "Corrupt coverage data: #{message}"
    end
  end

  # Shared module for stale error formatting
  module StalenessFormatterMixin
    private def formatter
      @formatter ||= StalenessMessageFormatter.new(
        cov_timestamp: @cov_timestamp,
        resultset_path: @resultset_path
      )
    end
  end

  # Coverage data is present but appears stale compared to source files
  class CoverageDataStaleError < CoverageDataError
    include StalenessFormatterMixin

    attr_reader :file_path, :file_mtime, :cov_timestamp, :src_len, :cov_len, :resultset_path

    def initialize(message = nil, original_error = nil, file_path: nil, file_mtime: nil,
      cov_timestamp: nil, src_len: nil, cov_len: nil, resultset_path: nil)
      @file_path = file_path
      @file_mtime = file_mtime
      @cov_timestamp = cov_timestamp
      @src_len = src_len
      @cov_len = cov_len
      @resultset_path = resultset_path
      super(message || default_message, original_error)
    end

    def user_friendly_message
      "Coverage data stale: #{message}" + formatter.format_single_file_details(
        file_path: @file_path,
        file_mtime: @file_mtime,
        src_len: @src_len,
        cov_len: @cov_len
      )
    end

    private def default_message
      fp = file_path || 'file'
      "Coverage data appears stale for #{fp}"
    end
  end

  # Project-level stale coverage (global) — coverage timestamp older than
  # one or more source files, or new tracked files missing from coverage.
  class CoverageDataProjectStaleError < CoverageDataError
    include StalenessFormatterMixin

    attr_reader :cov_timestamp, :newer_files, :missing_files, :deleted_files,
      :length_mismatch_files, :unreadable_files, :resultset_path

    def initialize(message = nil, original_error = nil, cov_timestamp: nil, newer_files: [],
      missing_files: [], deleted_files: [], length_mismatch_files: [], unreadable_files: [],
      resultset_path: nil)
      super(message, original_error)
      @cov_timestamp = cov_timestamp
      @newer_files = Array(newer_files)
      @missing_files = Array(missing_files)
      @deleted_files = Array(deleted_files)
      @length_mismatch_files = Array(length_mismatch_files)
      @unreadable_files = Array(unreadable_files)
      @resultset_path = resultset_path
    end

    def user_friendly_message
      base = "Coverage data stale (project): #{message || default_message}"
      base + formatter.format_project_details(
        newer_files: @newer_files,
        missing_files: @missing_files,
        deleted_files: @deleted_files,
        length_mismatch_files: @length_mismatch_files,
        unreadable_files: @unreadable_files
      )
    end

    private def default_message
      'Coverage data appears stale for project'
    end
  end

  # Command line usage errors
  class UsageError < Error
    def self.for_subcommand(usage_fragment)
      new("Usage: cov-loupe #{usage_fragment}")
    end

    def user_friendly_message
      message
    end
  end
end
