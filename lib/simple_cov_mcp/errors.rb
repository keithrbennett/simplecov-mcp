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

    # Coverage data related errors
    class CoverageDataError < Error
      def user_friendly_message
        "Coverage data error: #{message}"
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
