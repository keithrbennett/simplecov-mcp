# frozen_string_literal: true

# Load all CovLoupe components including CLI, MCP server, and all tools.
# This file is used by the test suite (spec/spec_helper.rb) to ensure all
# components are loaded for testing.
#
# For selective loading at runtime:
# - Use all_cli.rb for CLI mode (loads optparse + CLI)
# - Use all_mcp.rb for MCP mode (loads MCP gem + tools)
#
# Library users should use `require 'cov_loupe'` instead, which loads only the core
# components (CoverageModel, errors, utilities) without the CLI/MCP overhead.

require_relative 'all_cli'
require_relative 'all_mcp'
