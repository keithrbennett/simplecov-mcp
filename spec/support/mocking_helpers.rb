# frozen_string_literal: true

# Helpers for mocking and stubbing objects in RSpec tests.
module MockingHelpers
  # Stub staleness checking to return a specific value
  # @param value [String, false] The staleness value to return ('L', 'T', 'M', or false)
  def stub_staleness_check(value)
    checker_double = instance_double(SimpleCovMcp::StalenessChecker)
    allow(checker_double).to receive_messages(
      stale_for_file?: value,
      off?: false
    )
    allow(checker_double).to receive(:check_file!)
    allow(SimpleCovMcp::StalenessChecker).to receive(:new).and_return(checker_double)
  end

  # Stub a presenter with specific payload data
  # @param presenter_class [Class] The presenter class to stub (e.g., SimpleCovMcp::Presenters::CoverageRawPresenter)
  # @param absolute_payload [Hash] The data hash to return from #absolute_payload
  # @param relative_path [String] The path to return from #relative_path
  def mock_presenter(presenter_class, absolute_payload:, relative_path:)
    presenter_double = instance_double(presenter_class)
    allow(presenter_double).to receive_messages(
      absolute_payload: absolute_payload,
      relative_path: relative_path
    )
    allow(presenter_class).to receive(:new).and_return(presenter_double)
    presenter_double
  end
end
