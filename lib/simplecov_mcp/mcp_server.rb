# frozen_string_literal: true

module SimpleCovMcp
  class MCPServer
    def initialize(context: SimpleCovMcp.context)
      @context = context
    end

    def run
      SimpleCovMcp.with_context(context) do
        server = ::MCP::Server.new(
          name: 'simplecov-mcp',
          version: SimpleCovMcp::VERSION,
          tools: toolset
        )
        ::MCP::Server::Transports::StdioTransport.new(server).open
      end
    end

    # Expose the registered tools so embedders can introspect without booting the server.
    def toolset
      TOOLSET
    end

    private

    TOOLSET = [
      Tools::AllFilesCoverageTool,
      Tools::CoverageDetailedTool,
      Tools::CoverageRawTool,
      Tools::CoverageSummaryTool,
      Tools::CoverageTotalsTool,
      Tools::UncoveredLinesTool,
      Tools::CoverageTableTool,
      Tools::HelpTool,
      Tools::VersionTool
    ].freeze

    attr_reader :context
  end
end
