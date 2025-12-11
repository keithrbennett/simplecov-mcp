# frozen_string_literal: true

module CovLoupe
  # Shared constants used across multiple components to avoid duplication.
  # This ensures consistency between CLI option parsing and mode detection.
  module Constants
    # CLI options that expect an argument value following them.
    # Used by both CoverageCLI and ModeDetector to correctly parse command-line arguments.
    OPTIONS_EXPECTING_ARGUMENT = %w[
      -r --resultset
      -R --root
      -f --format
      -o --sort-order
      -s --source
      -c --context-lines
      -g --tracked-globs
      -l --log-file
      --error-mode
    ].freeze
  end
end
