# frozen_string_literal: true

require_relative '../model'
require_relative '../base_tool'

module SimpleCovMcp
  module Tools
    class AllFilesCoverageTool < BaseTool
      description 'Return coverage percentage for all files in the project'
      input_schema(
        type: 'object',
        properties: {
          root: { type: 'string', description: 'Project root for resolution', default: '.' },
          resultset: { type: 'string', description: 'Path to .resultset.json (absolute or relative to root)' },
          sort_order: { type: 'string', description: 'Sort order for coverage percentage: ascending or descending', default: 'ascending', enum: ['ascending', 'descending'] },
          stale: { type: 'string', description: 'Staleness mode: off|error', enum: ['off', 'error'] },
          tracked_globs: { type: 'array', description: 'Globs (project-relative) to detect new files missing from coverage', items: { type: 'string' } }
        }
      )
      class << self
        def call(root: '.', resultset: nil, sort_order: 'ascending', stale: 'off', tracked_globs: nil, server_context:)
          model = CoverageModel.new(root: root, resultset: resultset, staleness: stale, tracked_globs: tracked_globs)
          files = model.all_files(sort_order: sort_order, check_stale: (stale.to_s == 'error'), tracked_globs: tracked_globs)
          ::MCP::Tool::Response.new([{ type: 'json', json: { files: files } }],
                              meta: { mimeType: 'application/json' })
        rescue => e
          handle_mcp_error(e, 'AllFilesCoverageTool')
        end
      end
    end
  end
end
