# frozen_string_literal: true

require_relative '../resolvers/resolver_helpers'
require_relative '../resultset_loader'
require_relative '../errors'

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

      private def normalize_paths(map)
        return {} unless map

        map.transform_keys { |k| File.expand_path(k, @root) }
      end
    end
  end
end
