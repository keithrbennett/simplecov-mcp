# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'MCP Mode Logging' do
  it 'raises a configuration error when --log-file is stdout' do
    argv = ['--log-file', 'stdout']

    # Mock ModeDetector to force MCP mode
    allow(SimpleCovMcp::ModeDetector).to receive(:cli_mode?).and_return(false)

    expect do
      SimpleCovMcp.run(argv)
    end.to raise_error(SimpleCovMcp::ConfigurationError, /Logging to stdout is not permitted in MCP server mode/)
  end

  it 'allows stderr logging in MCP mode' do
    argv = ['--log-file', 'stderr']
    original_target = SimpleCovMcp.active_log_file

    # Mock ModeDetector to force MCP mode
    allow(SimpleCovMcp::ModeDetector).to receive(:cli_mode?).and_return(false)

    # The server would normally start here; stub it so we can capture the context without side effects.
    mcp_server_double = instance_double(SimpleCovMcp::MCPServer, run: true)
    captured_context = nil
    allow(SimpleCovMcp::MCPServer).to receive(:new) do |context:|
      # Record the context that the MCP server receives to ensure the log target was honored.
      captured_context = context
      mcp_server_double
    end

    expect do
      SimpleCovMcp.run(argv)
    end.not_to raise_error

    # Server boot should have been given a context that points stdout logging to stderr.
    expect(captured_context).not_to be_nil
    expect(captured_context.log_target).to eq('stderr')
    # After the run, the original active context should be restored.
    expect(SimpleCovMcp.active_log_file).to eq(original_target)
  end
end
