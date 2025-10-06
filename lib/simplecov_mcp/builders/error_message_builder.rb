# frozen_string_literal: true

module SimpleCovMcp
  module Builders
    class ErrorMessageBuilder
      def self.build_file_error_message(file_path, operation, error_type: :not_found)
        case error_type
        when :not_found
          "File not found: #{file_path}"
        when :permission_denied
          "Permission denied: #{file_path}"
        when :unreadable
          "Cannot read file: #{file_path}"
        else
          "Error #{operation} file #{file_path}"
        end
      end

      def self.build_usage_error(subcommand_or_msg)
        if subcommand_or_msg.include?('<')
          "Usage: simplecov-mcp #{subcommand_or_msg}"
        else
          "Error: #{subcommand_or_msg}. Run 'simplecov-mcp --help' for usage information."
        end
      end

      def self.build_suggestion_message(invalid_option, correct_option, example_format: nil)
        base = "Error: '#{invalid_option}' is not a valid option. Did you mean '#{correct_option}'?"
        if example_format
          base + "\nTry: #{example_format.format(correct_option)}"
        end
        base
      end

      def self.build_enum_values_hint(option, valid_values, display_format = nil)
        display = display_format || valid_values.join(', ')
        "Valid values for #{option}: #{display}"
      end

      def self.build_log_message(error, context, include_stack_trace: false)
        parts = ["Error#{context ? " in #{context}" : ''}: #{error.class}: #{error.message}"]

        if include_stack_trace && error.backtrace
          parts << error.backtrace.join("\n")
        end

        parts.join("\n")
      end
    end
  end
end