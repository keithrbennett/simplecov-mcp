# frozen_string_literal: true

require 'shellwords'
require_relative '../option_normalizers'

module SimpleCovMcp
  module OptionParsers
    class EnvOptionsParser
      ENV_VAR = 'SIMPLECOV_MCP_OPTS'

      def initialize(env_var: ENV_VAR)
        @env_var = env_var
      end

      def parse_env_opts
        opts_string = ENV[@env_var]
        return [] unless opts_string && !opts_string.empty?

        begin
          Shellwords.split(opts_string)
        rescue ArgumentError => e
          raise SimpleCovMcp::ConfigurationError, "Invalid #{@env_var} format: #{e.message}"
        end
      end

      def pre_scan_error_mode(argv, error_mode_normalizer: method(:normalize_error_mode))
        # Quick scan for --error-mode to ensure early errors are logged correctly
        argv.each_with_index do |arg, i|
          if arg == '--error-mode' && argv[i + 1]
            return error_mode_normalizer.call(argv[i + 1])
          elsif arg.start_with?('--error-mode=')
            value = arg.split('=', 2)[1]
            return nil if value.to_s.empty?
            return error_mode_normalizer.call(value) if value
          end
        end
        nil
      rescue StandardError
        # Ignore errors during pre-scan; they'll be caught during actual parsing
        nil
      end

      private

      def normalize_error_mode(value)
        OptionNormalizers.normalize_error_mode(value, strict: false, default: :on)
      end
    end
  end
end
