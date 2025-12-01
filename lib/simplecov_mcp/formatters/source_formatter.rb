# frozen_string_literal: true

module SimpleCovMcp
  module Formatters
    class SourceFormatter
      def initialize(color_enabled: true)
        @color_enabled = color_enabled
      end

      def format_source_for(model, path, mode: nil, context: 2)
        raw = fetch_raw(model, path)
        return '[source not available]' unless raw

        abs = raw['file']
        lines_cov = raw['lines']
        src = File.file?(abs) ? File.readlines(abs, chomp: true) : nil
        return '[source not available]' unless src

        begin
          rows = build_source_rows(src, lines_cov, mode: mode, context: context)
          format_source_rows(rows)
        rescue StandardError
          # If any unexpected formatting/indexing error occurs, avoid crashing the CLI
          '[source not available]'
        end
      end

      def build_source_payload(model, path, mode: nil, context: 2)
        raw = fetch_raw(model, path)
        return nil unless raw

        abs = raw['file']
        lines_cov = raw['lines']
        src = File.file?(abs) ? File.readlines(abs, chomp: true) : nil
        return nil unless src

        build_source_rows(src, lines_cov, mode: mode, context: context)
      end

      def build_source_rows(src_lines, cov_lines, mode:, context: 2)
        # Normalize inputs defensively to avoid type errors in formatting
        coverage_lines = cov_lines || []
        context_line_count = begin
          context.to_i
        rescue
          2
        end
        context_line_count = 0 if context_line_count.negative?

        n = src_lines.length
        include_line = Array.new(n, mode == :full)
        if mode == :uncovered
          include_line = mark_uncovered_lines_with_context(coverage_lines, context_line_count, n)
        end

        build_row_data(src_lines, coverage_lines, include_line)
      end

      def format_source_rows(rows)
        marker = ->(covered, _hits) do
          case covered
          when true then colorize('✓', :green)
          when false then colorize('·', :red)
          else colorize(' ', :dim)
          end
        end

        lines = []
        lines << format('%6s  %2s | %s', 'Line', ' ', 'Source')
        lines << format('%6s  %2s-+-%s', '------', '--', '-' * 60)

        rows.each do |r|
          m = marker.call(r['covered'], r['hits'])
          lines << format('%6d  %2s | %s', r['line'], m, r['code'])
        end
        lines.join("\n")
      end

      def format_detailed_rows(rows)
        # Simple aligned columns: line, hits, covered
        out = []
        out << format('%6s  %6s  %7s', 'Line', 'Hits', 'Covered')
        out << format('%6s  %6s  %7s', '-----', '----', '-------')
        rows.each do |r|
          out << format('%6d  %6d  %5s', r['line'], r['hits'], r['covered'] ? 'yes' : 'no')
        end
        out.join("\n")
      end

      attr_reader :color_enabled

      private def fetch_raw(model, path)
        @raw_cache ||= {}
        return @raw_cache[path] if @raw_cache.key?(path)

        raw = model.raw_for(path)
        @raw_cache[path] = raw
      rescue StandardError
        nil
      end

      private def mark_uncovered_lines_with_context(coverage_lines, context_line_count, total_lines)
        include_line = Array.new(total_lines, false)
        misses = find_uncovered_lines(coverage_lines)

        misses.each do |uncovered_line_index|
          mark_context_lines(include_line, uncovered_line_index, context_line_count, total_lines)
        end

        include_line
      end

      private def find_uncovered_lines(coverage_lines)
        misses = []
        coverage_lines.each_with_index do |hits, i|
          misses << i if !hits.nil? && hits.to_i == 0
        end
        misses
      end

      private def mark_context_lines(include_line, center_line, context_count, total_lines)
        start_line = [0, center_line - context_count].max
        end_line = [total_lines - 1, center_line + context_count].min

        (start_line..end_line).each { |i| include_line[i] = true }
      end

      private def build_row_data(src_lines, coverage_lines, include_line)
        out = []
        src_lines.each_with_index do |code, i|
          next unless include_line[i]

          hits = coverage_lines[i]
          covered = hits.nil? ? nil : hits.to_i > 0
          # Use string keys consistently across CLI formatting and JSON payloads
          out << { 'line' => i + 1, 'code' => code, 'hits' => hits, 'covered' => covered }
        end
        out
      end

      private def colorize(text, color)
        return text unless color_enabled

        codes = { green: 32, red: 31, dim: 2 }
        code = codes[color] || 0
        "\e[#{code}m#{text}\e[0m"
      end
    end
  end
end
