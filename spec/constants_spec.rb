# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::Constants do
  describe 'OPTIONS_EXPECTING_ARGUMENT' do
    subject(:options) { described_class::OPTIONS_EXPECTING_ARGUMENT }

    it 'exists' do
      expect(options).not_to be_nil
    end

    it 'is frozen' do
      expect(options).to be_frozen
    end

    it 'contains expected CLI options' do
      expected_options = %w[
        -r --resultset
        -R --root
        -o --sort-order
        -c --source-context
        -S --stale
        -g --tracked-globs
        -l --log-file
        --error-mode
        --success-predicate
      ]

      expect(options).to eq(expected_options)
    end

    it 'contains only strings' do
      expect(options).to all(be_a(String))
    end

    it 'contains options that start with dashes' do
      expect(options).to all(start_with('-'))
    end
  end

  describe 'usage by other classes' do
    it 'is used by ModeDetector' do
      expect(SimpleCovMcp::ModeDetector::OPTIONS_EXPECTING_ARGUMENT)
        .to equal(SimpleCovMcp::Constants::OPTIONS_EXPECTING_ARGUMENT)
    end

    it 'is used by CoverageCLI' do
      expect(SimpleCovMcp::CoverageCLI::OPTIONS_EXPECTING_ARGUMENT)
        .to equal(SimpleCovMcp::Constants::OPTIONS_EXPECTING_ARGUMENT)
    end

    it 'ensures both classes reference the same object' do
      cli_options = SimpleCovMcp::CoverageCLI::OPTIONS_EXPECTING_ARGUMENT
      detector_options = SimpleCovMcp::ModeDetector::OPTIONS_EXPECTING_ARGUMENT

      expect(cli_options).to equal(detector_options)
    end
  end
end
