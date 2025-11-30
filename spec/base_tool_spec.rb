# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::BaseTool do
  let(:handler) { SimpleCovMcp::ErrorHandler.new(error_mode: :log, logger: test_logger) }
  let(:test_logger) do
    Class.new do
      attr_reader :messages

      def initialize() = @messages = []
      def error(msg) = @messages << msg
    end.new
  end

  around do |example|
    orig_handler = begin
      SimpleCovMcp.error_handler
    rescue StandardError
      nil
    end

    SimpleCovMcp.error_handler = handler
    setup_mcp_response_stub

    example.run
  ensure
    SimpleCovMcp.error_handler = orig_handler if orig_handler
  end

  shared_examples 'friendly response and logged' do
    it 'returns friendly text' do
      resp = described_class.handle_mcp_error(error, tool, error_mode: :log)
      expect(resp).to be_a(MCP::Tool::Response)
      expect(resp.payload.first[:text]).to match(expected_pattern)
    end

    it 'respects error_mode :off' do
      resp = described_class.handle_mcp_error(error, tool, error_mode: :off)
      expect(resp).to be_a(MCP::Tool::Response)
      expect(resp.payload.first[:text]).to match(expected_pattern)
    end
  end

  context 'with SimpleCovMcp::Error' do
    let(:error) { SimpleCovMcp::UsageError.new('invalid args') }
    let(:tool) { 'coverage_summary' }
    let(:expected_pattern) { /Error: invalid args/ }
    let(:log_fragment) { 'invalid args' }

    it_behaves_like 'friendly response and logged'
  end

  context 'with standard error' do
    let(:error) { Errno::ENOENT.new('No such file or directory @ rb_sysopen - missing.rb') }
    let(:tool) { 'coverage_raw' }
    let(:expected_pattern) { /Error: .*File not found: missing.rb/ }
    let(:log_fragment) { 'File not found' }

    it_behaves_like 'friendly response and logged'
  end
end
