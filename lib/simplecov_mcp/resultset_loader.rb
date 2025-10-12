# frozen_string_literal: true

require 'json'
require 'time'

require_relative 'errors'
require_relative 'util'

module SimpleCovMcp
  class ResultsetLoader
    Result = Struct.new(:coverage_map, :timestamp, :suite_names, keyword_init: true)
    SuiteEntry = Struct.new(:name, :coverage, :timestamp, keyword_init: true)

    class << self
      def load(resultset_path:)
        raw = JSON.parse(File.read(resultset_path))

        suites = extract_suite_entries(raw, resultset_path)
        raise CoverageDataError.new("No test suite with coverage data found in resultset file: #{resultset_path}") if suites.empty?

        coverage_map = build_coverage_map(suites, resultset_path)
        Result.new(
          coverage_map: coverage_map,
          timestamp: compute_combined_timestamp(suites),
          suite_names: suites.map(&:name)
        )
      end

      private

      def extract_suite_entries(raw, resultset_path)
        raw
          .select { |_, data| data.is_a?(Hash) && data.key?('coverage') && !data['coverage'].nil? }
          .map do |name, data|
            SuiteEntry.new(
              name: name.to_s,
              coverage: normalize_suite_coverage(data['coverage'], suite_name: name, resultset_path: resultset_path),
              timestamp: normalize_coverage_timestamp(data['timestamp'], data['created_at'])
            )
          end
      end

      def build_coverage_map(suites, resultset_path)
        return suites.first&.coverage if suites.length == 1

        merge_suite_coverages(suites, resultset_path)
      end

      def normalize_suite_coverage(coverage, suite_name:, resultset_path:)
        unless coverage.is_a?(Hash)
          raise CoverageDataError.new("Invalid coverage data structure for suite #{suite_name.inspect} in resultset file: #{resultset_path}")
        end

        needs_adaptation = coverage.values.any? { |value| value.is_a?(Array) }
        return coverage unless needs_adaptation

        coverage.each_with_object({}) do |(file, value), acc|
          acc[file] = value.is_a?(Array) ? { 'lines' => value } : value
        end
      end

      def merge_suite_coverages(suites, resultset_path)
        require_simplecov_for_merge!(resultset_path)
        log_duplicate_suite_names(suites)

        suites.reduce(nil) do |memo, suite|
          coverage = suite.coverage
          memo ? SimpleCov::Combine.combine(SimpleCov::Combine::ResultsCombiner, memo, coverage) : coverage
        end
      end

      def require_simplecov_for_merge!(resultset_path)
        require 'simplecov'
      rescue LoadError
        raise CoverageDataError.new(
          "Multiple coverage suites detected in #{resultset_path}, but the simplecov gem could not be loaded. Install simplecov to enable suite merging."
        )
      end

      def log_duplicate_suite_names(suites)
        grouped = suites.group_by(&:name)
        duplicates = grouped.select { |_, entries| entries.length > 1 }.keys
        return if duplicates.empty?

        message = "Merging duplicate coverage suites for #{duplicates.join(', ')}"
        CovUtil.log(message)
      rescue StandardError
        # Logging should never block coverage loading
      end

      def compute_combined_timestamp(suites)
        suites.map(&:timestamp).compact.max.to_i
      end

      def normalize_coverage_timestamp(timestamp_value, created_at_value)
        raw = timestamp_value.nil? ? created_at_value : timestamp_value
        return 0 if raw.nil?

        case raw
        when Integer
          raw
        when Float, Time
          raw.to_i
        when String
          normalize_string_timestamp(raw)
        else
          log_timestamp_warning(raw)
          0
        end
      rescue StandardError => e
        log_timestamp_warning(raw, e)
        0
      end

      def normalize_string_timestamp(value)
        str = value.strip
        return 0 if str.empty?

        if str.match?(/\A-?\d+(\.\d+)?\z/)
          str.to_f.to_i
        else
          Time.parse(str).to_i
        end
      end

      def log_timestamp_warning(raw_value, error = nil)
        message = "Coverage resultset timestamp could not be parsed: #{raw_value.inspect}"
        message = "#{message} (#{error.message})" if error
        CovUtil.log(message) rescue nil
      end
    end
  end
end
