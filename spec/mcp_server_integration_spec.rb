# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'MCP Server Bootstrap' do
  it 'does not crash on startup in non-TTY environments' do
    # Simulate a non-TTY environment, which should trigger MCP mode
    allow($stdin).to receive(:tty?).and_return(false)

    # The server will try to run, but we only need to ensure it gets past
    # the point where the NameError would have occurred. We can mock the
    # server's run method to prevent it from hanging while waiting for input.
    mcp_server_instance = instance_double(SimpleCovMcp::MCPServer)
    allow(SimpleCovMcp::MCPServer).to receive(:new).and_return(mcp_server_instance)
    allow(mcp_server_instance).to receive(:run)

    # The key assertion is that this code executes without raising a NameError
    # or any other exception related to the bootstrap process.
    expect { SimpleCovMcp.run([]) }.not_to raise_error

    expect(mcp_server_instance).to have_received(:run)
  end
end
