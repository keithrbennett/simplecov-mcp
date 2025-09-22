# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp do
  describe '.should_run_cli?' do
    after { ENV.delete('SIMPLECOV_MCP_CLI') }
    
    it 'returns true when SIMPLECOV_MCP_CLI=1' do
      ENV['SIMPLECOV_MCP_CLI'] = '1'
      expect(SimpleCovMcp.send(:should_run_cli?, [])).to be true
    end
    
    it 'returns true for valid subcommands' do
      expect(SimpleCovMcp.send(:should_run_cli?, ['list'])).to be true
    end
    
    it 'returns true when STDIN is a TTY' do
      allow(STDIN).to receive(:tty?).and_return(true)
      expect(SimpleCovMcp.send(:should_run_cli?, [])).to be true
    end
    
    it 'returns false when STDIN is not a TTY and no subcommand' do
      allow(STDIN).to receive(:tty?).and_return(false)
      expect(SimpleCovMcp.send(:should_run_cli?, [])).to be false
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