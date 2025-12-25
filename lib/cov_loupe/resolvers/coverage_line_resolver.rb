# frozen_string_literal: true

module CovLoupe
  module Resolvers
    # Finds a SimpleCov line coverage array for a given file path.
    #
    # This is a string-based resolver: it does not touch the filesystem. It
    # looks up keys in the coverage map using a few heuristics:
    # 1) exact match on the provided path
    # 2) match after stripping the configured root prefix
    # 3) match by basename when the full path is unknown
    #
    # For portability, matching normalizes path separators to '/' so Windows
    # and Unix-style keys can be compared without mutating stored data.
    class CoverageLineResolver
      # @param cov_data [Hash] coverage data map keyed by file path
      # @param root [String, nil] project root used for path stripping
      def initialize(cov_data, root:)
        @cov_data = cov_data
        @root = root
      end

      # Resolve coverage lines for a file path, trying fallbacks before raising.
      # @param file_abs [String] absolute file path to resolve
      # @return [Array<Integer, nil>] SimpleCov-style line coverage array
      def lookup_lines(file_abs)
        # First try exact match
        direct_match = find_direct_match(file_abs)
        return direct_match if direct_match

        # Then try without current working directory prefix
        stripped_match = find_stripped_match(file_abs)
        return stripped_match if stripped_match

        # Finally try matching by basename
        basename_match = find_basename_match(file_abs)
        return basename_match if basename_match

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

      # Fallback to matching by basename when full path is unknown.
      private def find_basename_match(file_abs)
        target_basename = basename_for(file_abs)

        # Look for any key that ends with /target_basename or is exactly target_basename
        match_keys = cov_data.each_key.select do |key|
          normalized_key = normalize_path(key)
          normalized_key == target_basename || normalized_key.end_with?("/#{target_basename}")
        end

        return fetch_lines_for_path(match_keys.first) if match_keys.length == 1
        return if match_keys.empty?

        raise FileError, "Multiple coverage entries match basename #{target_basename}: #{match_keys.join(', ')}"
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
        return path if cov_data.key?(path)

        normalized = normalize_path(path)
        match_keys = cov_data.keys.select { |key| normalize_path(key) == normalized }
        return if match_keys.empty?
        return match_keys.first if match_keys.length == 1

        raise FileError, "Multiple coverage entries match path #{path}: #{match_keys.join(', ')}"
      end

      # Normalize separators for matching, keeping original values intact.
      private def normalize_path(path)
        path.to_s.tr('\\', '/')
      end

      # Derive a basename after normalizing separators.
      private def basename_for(path)
        normalize_path(path).split('/').last
      end

      private def raise_not_found_error(file_abs)
        raise FileError, "No coverage entry found for #{file_abs}"
      end

      # Entry may store exact line coverage.
      #
      # Returning nil tells callers to keep searching; the resolver will raise
      # a FileError if no variant yields coverage data.
      private def lines_from_entry(entry)
        return unless entry.is_a?(Hash)

        entry['lines']
      end
    end
  end
end
