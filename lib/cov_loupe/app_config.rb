# frozen_string_literal: true

require_relative 'constants'

module CovLoupe
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
    :raise_on_stale,
    :tracked_globs,
    :log_file,
    :show_version,
    :mode,
    keyword_init: true
  ) do
    # Set sensible defaults - ALL SYMBOLS FOR ENUMS
    def initialize(
      root: '.',
      resultset: nil,
      format: :table,
      sort_order: :descending,
      source_mode: nil,
      source_context: 2,
      color: $stdout.tty?,
      error_mode: :log,
      raise_on_stale: false,
      tracked_globs: nil,
      log_file: nil,
      show_version: false,
      mode: :cli
    )
      # Default to empty array (show all files in resultset and don't look for files lacking coverage data)
      # Users should set COV_LOUPE_OPTS to match SimpleCov track_files patterns
      tracked_globs = [] if tracked_globs.nil?
      super
    end

    # Convenience method for CoverageModel initialization
    def model_options
      {
        root: root,
        resultset: resultset,
        raise_on_stale: raise_on_stale,
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
