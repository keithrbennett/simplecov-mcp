# frozen_string_literal: true

require 'json'
require_relative '../formatters'
require_relative '../formatters/source_formatter'
require_relative '../model'
require_relative '../errors'

module SimpleCovMcp
  module Commands
    class BaseCommand
      def initialize(cli_context)
        @cli = cli_context
        @config = cli_context.config
        @source_formatter = Formatters::SourceFormatter.new(
          **config.formatter_options
        )
      end

      protected

      attr_reader :cli, :config, :source_formatter

      def model
        @model ||= CoverageModel.new(**config.model_options)
      end

      def handle_with_path(args, name)
        path = args.shift or raise UsageError.for_subcommand("#{name} <path>")
        yield(path)
      rescue Errno::ENOENT
        raise FileNotFoundError.new("File not found: #{path}")
      rescue Errno::EACCES
        raise FilePermissionError.new("Permission denied: #{path}")
      end

      def maybe_output_structured_format?(obj, model)
        return false if config.format == :table

        puts SimpleCovMcp::Formatters.format(model.relativize(obj), config.format)
        true
      end

      def emit_structured_format_with_optional_source?(data, model, path)
        return false if config.format == :table

        relativized = model.relativize(data)
        if config.source_mode
          payload = relativized.merge('source' => build_source_payload(model, path))
          puts SimpleCovMcp::Formatters.format(payload, config.format)
        else
          puts SimpleCovMcp::Formatters.format(relativized, config.format)
        end
        true
      end

      def build_source_payload(model, path)
        source_formatter.build_source_payload(model, path, mode: config.source_mode,
          context: config.source_context)
      end

      def print_source_for(model, path)
        formatted = source_formatter.format_source_for(model, path, mode: config.source_mode,
          context: config.source_context)
        puts formatted
      end
    end
  end
end
