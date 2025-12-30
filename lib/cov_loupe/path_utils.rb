# frozen_string_literal: true

require 'pathname'

module CovLoupe
  # Centralized path handling utilities providing consistent normalization,
  # relativization, and absolutization across all components.
  module PathUtils
    # Platform detection - delegates to main CovLoupe module for testability
    def self.windows?
      CovLoupe.windows?
    end

    def self.windows_drive?
      File.expand_path('.').match?(/^[A-Za-z]:/)
    end

    # Normalizes a path by handling:
    # 1. Slash normalization (Windows backslashes -> forward slashes)
    # 2. Case normalization (case-insensitive volumes)
    # 3. Path cleaning (removing ., .., redundant separators)
    #
    # @param path [String, Pathname] path to normalize
    # @param options [Hash] normalization options
    # @option options [Boolean] :normalize_case (true on case-insensitive volumes)
    # @return [String] normalized path
    def self.normalize(path, options = {})
      return path if path.nil? || path.empty?

      result = path.to_s

      # Always normalize slashes on Windows (Pathname#cleanpath does this anyway)
      result = result.tr('\\', '/') if windows?

      # Handle case normalization for case-insensitive volumes
      if options.fetch(:normalize_case, !volume_case_sensitive?)
        result = result.downcase
      end

      # Clean path components
      Pathname.new(result).cleanpath.to_s
    end

    # Expands a path to absolute form, optionally relative to a base directory
    #
    # @param path [String] path to expand
    # @param base [String, nil] base directory (defaults to current working directory)
    # @return [String] absolute path
    def self.expand(path, base = nil)
      return path if path.nil? || path.empty?

      base ? File.expand_path(path, base) : File.expand_path(path)
    end

    # Converts an absolute path to a path relative to the given root
    #
    # @param path [String] absolute path to relativize
    # @param root [String] root directory for relativization
    # @return [String] relative path or original path if conversion fails
    def self.relativize(path, root)
      return path if path.nil? || path.empty? || root.nil? || root.empty?

      # Only expand relative paths against root; absolute paths expand without base
      abs_path = absolute?(path) ? expand(path) : expand(path, root)
      abs_root = expand(root)

      # Check if path is within root (handles different drives on Windows)
      return path unless abs_path.start_with?(root_prefix(abs_root)) || abs_path == abs_root

      Pathname.new(abs_path).relative_path_from(Pathname.new(abs_root)).to_s
    rescue ArgumentError
      # Path is on a different drive or cannot be made relative
      path
    end

    # Checks if a path is absolute
    #
    # @param path [String] path to check
    # @return [Boolean] true if path is absolute
    def self.absolute?(path)
      return false if path.nil? || path.empty?

      # Check for Windows drive paths (C:/, D:/, etc.)
      return true if path.match?(/^[A-Za-z]:[\/\\]/)

      Pathname.new(path).absolute?
    end

    # Checks if a path is relative
    #
    # @param path [String] path to check
    # @return [Boolean] true if path is relative
    def self.relative?(path)
      !absolute?(path)
    end

    # Checks if a path is within a given root directory
    #
    # @param path [String] path to check
    # @param root [String] root directory
    # @return [Boolean] true if path is within root
    def self.within_root?(path, root)
      return false if path.nil? || root.nil?

      abs_path = expand(path)
      abs_root = expand(root)

      abs_path == abs_root || abs_path.start_with?(root_prefix(abs_root))
    end

    # Extracts basename from a path, handling normalization
    #
    # @param path [String] path to extract basename from
    # @param options [Hash] options passed to normalize
    # @return [String] basename
    def self.basename(path, options = {})
      return '' if path.nil? || path.empty?

      normalize(path, options).split('/').last
    end

    # Joins path components using platform-appropriate separators
    #
    # @param components [Array<String>] path components
    # @return [String] joined path
    def self.join(*components)
      File.join(*components)
    end

    # Checks if volume is case-sensitive
    #
    # @return [Boolean] true if volume is case-sensitive
    def self.volume_case_sensitive?
      @volume_case_sensitive ||= !windows?
    end

    # Returns root path with trailing separator for prefix matching
    #
    # @param root [String] root path
    # @return [String] root with trailing separator
    def self.root_prefix(root)
      return '' if root.nil? || root.empty?

      root.end_with?(File::SEPARATOR) ? root : "#{root}#{File::SEPARATOR}"
    end
  end
end
