# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::BaseTool do
  let(:handler) { SimpleCovMcp::ErrorHandler.new(log_errors: true, show_stack_traces: false, logger: test_logger) }
  let(:test_logger) do
    Class.new do
      attr_reader :messages
      def initialize; @messages = []; end
      def error(msg); @messages << msg; end
    end.new
  end

  before do
    @orig_handler = begin
      SimpleCovMcp.error_handler
    rescue StandardError
      nil
    end
    SimpleCovMcp.error_handler = handler
    # Stub MCP::Tool::Response once for all examples; capture the payload
    fake_resp = Class.new do
      attr_reader :payload
      def initialize(payload) = @payload = payload
    end
    stub_const('MCP::Tool::Response', fake_resp)
  end

  after do
    SimpleCovMcp.error_handler = @orig_handler if @orig_handler
  end

  shared_examples 'friendly response and logged' do
    it 'returns friendly text and logs' do
      resp = described_class.handle_mcp_error(error, tool)
      expect(resp).to be_a(MCP::Tool::Response)
      expect(resp.payload.first[:text]).to match(expected_pattern)
      expect(test_logger.messages.join).to include(log_fragment)
    end
  end

  context 'with SimpleCovMcp::Error' do
    let(:error) { SimpleCovMcp::UsageError.new('invalid args') }
    let(:tool) { 'coverage_summary' }
    let(:expected_pattern) { /Error: invalid args/ }
    let(:log_fragment) { 'invalid args' }
    include_examples 'friendly response and logged'
  end

  context 'with standard error' do
    let(:error) { Errno::ENOENT.new('No such file or directory @ rb_sysopen - missing.rb') }
    let(:tool) { 'coverage_raw' }
    let(:expected_pattern) { /Error: .*File not found: missing.rb/ }
    let(:log_fragment) { 'File not found' }
    include_examples 'friendly response and logged'
  end
end
