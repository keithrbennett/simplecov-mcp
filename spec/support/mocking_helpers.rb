# frozen_string_literal: true

# Helpers for mocking and stubbing objects in RSpec tests.
module MockingHelpers
  # Stub staleness checking to return a specific value
  # @param value [Symbol] The staleness value to return (:length_mismatch, :newer, :missing, :error, or :ok)
  def stub_staleness_check(value)
    checker_double = instance_double(CovLoupe::StalenessChecker)
    allow(checker_double).to receive_messages(
      file_staleness_status: value,
      off?: false
    )
    allow(checker_double).to receive(:check_file!)
    allow(CovLoupe::StalenessChecker).to receive(:new).and_return(checker_double)
  end

  # Stub a presenter with specific payload data
  # @param presenter_class [Class] The presenter class to stub (e.g., CovLoupe::Presenters::CoveragePayloadPresenter)
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

  # Create a standard PathRelativizer for testing
  # @param root [String] The root path (default: '/abs/path')
  # @return [CovLoupe::PathRelativizer] Configured relativizer
  def create_test_relativizer(root: '/abs/path')
    CovLoupe::PathRelativizer.new(
      root: root,
      scalar_keys: %w[file file_path],
      array_keys: %w[newer_files missing_files deleted_files]
    )
  end

  # Stub a CoverageModel with common test configuration
  # @param model_method [Symbol] The method to stub (e.g., :summary_for, :raw_for)
  # @param mock_data [Hash] The data to return from the stubbed method
  # @param file_path [String] The file path argument for the stubbed method
  # @param staleness [Symbol] The staleness value to return (default: :ok)
  # @param root [String] The root path for the relativizer (default: '/abs/path')
  # @return [RSpec::Mocks::InstanceVerifyingDouble] The stubbed model
  def stub_coverage_model(model_method:, mock_data:, file_path: 'lib/foo.rb',
    staleness: :ok, root: '/abs/path')
    model = instance_double(CovLoupe::CoverageModel)
    allow(CovLoupe::CoverageModel).to receive(:new).and_return(model)
    # Accept any keyword arguments (like raise_on_stale) in addition to the file path
    allow(model).to receive(model_method).with(file_path, any_args).and_return(mock_data)

    relativizer = create_test_relativizer(root: root)
    allow(model).to receive(:relativize) { |payload| relativizer.relativize(payload) }
    allow(model).to receive(:staleness_for).with(file_path).and_return(staleness)

    model
  end
end
