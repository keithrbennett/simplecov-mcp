# frozen_string_literal: true

module CovLoupe
  module GlobUtils
    GLOB_MATCH_FLAGS = File::FNM_PATHNAME | File::FNM_EXTGLOB

    module_function def normalize_patterns(globs)
      Array(globs).compact.map(&:to_s).reject(&:empty?)
    end

    # Converts a pattern to absolute path relative to a root.
    # Handles both relative patterns ("lib/*.rb") and absolute ones ("/tmp/*.rb").
    #
    # @param pattern [String] glob pattern
    # @param root [String] root directory path
    # @return [String] absolute pattern
    module_function def absolutize_pattern(pattern, root)
      File.absolute_path(pattern, root)
    end

    # Tests if a file path matches any of the given absolute glob patterns.
    # Uses File.fnmatch? for pure string matching without filesystem access.
    #
    # @param abs_path [String] absolute file path to test
    # @param patterns [Array<String>] absolute glob patterns
    # @return [Boolean] true if the path matches at least one pattern
    module_function def matches_any_pattern?(abs_path, patterns)
      patterns.any? { |pattern| File.fnmatch?(pattern, abs_path, GLOB_MATCH_FLAGS) }
    end

    # Filters items where a key contains a file path matching the patterns.
    #
    # @param items [Array<Hash>] items to filter
    # @param patterns [Array<String>] absolute glob patterns
    # @param key [String] key in item hash containing the absolute file path
    # @return [Array<Hash>] items whose file path matches at least one pattern
    module_function def filter_by_pattern(items, patterns, key: 'file')
      return items if patterns.nil? || patterns.empty?

      items.select { |item| matches_any_pattern?(item[key], patterns) }
    end
  end
end
