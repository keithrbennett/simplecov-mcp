# frozen_string_literal: true

# Back-compat shim: load new path
require 'simple_cov_mcp'

# Only when requiring this legacy path, expose SimpleCov::Mcp as an alias
module SimpleCov
  Mcp = SimpleCovMcp
end
