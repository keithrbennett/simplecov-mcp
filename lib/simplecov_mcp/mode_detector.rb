# frozen_string_literal: true

module SimpleCovMcp
  # Centralizes the logic for detecting whether to run in CLI or MCP server mode.
  # This makes the mode detection strategy explicit and testable.
  #
  # Mode Detection Rules (in priority order):
  # 1. --force-cli flag present → CLI mode
  # 2. Valid subcommand present → CLI mode
  # 3. Invalid subcommand attempt (non-flag arg) → CLI mode (to show error)
  # 4. Interactive TTY → CLI mode
  # 5. Otherwise (piped input) → MCP server mode
  class ModeDetector
    SUBCOMMANDS = %w[list summary raw uncovered detailed version].freeze

    # Determine if CLI mode should be used based on arguments
    #
    # @param argv [Array<String>] Command line arguments (may include env options)
    # @param stdin [IO] Standard input stream (default: STDIN)
    # @return [Boolean] true if CLI mode should be used, false for MCP server mode
    def self.cli_mode?(argv, stdin: STDIN)
      # Check for explicit --force-cli flag
      return true if argv.include?('--force-cli')

      # Check if first argument is a valid subcommand
      return true if !argv.empty? && SUBCOMMANDS.include?(argv[0])

      # Check if first arg looks like an invalid subcommand (to show helpful error)
      # If it doesn't start with '-', treat it as a subcommand attempt
      return true if !argv.empty? && !argv[0].start_with?('-')

      # If interactive terminal, default to CLI mode
      stdin.tty?
    end

    # Inverse of cli_mode? for clarity when checking MCP mode
    def self.mcp_server_mode?(argv, stdin: STDIN)
      !cli_mode?(argv, stdin: stdin)
    end
  end
end
