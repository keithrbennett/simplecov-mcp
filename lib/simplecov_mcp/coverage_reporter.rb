# frozen_string_literal: true

module SimpleCovMcp
  # Reports files with coverage below a specified threshold.
  # Useful for displaying low coverage files after test runs.
  #
  # @example Basic usage in spec_helper.rb
  #   SimpleCov.at_exit do
  #     SimpleCov.result.format!
  #     report = SimpleCovMcp::CoverageReporter.report(threshold: 80, count: 5)
  #     puts report if report
  #   end
  #
  module CoverageReporter
    module_function

    # Returns formatted report of low coverage files.
    # @param threshold [Numeric] coverage percentage threshold (default: 80)
    # @param count [Integer] maximum number of files to return (default: 5)
    # @param model [CoverageModel, nil] optional model instance (creates one if nil)
    # @return [String, nil] formatted output string, or nil if no files below threshold
    def report(threshold: 80, count: 5, model: nil)
      model ||= CoverageModel.new
      file_list = model.all_files(sort_order: :ascending)
        .select { |f| f['percentage'] < threshold }
        .first(count)
      file_list = model.relativize(file_list)

      return nil if file_list.empty?

      lines = ["\nLowest coverage files (< #{threshold}%):"]
      file_list.each do |f|
        lines << format('  %5.1f%%  %s', f['percentage'], f['file'])
      end
      lines.join("\n")
    end
  end
end
