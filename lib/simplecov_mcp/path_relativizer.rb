# frozen_string_literal: true

require 'pathname'

module SimpleCovMcp
  # Utility object that converts configured path-bearing keys to forms
  # relative to the project root while leaving the original payload untouched.
  class PathRelativizer
    def initialize(root:, scalar_keys:, array_keys: [])
      @root = Pathname.new(File.absolute_path(root || '.'))
      @scalar_keys = Array(scalar_keys).map(&:to_s).freeze
      @array_keys = Array(array_keys).map(&:to_s).freeze
    end

    def relativize(obj)
      deep_copy_and_relativize(obj)
    end

    # Converts an absolute path to a path relative to the root.
    # Falls back to the original path if conversion fails (e.g., different drive on Windows).
    #
    # @param path [String] file path (absolute or relative)
    # @return [String] relative path or original path on failure
    def relativize_path(path)
      root_str = @root.to_s
      abs = File.absolute_path(path, root_str)
      return path unless abs.start_with?(root_prefix(root_str)) || abs == root_str

      Pathname.new(abs).relative_path_from(@root).to_s
    rescue ArgumentError
      path
    end

    private def deep_copy_and_relativize(obj)
      case obj
      when Hash
        obj.each_with_object({}) do |(k, v), acc|
          acc[k] = relativize_value(k, v)
        end
      when Array
        obj.map { |item| deep_copy_and_relativize(item) }
      else
        obj
      end
    end

    private def relativize_value(key, value)
      key_str = key.to_s
      if @scalar_keys.include?(key_str) && value.is_a?(String)
        relativize_path(value)
      elsif @array_keys.include?(key_str) && value.is_a?(Array)
        value.map do |item|
          item.is_a?(String) ? relativize_path(item) : deep_copy_and_relativize(item)
        end
      else
        deep_copy_and_relativize(value)
      end
    end

    private def root_prefix(root_str)
      root_str.end_with?(File::SEPARATOR) ? root_str : root_str + File::SEPARATOR
    end
  end
end
