# frozen_string_literal: true

require_relative '../formatters/source_formatter'

module SimpleCovMcp
  module Commands
    class BaseCommand
      def initialize(cli_context)
        @cli = cli_context
        @source_formatter = Formatters::SourceFormatter.new(
          color_enabled: cli_context.instance_variable_get(:@color)
        )
      end

      protected

      attr_reader :cli

      def model
        @model ||= CoverageModel.new(
          root: cli.instance_variable_get(:@root),
          resultset: cli.instance_variable_get(:@resultset),
          staleness: cli.instance_variable_get(:@stale_mode),
          tracked_globs: cli.instance_variable_get(:@tracked_globs)
        )
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
        return false unless cli.instance_variable_get(:@json)
        puts JSON.pretty_generate(model.relativize(obj))
        true
      end

      def emit_json_with_optional_source(data, model, path)
        return false unless cli.instance_variable_get(:@json)
        relativized = model.relativize(data)
        if cli.instance_variable_get(:@source_mode)
          payload = relativized.merge('source' => build_source_payload(model, path))
          puts JSON.pretty_generate(payload)
        else
          puts JSON.pretty_generate(relativized)
        end
        true
      end

      def build_source_payload(model, path)
        source_mode = cli.instance_variable_get(:@source_mode)
        source_context = cli.instance_variable_get(:@source_context)
        @source_formatter.build_source_payload(model, path, mode: source_mode, context: source_context)
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
        source_mode = cli.instance_variable_get(:@source_mode)
        source_context = cli.instance_variable_get(:@source_context)
        formatted = @source_formatter.format_source_for(model, path, mode: source_mode, context: source_context)
        puts formatted
      end
    end
  end
end