# frozen_string_literal: true

module SimpleCovMcp
  # Configuration container for application options (used by both CLI and MCP modes)
  # Uses Struct for simplicity and built-in functionality
  AppConfig = Struct.new(
    :root,
    :resultset,
    :json,
    :sort_order,
    :source_mode,
    :source_context,
    :color,
    :error_mode,
    :stale_mode,
    :tracked_globs,
    :log_file,
    :success_predicate,
    :show_version,
    keyword_init: true
  ) do
    # Set sensible defaults - ALL SYMBOLS FOR ENUMS
    def initialize(
      root: '.',
      resultset: nil,
      json: false,
      sort_order: :ascending,
      source_mode: nil,
      source_context: 2,
      color: STDOUT.tty?,
      error_mode: :on,
      stale_mode: :off,
      tracked_globs: nil,
      log_file: nil,
      success_predicate: nil,
      show_version: false
    )
      super
    end

    # Convenience method for CoverageModel initialization
    def model_options
      {
        root: root,
        resultset: resultset,
        staleness: stale_mode,
        tracked_globs: tracked_globs
      }
    end

    # Convenience method for SourceFormatter initialization
    def formatter_options
      {
        color_enabled: color
      }
    end
  end
end
