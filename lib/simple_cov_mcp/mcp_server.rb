# frozen_string_literal: true

module SimpleCovMcp
  class MCPServer
      def initialize
        # Configure error handling for MCP server mode using the factory
        SimpleCovMcp.error_handler = ErrorHandlerFactory.for_mcp_server
      end

      def run
        server = ::MCP::Server.new(
          name:    'simplecov_mcp',
          version: SimpleCovMcp::VERSION,
          tools:   [AllFilesCoverageTool, CoverageDetailedTool, CoverageRawTool, CoverageSummaryTool, UncoveredLinesTool]
        )
        ::MCP::Server::Transports::StdioTransport.new(server).open
      end
  end
end
