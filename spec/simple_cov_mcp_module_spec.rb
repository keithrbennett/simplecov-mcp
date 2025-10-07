# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp do
  # Mode detection tests moved to mode_detector_spec.rb
  # These tests verify the integration with ModeDetector
  describe 'mode detection integration' do
    it 'uses ModeDetector for CLI mode detection' do
      expect(SimpleCovMcp::ModeDetector).to receive(:cli_mode?).with(['--force-cli']).and_return(true)
      expect(SimpleCovMcp::CoverageCLI).to receive_message_chain(:new, :run)
      SimpleCovMcp.run(['--force-cli'])
    end
  end
  
  describe '.execute_library_command' do
    let(:model) { instance_double(SimpleCovMcp::CoverageModel) }
    
    it 'returns all_files when argv is empty' do
      expect(model).to receive(:all_files).and_return([])
      expect(SimpleCovMcp.send(:execute_library_command, model, [])).to eq([])
    end
    
    it 'raises UsageError for insufficient arguments' do
      expect {
        SimpleCovMcp.send(:execute_library_command, model, ['summary'])
      }.to raise_error(SimpleCovMcp::UsageError)
    end
    
    %w[summary raw uncovered detailed].each do |command|
      it "routes #{command} command correctly" do
        expect(model).to receive("#{command}_for").with('file.rb').and_return({})
        result = SimpleCovMcp.send(:execute_library_command, model, [command, 'file.rb'])
        expect(result).to eq({})
      end
    end
    
    it 'raises UsageError for unknown commands' do
      expect {
        SimpleCovMcp.send(:execute_library_command, model, ['unknown', 'file.rb'])
      }.to raise_error(SimpleCovMcp::UsageError, /Unknown command/)
    end
  end
end