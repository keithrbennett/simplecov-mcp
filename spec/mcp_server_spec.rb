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

    server_context = SimpleCovMcp.create_context(
      error_handler: SimpleCovMcp::ErrorHandlerFactory.for_mcp_server,
      log_target: 'stderr'
    )
    server = described_class.new(context: server_context)
    baseline_context = SimpleCovMcp.context

    # Run should construct server and open transport
    server.run
    # Server should restore the caller's context after execution.
    expect(SimpleCovMcp.context).to eq(baseline_context)

    # Fetch the instances created during `run` via the class-level hooks.
    fake_server = fake_server_class.last_instance
    fake_transport = fake_transport_class.last_instance

    expect(fake_transport).not_to be_nil
    expect(fake_transport).to be_opened
    expect(fake_server).not_to be_nil

    expect(fake_server.params[:name]).to eq('simplecov-mcp')
    # Ensure expected tools are registered
    tool_names = fake_server.params[:tools].map { |t| t.name.split('::').last }
    expect(tool_names).to include(
      'AllFilesCoverageTool',
      'CoverageDetailedTool',
      'CoverageRawTool',
      'CoverageSummaryTool',
      'CoverageTotalsTool',
      'UncoveredLinesTool',
      'CoverageTableTool',
      'HelpTool',
      'VersionTool'
    )
  end

  describe 'TOOLSET and TOOL_GUIDE consistency' do
    it 'includes all tools documented in HelpTool TOOL_GUIDE' do
      # Get tool classes from TOOLSET
      toolset_classes = described_class::TOOLSET

      # Get tool classes from TOOL_GUIDE
      tool_guide_classes = SimpleCovMcp::Tools::HelpTool::TOOL_GUIDE.map { |guide| guide[:tool] }

      # Every tool in TOOL_GUIDE should be in TOOLSET
      tool_guide_classes.each do |tool_class|
        expect(toolset_classes).to include(tool_class),
          "Expected TOOLSET to include #{tool_class.name}, but it was missing. " \
            'Add it to MCPServer::TOOLSET or remove from HelpTool::TOOL_GUIDE.'
      end
    end

    it 'has corresponding TOOL_GUIDE entry for all tools (except HelpTool itself)' do
      toolset_classes = described_class::TOOLSET
      tool_guide_classes = SimpleCovMcp::Tools::HelpTool::TOOL_GUIDE.map { |guide| guide[:tool] }

      # Every tool in TOOLSET should be in TOOL_GUIDE (except HelpTool which documents itself)
      toolset_classes.each do |tool_class|
        # HelpTool doesn't need an entry about itself
        next if tool_class == SimpleCovMcp::Tools::HelpTool

        expect(tool_guide_classes).to include(tool_class),
          "Expected TOOL_GUIDE to document #{tool_class.name}, but it was missing. " \
            'Add documentation for this tool to HelpTool::TOOL_GUIDE.'
      end
    end

    it 'registers the expected number of tools' do
      # This helps catch accidental removal of tools
      expect(described_class::TOOLSET.length).to eq(9)
    end

    it 'registers all tool classes defined in SimpleCovMcp::Tools module' do
      # This test catches the bug where a tool file is created, required in
      # simplecov_mcp.rb, but not added to MCPServer::TOOLSET.
      #
      # Get all classes in the Tools module that inherit from BaseTool
      tool_classes = SimpleCovMcp::Tools.constants
        .map { |const_name| SimpleCovMcp::Tools.const_get(const_name) }
        .select { |const| const.is_a?(Class) && const < SimpleCovMcp::BaseTool }

      toolset_classes = described_class::TOOLSET

      tool_classes.each do |tool_class|
        expect(toolset_classes).to include(tool_class),
          "Expected TOOLSET to include #{tool_class.name}, but it was missing. " \
            'The tool class exists in SimpleCovMcp::Tools but is not registered in MCPServer::TOOLSET.'
      end
    end
  end
end
