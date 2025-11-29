# frozen_string_literal: true

require_relative '../base_tool'
require_relative '../model'
require_relative '../presenters/coverage_raw_presenter'

module SimpleCovMcp
  module Tools
    class CoverageRawTool < BaseTool
      description <<~DESC
        Use this when you need the raw SimpleCov `lines` array for a file exactly as stored on disk.
        Do not use this for human-friendly explanations; choose coverage.detailed or coverage.summary instead.
        Inputs: file path (required) plus optional root/resultset/staleness mode inherited from BaseTool.
        Output: JSON object with "file" and "lines" (array of integers/nulls) mirroring SimpleCov's native structure, plus "stale" status.
        Example: "Fetch the raw coverage array for spec/support/foo_helper.rb".
      DESC
      input_schema(**input_schema_def)
      class << self
        def call(path:, root: '.', resultset: nil, staleness: :off, error_mode: 'on',
          server_context:)
          with_error_handling('CoverageRawTool', error_mode: error_mode) do
            model = CoverageModel.new(
              root: root,
              resultset: resultset,
              staleness: staleness.to_sym
            )
            presenter = Presenters::CoverageRawPresenter.new(model: model, path: path)
            respond_json(presenter.relativized_payload, name: 'coverage_raw.json', pretty: true)
          end
        end
      end
    end
  end
end
