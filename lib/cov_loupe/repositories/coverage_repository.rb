# frozen_string_literal: true

require 'json'
require_relative '../resolvers/resolver_helpers'
require_relative '../resultset_loader'
require_relative '../errors'
require_relative '../path_utils'

module CovLoupe
  module Repositories
    # CoverageRepository handles the discovery, loading, and normalization of SimpleCov
    # coverage data. It decouples data access concerns from the domain logic in CoverageModel.
    #
    # Its primary responsibilities are:
    # 1. Locating the .resultset.json file using ResolverHelpers.
    # 2. Loading and parsing the JSON data using ResultsetLoader (handling suite merging if needed).
    # 3. Normalizing all coverage map keys to absolute paths relative to the project root.
    #
    # @attr_reader coverage_map [Hash] A map of absolute file paths to coverage data.
    # @attr_reader timestamp [Integer] The latest timestamp from the loaded coverage suites.
    # @attr_reader resultset_path [String] The resolved absolute path to the .resultset.json file.
    class CoverageRepository
      attr_reader :coverage_map, :timestamp, :resultset_path

      def initialize(root:, resultset_path: nil, logger: nil)
        @root = root
        @logger = logger || CovLoupe.logger

        begin
          # 1. Locate the file
          @resultset_path = resolve_resultset_path(resultset_path)

          # 2. Load the data
          loaded_data = load_data

          # 3. Normalize keys to absolute paths
          @coverage_map = normalize_paths(loaded_data.coverage_map)
          @timestamp = loaded_data.timestamp
        rescue CovLoupe::Error
          raise # Re-raise our own errors as-is
        rescue => e
          raise ErrorHandler.new.convert_standard_error(e, context: :coverage_loading)
        end
      end

      private def resolve_resultset_path(path_arg)
        Resolvers::ResolverHelpers.find_resultset(@root, resultset: path_arg)
      end

      private def load_data
        ResultsetLoader.load(resultset_path: @resultset_path, logger: @logger)
      end

      # Normalizes all coverage map keys to absolute paths and detects collisions.
      #
      # This method transforms relative and mixed-case paths to their canonical absolute
      # form. If multiple original keys normalize to the same path (e.g., "lib/foo.rb" and
      # "/full/path/lib/foo.rb"), this indicates corrupt or problematic coverage data that
      # would otherwise silently overwrite earlier entries.
      #
      # @param map [Hash] Original coverage map with potentially relative/mixed keys
      # @return [Hash] Normalized coverage map with absolute path keys
      # @raise [CoverageDataError] If duplicate keys normalize to the same path
      private def normalize_paths(map)
        return {} unless map

        result = {}
        # Track which original keys map to each normalized key to detect collisions
        # Example: { "/abs/path/lib/foo.rb" => ["lib/foo.rb", "/abs/path/lib/foo.rb"] }
        provided_paths_by_normalized_path = Hash.new { |h, k| h[k] = [] }

        # First pass: normalize all keys and track the mapping
        map.each do |original_key, value|
          normalized_key = PathUtils.expand(original_key, @root)
          provided_paths_by_normalized_path[normalized_key] << original_key
          result[normalized_key] = value
        end

        # Second pass: detect collisions (any normalized key with multiple original keys)
        collisions = provided_paths_by_normalized_path.select do |_norm_key, orig_keys|
          orig_keys.size > 1
        end

        collisions.empty? ? result : raise_collision_error(collisions)
      end

      # Raises a CoverageDataError with details about path normalization collisions.
      #
      # Formats collision data as parseable JSON with each collision on one line:
      #   {
      #     "/full/path/lib/foo.rb": ["lib/foo.rb", "/full/path/lib/foo.rb"],
      #     "/full/path/lib/bar.rb": ["lib/bar.rb", "/full/path/lib/bar.rb"]
      #   }
      #
      # @param collisions [Hash] Map of normalized paths to arrays of original keys
      # @raise [CoverageDataError] Always raises with formatted collision details
      private def raise_collision_error(collisions)
        json_lines = collisions.map do |norm_key, orig_keys|
          "  #{JSON.generate(norm_key)}: #{JSON.generate(orig_keys)}"
        end
        details = "{\n#{json_lines.join(",\n")}\n}"

        raise CoverageDataError,
          "Duplicate paths detected after normalization. The following keys normalize to the same path:\n#{details}"
      end
    end
  end
end
