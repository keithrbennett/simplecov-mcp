# frozen_string_literal: true

module CovLoupe
  class MCPServer
    def initialize(context: CovLoupe.context)
      @context = context
    end

    def run
      CovLoupe.with_context(context) do
        server = ::MCP::Server.new(
          name: 'cov-loupe',
          version: CovLoupe::VERSION,
          tools: toolset,
          server_context: context
        )
        ::MCP::Server::Transports::StdioTransport.new(server).open
      end
    end

    TOOLSET = [
      Tools::ListTool,
      Tools::CoverageDetailedTool,
      Tools::CoverageRawTool,
      Tools::CoverageSummaryTool,
      Tools::CoverageTotalsTool,
      Tools::UncoveredLinesTool,
      Tools::CoverageTableTool,
      Tools::ValidateTool,
      Tools::HelpTool,
      Tools::VersionTool
    ].freeze

    # Expose the registered tools so embedders can introspect without booting the server.
    def toolset
      TOOLSET
    end

    private

    attr_reader :context
  end
end
