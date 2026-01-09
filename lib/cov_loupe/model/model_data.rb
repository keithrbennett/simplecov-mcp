# frozen_string_literal: true

module CovLoupe
  # Immutable data container for coverage data loaded from a specific resultset file.
  # Holds the normalized coverage map, timestamp, and resultset path.
  #
  # This class has no awareness of caching - it's managed by ModelDataCache.
  #
  # @attr_reader coverage_map [Hash] Map of absolute file paths to coverage data
  # @attr_reader timestamp [Integer] Latest timestamp from coverage suites
  # @attr_reader resultset_path [String] Absolute path to the .resultset.json file
  ModelData = Data.define(:coverage_map, :timestamp, :resultset_path)
end
