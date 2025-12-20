# frozen_string_literal: true

require_relative 'constants'
require_relative 'option_normalizers'

module CovLoupe
  # Centralizes the logic for detecting whether to run in CLI or MCP server mode.
  # This makes the mode detection strategy explicit and testable.
  class ModeDetector
    # Reference shared constants to avoid duplication with CoverageCLI
    SUBCOMMANDS = Constants::SUBCOMMANDS
    OPTIONS_EXPECTING_ARGUMENT = Constants::OPTIONS_EXPECTING_ARGUMENT

    def self.cli_mode?(argv, stdin: $stdin)
      forced_mode = force_mode_override(argv)
      return forced_mode == :cli if forced_mode

      # 1. Explicit flags that force CLI mode always win
      cli_options = %w[-h --help --version -v]
      return true if argv.intersect?(cli_options)

      # 2. Find the first non-option argument
      first_non_option = find_first_non_option(argv)

      # 3. If a non-option argument exists, it must be a CLI command (or an error)
      return true if first_non_option

      # 4. Fallback: If no non-option args, use TTY status to decide
      stdin.tty?
    end

    def self.mcp_server_mode?(argv, stdin: $stdin)
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

    # Checks for the --force-mode (-F) flag which allows the user (or test suite)
    # to bypass standard heuristic detection (TTY, subcommands).
    #
    # This manual scan is necessary because mode detection happens *before* regular
    # option parsing. We must determine whether to initialize the CLI application
    # or the MCP server before we can safely parse the remaining arguments using
    # the mode-specific logic.
    def self.force_mode_override(argv)
      argv.each_with_index do |token, idx|
        next unless token == '-F' || token.start_with?('--force-mode')

        value = token.split('=', 2)[1] || argv[idx + 1]
        next unless value

        normalized = OptionNormalizers.normalize_force_mode(value, strict: false)
        return normalized if normalized
      end

      nil
    end
    private_class_method :force_mode_override
  end
end
