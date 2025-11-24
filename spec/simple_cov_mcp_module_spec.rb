# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp do
  # Mode detection tests moved to mode_detector_spec.rb
  # These tests verify the integration with ModeDetector
  describe 'mode detection integration' do
    it 'uses ModeDetector for CLI mode detection' do
      expect(SimpleCovMcp::ModeDetector).to receive(:cli_mode?).with(['--force-cli'])
        .and_return(true)
      expect(SimpleCovMcp::CoverageCLI).to receive_message_chain(:new, :run)
      SimpleCovMcp.run(['--force-cli'])
    end
  end

  # When no thread-local context exists, active_log_file= creates one
  # from the default context rather than modifying an existing one.
  describe '.active_log_file=' do
    it 'creates context from default when no current context exists' do
      Thread.current[:simplecov_mcp_context] = nil

      SimpleCovMcp.active_log_file = '/tmp/test.log'

      expect(SimpleCovMcp.context).not_to be_nil
      expect(SimpleCovMcp.active_log_file).to eq('/tmp/test.log')
    ensure
      SimpleCovMcp.active_log_file = File::NULL
    end
  end
end
