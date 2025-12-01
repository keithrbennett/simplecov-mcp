# frozen_string_literal: true

module SimpleCovMcp
  # Configuration container for application options (used by both CLI and MCP modes)
  # Uses Struct for simplicity and built-in functionality
  AppConfig = Struct.new(
    :root,
    :resultset,
    :format,
    :sort_order,
    :source_mode,
    :source_context,
    :color,
    :error_mode,
    :staleness,
    :tracked_globs,
    :log_file,
    :show_version,
    keyword_init: true
  ) do
    # Set sensible defaults - ALL SYMBOLS FOR ENUMS
    def initialize(
      root: '.',
      resultset: nil,
      format: :table,
      sort_order: :ascending,
      source_mode: nil,
      source_context: 2,
      color: $stdout.tty?,
      error_mode: :log,
      staleness: :off,
      tracked_globs: nil,
      log_file: nil,
      show_version: false
    )
      super
    end

    # Convenience method for CoverageModel initialization
    def model_options
      {
        root: root,
        resultset: resultset,
        staleness: staleness,
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
