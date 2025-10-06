# frozen_string_literal: true

require_relative 'base_command'
require_relative 'list_command'
require_relative 'version_command'
require_relative 'summary_command'
require_relative 'raw_command'
require_relative 'uncovered_command'
require_relative 'detailed_command'

module SimpleCovMcp
  module Commands
    class CommandFactory
      COMMAND_MAP = {
        'list' => ListCommand,
        'version' => VersionCommand,
        'summary' => SummaryCommand,
        'raw' => RawCommand,
        'uncovered' => UncoveredCommand,
        'detailed' => DetailedCommand
      }.freeze

      def self.create(command_name, cli_context)
        command_class = COMMAND_MAP[command_name]
        unless command_class
          raise UsageError.for_subcommand('list | summary <path> | raw <path> | uncovered <path> | detailed <path> | version')
        end

        command_class.new(cli_context)
      end

      def self.available_commands
        COMMAND_MAP.keys
      end
    end
  end
end