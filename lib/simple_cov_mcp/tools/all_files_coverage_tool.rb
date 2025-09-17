# frozen_string_literal: true

require_relative '../model'
require_relative '../base_tool'

module SimpleCovMcp
  class AllFilesCoverageTool < BaseTool
      description 'Return coverage percentage for all files in the project'
      input_schema(
        type: 'object',
        properties: {
          root: { type: 'string', description: 'Project root for resolution', default: '.' },
          resultset: { type: 'string', description: 'Path to .resultset.json (absolute or relative to root)' },
          sort_order: { type: 'string', description: 'Sort order for coverage percentage: ascending or descending', default: 'ascending', enum: ['ascending', 'descending'] },
          strict_staleness: { type: 'boolean', description: 'If true, raise if any source file is newer than coverage timestamp or if tracked files are missing from coverage' },
          tracked_globs: { type: 'array', description: 'Globs (project-relative) to detect new files missing from coverage', items: { type: 'string' } }
        }
      )
      class << self
        def call(root: '.', resultset: nil, sort_order: 'ascending', strict_staleness: nil, tracked_globs: nil, server_context:)
          model = CoverageModel.new(root: root, resultset: resultset, strict_staleness: strict_staleness.nil? ? (ENV['SIMPLECOV_MCP_STRICT_STALENESS'] == '1') : strict_staleness)
          files = model.all_files(sort_order: sort_order, check_stale: model.instance_variable_get(:@strict_staleness), tracked_globs: tracked_globs)
          ::MCP::Tool::Response.new([{ type: 'json', json: { files: files } }],
                              meta: { mimeType: 'application/json' })
        rescue => e
          handle_mcp_error(e, 'AllFilesCoverageTool')
        end
      end
  end
end
