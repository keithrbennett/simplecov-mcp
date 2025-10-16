# frozen_string_literal: true

module SimpleCovMcp
  module OptionParsers
    class ErrorHelper
      SUBCOMMANDS = %w[list summary raw uncovered detailed version].freeze

      def initialize(subcommands = SUBCOMMANDS)
        @subcommands = subcommands
      end

      def handle_option_parser_error(error, argv: [], usage_hint: "Run '#{program_name} --help' for usage information.")
        message = error.message.to_s
        # Suggest a subcommand when an invalid option matches a known subcommand
        option = extract_invalid_option(message)

        if option && option.start_with?('--') && @subcommands.include?(option[2..-1])
          suggest_subcommand(option)
        else
          # Generic message from OptionParser
          warn "Error: #{message}"
          # Attempt to derive a helpful hint for enumerated options
          if (hint = build_enum_value_hint(argv))
            warn hint
          end
        end
        warn usage_hint
        exit 1
      end

      private

      def extract_invalid_option(message)
        message.match(/invalid option: (.+)/)[1] rescue nil
      end

      def suggest_subcommand(option)
        subcommand = option[2..-1]
        warn "Error: '#{option}' is not a valid option. Did you mean the '#{subcommand}' subcommand?"
        warn "Try: #{program_name} #{subcommand} [args]"
      end

      def build_enum_value_hint(argv)
        rules = enumerated_option_rules
        tokens = Array(argv)
        rules.each do |rule|
          hint = build_hint_for_rule(rule, tokens)
          return hint if hint
        end
        nil
      end

      def build_hint_for_rule(rule, tokens)
        switches = rule[:switches]
        allowed = rule[:values]
        display = rule[:display] || allowed.join(', ')
        preferred = switches.find { |s| s.start_with?('--') } || switches.first

        tokens.each_with_index do |tok, i|
          # --opt=value form
          if equal_form_match?(tok, switches, preferred)
            hint = handle_equal_form(tok, switches, preferred, display, allowed)
            return hint if hint
          end

          # --opt value or -o value form
          if switches.include?(tok)
            hint = handle_space_form(tokens, i, preferred, display, allowed)
            return hint if hint
          end
        end
        nil
      end

      def equal_form_match?(token, switches, preferred)
        token.start_with?(preferred + '=') || switches.any? { |s| token.start_with?(s + '=') }
      end

      def handle_equal_form(token, switches, preferred, display, allowed)
        sw = switches.find { |s| token.start_with?(s + '=') } || preferred
        val = token.split('=', 2)[1]
        "Valid values for #{sw}: #{display}" if val && !allowed.include?(val)
      end

      def handle_space_form(tokens, index, preferred, display, allowed)
        val = tokens[index + 1]
        # If missing value, provide hint; if present and invalid, also hint
        if val.nil? || val.start_with?('-') || !allowed.include?(val)
          "Valid values for #{preferred}: #{display}"
        end
      end

      def enumerated_option_rules
        [
          { switches: ['-S', '--stale'], values: %w[off o error e], display: 'o[ff]|e[rror]' },
          { switches: ['-s', '--source'], values: %w[full f uncovered u], 
            display: 'f[ull]|u[ncovered]' },
          { switches: ['--error-mode'], values: %w[off on trace t], display: 'off|on|t[race]' },
          { switches: ['-o', '--sort-order'], values: %w[a d ascending descending], 
            display: 'a[scending]|d[escending]' }
        ]
      end

      def program_name
        'simplecov-mcp'
      end
    end
  end
end
