# frozen_string_literal: true

# Load CLI-specific components.
# Used when CovLoupe.run detects CLI mode.

require_relative '../cov_loupe' # Core library components

# CLI dependencies
require 'optparse'
require_relative 'cli'
