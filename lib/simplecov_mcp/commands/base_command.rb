# frozen_string_literal: true

require 'json'
require_relative '../formatters/source_formatter'

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
      rescue Errno::ENOENT => e
        raise FileNotFoundError.new("File not found: #{path}")
      rescue Errno::EACCES => e
        raise FilePermissionError.new("Permission denied: #{path}")
      end

      def maybe_output_json(obj, model)
        return false unless config.json
        puts JSON.pretty_generate(model.relativize(obj))
        true
      end

      def emit_json_with_optional_source(data, model, path)
        return false unless config.json
        relativized = model.relativize(data)
        if config.source_mode
          payload = relativized.merge('source' => build_source_payload(model, path))
          puts JSON.pretty_generate(payload)
        else
          puts JSON.pretty_generate(relativized)
        end
        true
      end

      def build_source_payload(model, path)
        source_formatter.build_source_payload(model, path, mode: config.source_mode, context: config.source_context)
      end

      def fetch_raw(model, path)
        @raw_cache ||= {}
        return @raw_cache[path] if @raw_cache.key?(path)

        raw = model.raw_for(path)
        @raw_cache[path] = raw
      rescue StandardError
        nil
      end

      def print_source_for(model, path)
        formatted = source_formatter.format_source_for(model, path, mode: config.source_mode, context: config.source_context)
        puts formatted
      end
    end
  end
end