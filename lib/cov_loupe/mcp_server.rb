# frozen_string_literal: true

require_relative 'resources'

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
          instructions: instructions,
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

    def instructions
      <<~MSG.chomp
        cov-loupe provides SimpleCov coverage data via MCP tools.
        Documentation resources: #{JSON.generate(Resources::MCP_RESOURCE_MAP)}
        Call help_tool for tool usage guidance.
        Tools accept optional `root` (project root directory) and `resultset`
        (path or directory containing .resultset.json) arguments when the defaults
        need overriding; these may point to different locations.
      MSG
    end
  end
end
