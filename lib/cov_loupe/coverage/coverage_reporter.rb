# frozen_string_literal: true

module CovLoupe
  require_relative '../staleness/stale_status'

  # Reports files with coverage below a specified threshold.
  # Useful for displaying low coverage files after test runs.
  #
  # @example Basic usage in spec_helper.rb
  #   SimpleCov.at_exit do
  #     SimpleCov.result.format!
  #     report = CovLoupe::CoverageReporter.report(threshold: 80, count: 5)
  #     puts report if report
  #   end
  #
  # @example With custom resultset path
  #   CovLoupe::CoverageReporter.report(
  #     threshold: 80,
  #     count: 5,
  #     resultset: 'custom/coverage/.resultset.json'
  #   )
  #
  # @example With custom project root
  #   CovLoupe::CoverageReporter.report(
  #     threshold: 80,
  #     count: 5,
  #     root: '/path/to/project'
  #   )
  #
  module CoverageReporter
    module_function def report(threshold: 80, count: 5, model: nil, root: nil, resultset: nil)
      # Determine default root from SimpleCov if available
      default_root = defined?(SimpleCov) ? SimpleCov.root : '.'

      # Determine default resultset from SimpleCov if available
      default_resultset = if defined?(SimpleCov)
        File.join(SimpleCov.root, SimpleCov.coverage_dir, '.resultset.json')
      end

      model ||= CoverageModel.new(
        root: root || default_root,
        resultset: resultset || default_resultset
      )
      list_result = model.list(sort_order: :ascending)
      file_list = list_result['files']
        .select { |f| f['percentage'] && f['percentage'] < threshold }
        .first(count)
      file_list = model.relativize(file_list)

      return nil if file_list.empty?

      lines = ["\nLowest coverage files (< #{threshold}%):"]
      file_list.each do |f|
        label = f['file']
        if StaleStatus.stale?(f['stale'])
          label = "#{label} (stale: #{f['stale']})"
        end
        lines << format('  %5.1f%%  %s', f['percentage'], label)
      end
      lines.join("\n")
    end
  end
end
