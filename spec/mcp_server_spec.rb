# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::MCPServer do
  # This spec verifies the MCP server boot path without requiring the real
  # MCP runtime. We stub the MCP::Server and its stdio transport to capture
  # constructor parameters and observe that `open` is invoked.
  it 'sets error handler and boots server with expected tools' do
    # Prepare fakes for MCP server and transport
    module ::MCP; end unless defined?(::MCP)

    # Fake server captures the last created instance so we can assert on the
    # name/version/tools passed in by SimpleCovMcp::MCPServer. The
    # `last_instance` accessor is a class-level handle to the most recently
    # instantiated fake. Because the production code constructs the server
    # internally, we can't grab the instance directly; recording the most
    # recent instance lets the test fetch it after `run` completes.
    fake_server_class = Class.new do
      class << self
        # Holds the most recently created fake server instance so tests can
        # inspect it after the code under test performs internal construction.
        attr_accessor :last_instance
      end
      attr_reader :params
      def initialize(name:, version:, tools:)
        @params = { name: name, version: version, tools: tools }
        self.class.last_instance = self
      end
    end

    # Fake stdio transport records whether `open` was called and the server
    # it was initialized with, to confirm that the server was started. It also
    # exposes a `last_instance` class accessor for the same reason as above:
    # to retrieve the instance created during `run` so we can assert on it.
    fake_transport_class = Class.new do
      class << self
        # Holds the most recently created fake transport instance for later
        # assertions (e.g., that `open` was invoked).
        attr_accessor :last_instance
      end
      attr_reader :server, :opened
      def initialize(server)
        @server = server
        @opened = false
        self.class.last_instance = self
      end
      def open
        @opened = true
      end
      def opened?
        @opened
      end
    end

    stub_const('MCP::Server', fake_server_class)
    stub_const('MCP::Server::Transports::StdioTransport', fake_transport_class)

    server = described_class.new
    # Error handler should be set for MCP server usage (factory selection).
    expect(SimpleCovMcp.error_handler).to be_a(SimpleCovMcp::ErrorHandler)

    # Run should construct server and open transport
    server.run
    # Fetch the instances created during `run` via the class-level hooks.
    fake_server = fake_server_class.last_instance
    fake_transport = fake_transport_class.last_instance

    expect(fake_transport).not_to be_nil
    expect(fake_transport).to be_opened
    expect(fake_server).not_to be_nil

    expect(fake_server.params[:name]).to eq('simplecov-mcp')
    # Ensure expected tools are registered
    tool_names = fake_server.params[:tools].map { |t| t.name.split('::').last }
    expect(tool_names).to include('AllFilesCoverageTool', 'CoverageDetailedTool', 'CoverageRawTool', 'CoverageSummaryTool', 'UncoveredLinesTool')
  end
end
