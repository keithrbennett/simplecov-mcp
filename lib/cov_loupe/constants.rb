# frozen_string_literal: true

module CovLoupe
  # Shared constants used across multiple components to avoid duplication.
  # This ensures consistency between CLI option parsing and mode detection.
  module Constants
    # Valid CLI subcommands.
    # Used by both CoverageCLI and ModeDetector to ensure consistent command recognition.
    SUBCOMMANDS = %w[list summary raw uncovered detailed totals validate version].freeze

    # CLI options that expect an argument value following them.
    # Used by CoverageCLI to correctly parse command-line arguments.
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
      -m --mode
    ].freeze

    # Default glob patterns for tracking files that should have coverage.
    # Used when --tracked-globs is not explicitly provided.
    # Covers common Ruby project structures:
    # - lib/**/*.rb: Standard gem structure
    # - app/**/*.rb: Rails applications
    # - src/**/*.rb: Alternative source directory
    DEFAULT_TRACKED_GLOBS = %w[
      lib/**/*.rb
      app/**/*.rb
      src/**/*.rb
    ].freeze
  end
end
