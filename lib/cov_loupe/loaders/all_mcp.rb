# frozen_string_literal: true

# Load MCP server-specific components including all tools.
# Used when CovLoupe.run detects MCP mode.

require_relative '../../cov_loupe' # Core library components (lib/cov_loupe.rb)

# MCP server dependencies
require 'mcp'
require 'mcp/server/transports/stdio_transport'
require_relative '../config/config_parser'
require_relative '../base_tool'
require_relative '../tools/coverage_raw_tool'
require_relative '../tools/coverage_summary_tool'
require_relative '../tools/uncovered_lines_tool'
require_relative '../tools/coverage_detailed_tool'
require_relative '../tools/list_tool'
require_relative '../tools/coverage_totals_tool'
require_relative '../tools/coverage_table_tool'
require_relative '../tools/validate_tool'
require_relative '../tools/version_tool'
require_relative '../tools/help_tool'
require_relative '../mcp_server'
