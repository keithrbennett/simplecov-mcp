# frozen_string_literal: true

require_relative 'constants'

module SimpleCovMcp
  # Centralizes the logic for detecting whether to run in CLI or MCP server mode.
  # This makes the mode detection strategy explicit and testable.
  class ModeDetector
    SUBCOMMANDS = %w[list summary raw uncovered detailed totals validate version].freeze

    # Reference shared constant to avoid duplication with CoverageCLI
    OPTIONS_EXPECTING_ARGUMENT = Constants::OPTIONS_EXPECTING_ARGUMENT

    def self.cli_mode?(argv, stdin: STDIN)
      # 1. Explicit flags that force CLI mode always win
      cli_options = %w[--force-cli -h --help --version -v]
      return true if (argv & cli_options).any?

      # 2. Find the first non-option argument
      first_non_option = find_first_non_option(argv)

      # 3. If a non-option argument exists, it must be a CLI command (or an error)
      return true if first_non_option

      # 4. Fallback: If no non-option args, use TTY status to decide
      stdin.tty?
    end

    def self.mcp_server_mode?(argv, stdin: STDIN)
      !cli_mode?(argv, stdin: stdin)
    end

    # Scans argv and returns the first token that is not an option or a value for an option.
    def self.find_first_non_option(argv)
      pending_option = false
      argv.each do |token|
        if pending_option
          pending_option = false
          next
        end

        if token.start_with?('-')
          # Check if the option is one that takes a value and isn't using '=' syntax.
          pending_option = OPTIONS_EXPECTING_ARGUMENT.include?(token) && !token.include?('=')
          next
        end

        # Found the first token that is not an option
        return token
      end
      nil
    end
    private_class_method :find_first_non_option
  end
end
