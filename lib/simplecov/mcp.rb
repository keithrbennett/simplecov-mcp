# frozen_string_literal: true

require "json"
require "time"
require "pathname"
require "mcp"
require "mcp/server/transports/stdio_transport"
require "awesome_print"

require_relative "mcp/version"
require_relative "mcp/util"
require_relative "mcp/model"
require_relative "mcp/base_tool"
require_relative "mcp/tools/coverage_raw"
require_relative "mcp/tools/coverage_summary"
require_relative "mcp/tools/uncovered_lines"
require_relative "mcp/tools/coverage_detailed"
require_relative "mcp/tools/all_files_coverage"
require_relative "mcp/cli"

module Simplecov
  module Mcp
    def self.run(argv)
      CoverageCLI.new.run(argv)
    end
  end
end

