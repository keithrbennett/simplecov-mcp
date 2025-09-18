# frozen_string_literal: true

module SimpleCovMcp
  class MCPServer
      def initialize
        # Configure error handling for MCP server mode using the factory
        SimpleCovMcp.error_handler = ErrorHandlerFactory.for_mcp_server
      end

      def run
        tools = [
          Tools::AllFilesCoverageTool,
          Tools::CoverageDetailedTool,
          Tools::CoverageRawTool,
          Tools::CoverageSummaryTool,
          Tools::UncoveredLinesTool,
          Tools::CoverageTableTool,
          Tools::HelpTool,
          Tools::VersionTool
        ]

        server = ::MCP::Server.new(
          name:    'simplecov-mcp',
          version: SimpleCovMcp::VERSION,
          tools:   tools
        )
        ::MCP::Server::Transports::StdioTransport.new(server).open
      end
  end
end
