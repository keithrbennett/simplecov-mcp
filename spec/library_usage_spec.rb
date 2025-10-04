# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'SimpleCovMcp.run_as_library' do
  let(:valid_file) { 'lib/simplecov_mcp.rb' }

  describe 'basic usage' do
    it 'returns all files when argv is empty' do
      result = SimpleCovMcp.run_as_library([])

      expect(result).to be_a(Array)
      expect(result).not_to be_empty
      expect(result.first).to have_key('file')
      expect(result.first).to have_key('covered')
      expect(result.first).to have_key('total')
    end

    it 'returns summary for a file with summary command' do
      result = SimpleCovMcp.run_as_library(['summary', valid_file])

      expect(result).to be_a(Hash)
      expect(result).to have_key('file')
      expect(result).to have_key('summary')
      expect(result['summary']).to have_key('covered')
      expect(result['summary']).to have_key('total')
      expect(result['summary']).to have_key('pct')
    end

    it 'returns raw coverage for a file with raw command' do
      result = SimpleCovMcp.run_as_library(['raw', valid_file])

      expect(result).to be_a(Hash)
      expect(result).to have_key('file')
      expect(result).to have_key('lines')
      expect(result['lines']).to be_a(Array)
    end

    it 'returns uncovered lines for a file with uncovered command' do
      result = SimpleCovMcp.run_as_library(['uncovered', valid_file])

      expect(result).to be_a(Hash)
      expect(result).to have_key('file')
      expect(result).to have_key('uncovered')
      expect(result['uncovered']).to be_a(Array)
    end

    it 'returns detailed coverage for a file with detailed command' do
      result = SimpleCovMcp.run_as_library(['detailed', valid_file])

      expect(result).to be_a(Hash)
      expect(result).to have_key('file')
      expect(result).to have_key('lines')
      expect(result['lines']).to be_a(Array)
      expect(result['lines'].first).to have_key('line')
      expect(result['lines'].first).to have_key('hits')
      expect(result['lines'].first).to have_key('covered')
    end
  end

  describe 'error handling' do
    it 'raises UsageError for invalid arguments' do
      expect {
        SimpleCovMcp.run_as_library(['summary'])
      }.to raise_error(SimpleCovMcp::UsageError, /Invalid arguments/)
    end

    it 'raises UsageError for unknown command' do
      expect {
        SimpleCovMcp.run_as_library(['invalid_command', valid_file])
      }.to raise_error(SimpleCovMcp::UsageError, /Unknown command/)
    end

    it 'raises FileError for missing file' do
      expect {
        SimpleCovMcp.run_as_library(['summary', 'nonexistent_file.rb'])
      }.to raise_error(SimpleCovMcp::FileError)
    end

    it 're-raises SimpleCovMcp::Error exceptions' do
      expect {
        SimpleCovMcp.run_as_library(['summary', 'nonexistent.rb'])
      }.to raise_error(SimpleCovMcp::Error)
    end

    it 're-raises other exceptions after handling' do
      # Mock the model to raise a non-SimpleCovMcp error
      model = instance_double(SimpleCovMcp::CoverageModel)
      allow(SimpleCovMcp::CoverageModel).to receive(:new).and_return(model)
      allow(model).to receive(:all_files).and_raise(RuntimeError, 'unexpected error')

      # Mock error handler to verify it's called
      error_handler = instance_double(SimpleCovMcp::ErrorHandler)
      allow(SimpleCovMcp::ErrorHandlerFactory).to receive(:for_library).and_return(error_handler)
      allow(error_handler).to receive(:handle_error)

      expect {
        SimpleCovMcp.run_as_library([])
      }.to raise_error(RuntimeError, 'unexpected error')

      expect(error_handler).to have_received(:handle_error)
    end
  end

  describe 'custom error handler' do
    it 'uses custom error handler when provided' do
      custom_handler = SimpleCovMcp::ErrorHandler.new(error_mode: :off)

      result = SimpleCovMcp.run_as_library([], error_handler: custom_handler)

      expect(result).to be_a(Array)
      expect(SimpleCovMcp.error_handler).to eq(custom_handler)
    end

    it 'uses default library error handler when not provided' do
      SimpleCovMcp.run_as_library([])

      # Verify error handler was set (factory method should have been called)
      expect(SimpleCovMcp.error_handler).to be_a(SimpleCovMcp::ErrorHandler)
    end
  end

  describe 'execute_library_command' do
    let(:model) { SimpleCovMcp::CoverageModel.new }

    it 'executes summary command' do
      result = SimpleCovMcp.send(:execute_library_command, model, ['summary', valid_file])
      expect(result).to have_key('summary')
    end

    it 'executes raw command' do
      result = SimpleCovMcp.send(:execute_library_command, model, ['raw', valid_file])
      expect(result).to have_key('lines')
    end

    it 'executes uncovered command' do
      result = SimpleCovMcp.send(:execute_library_command, model, ['uncovered', valid_file])
      expect(result).to have_key('uncovered')
    end

    it 'executes detailed command' do
      result = SimpleCovMcp.send(:execute_library_command, model, ['detailed', valid_file])
      expect(result['lines'].first).to have_key('covered')
    end
  end
end
