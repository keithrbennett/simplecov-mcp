# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp do
  # Mode detection tests moved to mode_detector_spec.rb
  # These tests verify the integration with ModeDetector
  describe 'mode detection integration' do
    it 'uses ModeDetector for CLI mode detection' do
      expect(described_class::ModeDetector).to receive(:cli_mode?).with(['--force-cli'])
        .and_return(true)
      cli = instance_double(described_class::CoverageCLI)
      expect(described_class::CoverageCLI).to receive(:new).and_return(cli)
      expect(cli).to receive(:run)
      described_class.run(['--force-cli'])
    end
  end

  # When no thread-local context exists, active_log_file= creates one
  # from the default context rather than modifying an existing one.
  describe '.active_log_file=' do
    it 'creates context from default when no current context exists' do
      Thread.current[:simplecov_mcp_context] = nil

      described_class.active_log_file = '/tmp/test.log'

      expect(described_class.context).not_to be_nil
      expect(described_class.active_log_file).to eq('/tmp/test.log')
    ensure
      described_class.active_log_file = File::NULL
    end
  end
end
