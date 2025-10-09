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

    # Mock ModeDetector to force MCP mode
    allow(SimpleCovMcp::ModeDetector).to receive(:cli_mode?).and_return(false)

    # We expect the server to run, but we'll mock it to prevent it from actually starting
    mcp_server_double = instance_double(SimpleCovMcp::MCPServer, run: true)
    allow(SimpleCovMcp::MCPServer).to receive(:new).and_return(mcp_server_double)

    expect do
      SimpleCovMcp.run(argv)
    end.not_to raise_error

    expect(SimpleCovMcp.log_file).to eq('stderr')
  end
end
