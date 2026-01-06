# frozen_string_literal: true

require_relative '../path_utils'

module CovLoupe
  module Resolvers
    # Finds a SimpleCov line coverage array for a given file path.
    #
    # This is a string-based resolver: it does not touch the filesystem. It
    # looks up keys in the coverage map using two strategies:
    # 1) exact match on the provided path
    # 2) match after stripping the configured root prefix
    class CoverageLineResolver
      # @param cov_data [Hash] coverage data map keyed by file path
      # @param root [String, nil] project root used for path stripping
      # @param volume_case_sensitive [Boolean] whether the volume is case-sensitive
      def initialize(cov_data, root:, volume_case_sensitive:)
        @cov_data = cov_data
        @root = root
        @normalize_case = !volume_case_sensitive
      end

      # Resolve coverage lines for a file path, trying fallbacks before raising.
      # @param file_abs [String] absolute file path to resolve
      # @return [Array<Integer, nil>] SimpleCov-style line coverage array
      def lookup_lines(file_abs)
        # Normalize the input path first to handle platform-specific differences
        normalized_path = normalize_path(file_abs)

        # First try exact match
        direct_match = find_direct_match(normalized_path)
        return direct_match if direct_match

        # Then try without current working directory prefix
        stripped_match = find_stripped_match(normalized_path)
        return stripped_match if stripped_match

        raise_not_found_error(file_abs)
      end

      attr_reader :cov_data

      private def find_direct_match(file_abs)
        fetch_lines_for_path(file_abs)
      end

      # Try matching a path after removing the root prefix.
      private def find_stripped_match(file_abs)
        return unless @root

        normalized_file = normalize_path(file_abs)
        return unless normalized_file.start_with?(normalized_root_with_slash)

        relative_path = normalized_file[(normalized_root.length + 1)..]
        fetch_lines_for_path(relative_path)
      end

      # Fetch lines for a path, resolving normalized separators when needed.
      private def fetch_lines_for_path(path)
        key = resolve_key(path)
        return unless key

        entry = cov_data[key]
        lines = lines_from_entry(entry)
        return lines if lines

        raise CorruptCoverageDataError, "Entry for #{path} has no valid lines"
      end

      private def resolution_root
        @resolution_root ||= @root
      end

      private def normalized_root
        @normalized_root ||= normalize_path(resolution_root)
      end

      private def normalized_root_with_slash
        return unless normalized_root

        @normalized_root_with_slash ||= "#{normalized_root}/"
      end

      # Resolve the coverage key that matches a path (including normalized variants).
      private def resolve_key(path)
        normalized = normalize_path(path)
        match_keys = cov_data.keys.select { |key| normalize_path(key) == normalized }

        return if match_keys.empty?

        # If exact path match exists and it's the only one, return it
        return path if cov_data.key?(path) && match_keys.length == 1

        # If multiple matches, raise ambiguity error
        if match_keys.length > 1
          raise FileError, "Multiple coverage entries match path #{path}: #{match_keys.join(', ')}"
        end

        # Single match found, return it
        match_keys.first
      end

      # Normalize a path using centralized PathUtils
      private def normalize_path(path)
        PathUtils.normalize(path, normalize_case: @normalize_case)
      end

      private def raise_not_found_error(file_abs)
        raise FileError, "No coverage entry found for #{normalize_path(file_abs)}"
      end

      # Entry may store exact line coverage.
      #
      # Returning nil tells callers to keep searching; the resolver will raise
      # a FileError if no variant yields coverage data.
      private def lines_from_entry(entry)
        return unless entry.is_a?(Hash)

        lines = entry['lines']
        lines.is_a?(Array) ? lines : nil
      end
    end
  end
end
