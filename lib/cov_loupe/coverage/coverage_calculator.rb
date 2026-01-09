# frozen_string_literal: true

module CovLoupe
  # Provides coverage data transformations and calculations.
  # Handles summary statistics, uncovered line identification, and detailed line-by-line analysis.
  class CoverageCalculator
    # Calculates coverage summary statistics from a coverage array.
    #
    # @param coverage_lines [Array<Integer, nil>] SimpleCov coverage array where each element
    #   represents a line: Integer for hit count, nil for non-code lines
    # @return [Hash] summary with 'covered', 'total', and 'percentage' keys
    def self.summary(coverage_lines)
      total = 0
      covered = 0
      coverage_lines.compact.each do |hits|
        total += 1
        covered += 1 if hits.to_i > 0
      end
      percentage = total <= 0 ? 100.0 : (covered.to_f / total * 100.0).round(2)
      { 'covered' => covered, 'total' => total, 'percentage' => percentage }
    end

    # Identifies uncovered line numbers from a coverage array.
    #
    # @param coverage_lines [Array<Integer, nil>] SimpleCov coverage array
    # @return [Array<Integer>] array of uncovered line numbers (1-indexed)
    def self.uncovered(coverage_lines)
      out = []

      coverage_lines.each_with_index do |hits, i|
        next if hits.nil?

        out << (i + 1) if hits.to_i.zero?
      end
      out
    end

    # Generates detailed line-by-line coverage information.
    #
    # @param coverage_lines [Array<Integer, nil>] SimpleCov coverage array
    # @return [Array<Hash>] array of hashes with 'line', 'hits', and 'covered' keys
    def self.detailed(coverage_lines)
      rows = []
      coverage_lines.each_with_index do |hits, i|
        next if hits.nil?

        h = hits.to_i
        rows << { 'line' => i + 1, 'hits' => h, 'covered' => h.positive? }
      end
      rows
    end
  end
end
