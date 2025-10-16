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

      # Convert standard Ruby errors to user-friendly custom errors
      def convert_standard_error(error)
        case error
        when Errno::ENOENT
          filename = extract_filename(error.message)
          FileNotFoundError.new("File not found: #{filename}", error)
        when Errno::EACCES
          filename = extract_filename(error.message)
          FilePermissionError.new("Permission denied accessing file: #{filename}", error)
        when Errno::EISDIR
          filename = extract_filename(error.message)
          NotAFileError.new("Expected file but found directory: #{filename}", error)
        when JSON::ParserError
          CoverageDataError.new("Invalid coverage data format - JSON parsing failed: #{error.message}", error)
        when ArgumentError
          if error.message.include?('wrong number of arguments')
            UsageError.new("Invalid number of arguments: #{error.message}", error)
          else
            ConfigurationError.new("Invalid configuration: #{error.message}", error)
          end
        when NoMethodError
          method_info = extract_method_info(error.message)
          CoverageDataError.new("Invalid coverage data structure - #{method_info}", error)
        when RuntimeError, StandardError
          # Handle string errors from CovUtil and other runtime errors
          if error.message.include?('Could not find .resultset.json')
            # Extract directory info if available
            dir_info = error.message.match(/under (.+?)(?:;|$)/)&.[](1) || 'project directory'
            CoverageDataError.new("Coverage data not found in #{dir_info} - please run your tests first", error)
          elsif error.message.include?('No .resultset.json found in directory')
            # Extract directory from error message
            dir_info = error.message.match(/directory: (.+)$/)&.[](1) || 'specified directory'
            CoverageDataError.new("Coverage data not found in directory: #{dir_info}", error)
          elsif error.message.include?('Specified resultset not found')
            # Extract path from error message
            path_info = error.message.match(/not found: (.+)$/)&.[](1) || 'specified path'
            ResultsetNotFoundError.new("Resultset file not found: #{path_info}", error)
          else
            Error.new("An unexpected error occurred: #{error.message}", error)
          end
        else
          Error.new("An unexpected error occurred: #{error.message}", error)
        end
      end

      private

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
