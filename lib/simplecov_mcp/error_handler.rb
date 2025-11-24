# frozen_string_literal: true

require 'json'
require_relative 'errors'
require_relative 'util'

module SimpleCovMcp
  # Handles error reporting and logging with configurable behavior
  class ErrorHandler
    attr_accessor :error_mode, :logger

    VALID_ERROR_MODES = [:off, :on, :trace].freeze

    def initialize(error_mode: :on, logger: nil)
      unless VALID_ERROR_MODES.include?(error_mode)
        raise ArgumentError, "Invalid error_mode: #{error_mode.inspect}. Valid modes: #{VALID_ERROR_MODES.inspect}"
      end

      @error_mode = error_mode
      @logger = logger
    end

    def log_errors?
      error_mode != :off
    end

    def show_stack_traces?
      error_mode == :trace
    end

    # Handle an error with appropriate logging and re-raising behavior
    def handle_error(error, context: nil, reraise: true)
      log_error(error, context)
      if reraise
        raise error.is_a?(SimpleCovMcp::Error) ? error : convert_standard_error(error)
      end
    end

    # Convert standard Ruby errors to user-friendly custom errors.
    # @param error [Exception] the error to convert
    # @param context [Symbol] :general (default) or :coverage_loading for context-specific messages
    def convert_standard_error(error, context: :general)
      case error
      when Errno::ENOENT
        convert_enoent(error, context)
      when Errno::EACCES
        convert_eacces(error, context)
      when Errno::EISDIR
        filename = extract_filename(error.message)
        NotAFileError.new("Expected file but found directory: #{filename}", error)
      when JSON::ParserError
        CoverageDataError.new("Invalid coverage data format: #{error.message}", error)
      when TypeError
        CoverageDataError.new("Invalid coverage data structure: #{error.message}", error)
      when ArgumentError
        convert_argument_error(error, context)
      when NoMethodError
        convert_no_method_error(error, context)
      when RuntimeError
        convert_runtime_error(error, context)
      when StandardError
        Error.new("An unexpected error occurred: #{error.message}", error)
      else
        Error.new("An unexpected error occurred: #{error.message}", error)
      end
    end

    private

    def convert_enoent(error, context)
      if context == :coverage_loading
        ResultsetNotFoundError.new('Coverage data not found', error)
      else
        filename = extract_filename(error.message)
        FileNotFoundError.new("File not found: #{filename}", error)
      end
    end

    def convert_eacces(error, context)
      if context == :coverage_loading
        FilePermissionError.new("Permission denied reading coverage data: #{error.message}", error)
      else
        filename = extract_filename(error.message)
        FilePermissionError.new("Permission denied accessing file: #{filename}", error)
      end
    end

    def convert_argument_error(error, context)
      if context == :coverage_loading
        CoverageDataError.new("Invalid path in coverage data: #{error.message}", error)
      elsif error.message.include?('wrong number of arguments')
        UsageError.new("Invalid number of arguments: #{error.message}", error)
      else
        ConfigurationError.new("Invalid configuration: #{error.message}", error)
      end
    end

    def convert_no_method_error(error, context)
      if context == :coverage_loading
        CoverageDataError.new("Invalid coverage data structure: #{error.message}", error)
      else
        method_info = extract_method_info(error.message)
        CoverageDataError.new("Invalid coverage data structure - #{method_info}", error)
      end
    end

    def convert_runtime_error(error, context)
      message = error.message
      if message.include?('Could not find .resultset.json')
        dir_info = message.match(/under (.+?)(?:;|$)/)&.[](1) || 'project directory'
        CoverageDataError.new("Coverage data not found in #{dir_info} - please run your tests first", error)
      elsif message.include?('No .resultset.json found in directory')
        dir_info = message.match(/directory: (.+)$/)&.[](1) || 'specified directory'
        CoverageDataError.new("Coverage data not found in directory: #{dir_info}", error)
      elsif message.include?('Specified resultset not found')
        # Preserve the original message format for consistency with existing tests
        ResultsetNotFoundError.new(message, error)
      elsif context == :coverage_loading && message.downcase.include?('resultset')
        ResultsetNotFoundError.new(message, error)
      elsif context == :coverage_loading
        CoverageDataError.new("Failed to load coverage data: #{message}", error)
      else
        Error.new("An unexpected error occurred: #{message}", error)
      end
    end

    def log_error(error, context)
      return unless log_errors?

      message = build_log_message(error, context)
      if logger
        logger.error(message)
      else
        CovUtil.log(message)
      end
    end

    def build_log_message(error, context)
      parts = ["Error#{context ? " in #{context}" : ''}: #{error.class}: #{error.message}"]

      if show_stack_traces? && error.backtrace
        parts << error.backtrace.join("\n")
      end

      parts.join("\n")
    end

    def extract_filename(message)
      # Extract filename from "No such file or directory @ rb_sysopen - filename"
      match = message.match(/@ \w+ - (.+)$/)
      match ? match[1] : 'unknown file'
    end

    def extract_method_info(message)
      # Extract method info from "undefined method `foo' for #<Object:0x...>"
      if match = message.match(/undefined method `(.+?)' for (.+)$/)
        method_name = match[1]
        object_info = match[2].gsub(/#<.*?>/, 'object')
        "missing method '#{method_name}' on #{object_info}"
      else
        message
      end
    end
  end
end
