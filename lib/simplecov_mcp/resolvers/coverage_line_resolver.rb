# frozen_string_literal: true

module SimpleCovMcp
  module Resolvers
    class CoverageLineResolver
      def initialize(cov_data)
        @cov_data = cov_data
      end

      def lookup_lines(file_abs)
        # First try exact match
        if direct_match = find_direct_match(file_abs)
          return direct_match
        end

        # Then try without current working directory prefix
        if stripped_match = find_stripped_match(file_abs)
          return stripped_match
        end

        raise_not_found_error(file_abs)
      end

      private

      attr_reader :cov_data

      def find_direct_match(file_abs)
        entry = cov_data[file_abs]
        entry['lines'] if entry&.dig('lines').is_a?(Array)
      end

      def find_stripped_match(file_abs)
        return unless file_abs.start_with?(cwd_with_slash)

        relative_path = file_abs[(cwd.length + 1)..-1]
        entry = cov_data[relative_path]
        entry['lines'] if entry&.dig('lines').is_a?(Array)
      end

      def cwd
        @cwd ||= Dir.pwd
      end

      def cwd_with_slash
        @cwd_with_slash ||= "#{cwd}/"
      end

      def raise_not_found_error(file_abs)
        raise "No coverage entry found for #{file_abs}"
      end
    end
  end
end