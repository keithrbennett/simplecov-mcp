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
end
