# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CovLoupe do
  # Mode detection tests moved to mode_detector_spec.rb
  # These tests verify the integration with ModeDetector
  describe 'mode detection integration' do
    it 'uses ModeDetector for CLI mode detection' do
      allow(described_class::ModeDetector).to receive(:cli_mode?).with(['--force-mode', 'cli'])
        .and_return(true)
      cli = instance_double(described_class::CoverageCLI, run: nil)
      allow(described_class::CoverageCLI).to receive(:new).and_return(cli)

      described_class.run(['--force-mode', 'cli'])

      expect(described_class::ModeDetector).to have_received(:cli_mode?).with(['--force-mode',
                                                                               'cli'])
      expect(described_class::CoverageCLI).to have_received(:new)
      expect(cli).to have_received(:run)
    end
  end

  # When no thread-local context exists, active_log_file= creates one
  # from the default context rather than modifying an existing one.
  describe '.active_log_file=' do
    it 'creates context from default when no current context exists' do
      Thread.current[:cov_loupe_context] = nil

      described_class.active_log_file = '/tmp/test.log'

      expect(described_class.context).not_to be_nil
      expect(described_class.active_log_file).to eq('/tmp/test.log')
    ensure
      described_class.active_log_file = File::NULL
    end
  end
end
