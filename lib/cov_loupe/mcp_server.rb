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
      Tools::ProjectCoverageTool,
      Tools::FileCoverageDetailedTool,
      Tools::FileCoverageRawTool,
      Tools::FileCoverageSummaryTool,
      Tools::ProjectCoverageTotalsTool,
      Tools::FileUncoveredLinesTool,
      Tools::ProjectValidateTool,
      Tools::HelpTool,
      Tools::VersionTool
    ].freeze

    # Expose the registered tools so embedders can introspect without booting the server.
    def toolset
      TOOLSET
    end

    attr_reader :context

    private def instructions
      <<~MSG.chomp
        cov-loupe provides SimpleCov coverage data via MCP tools.
        Documentation resources: #{JSON.generate(Resources::RESOURCE_MAP)}
        Call help for tool usage guidance. File-scope tools (file_coverage_*, file_uncovered_lines) require a path argument; project-scope tools (project_*) do not.
        Tools accept optional `root` (project root directory) and `resultset`
        (path or directory containing .resultset.json) arguments when the defaults
        need overriding; these may point to different locations.
      MSG
    end
  end
end
