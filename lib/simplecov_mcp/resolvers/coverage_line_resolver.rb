# frozen_string_literal: true

module SimpleCovMcp
  module Resolvers
    class CoverageLineResolver
      def initialize(cov_data)
        @cov_data = cov_data
      end

      def lookup_lines(file_abs)
        # First try exact match
        direct_match = find_direct_match(file_abs)
        return direct_match if direct_match

        # Then try without current working directory prefix
        stripped_match = find_stripped_match(file_abs)
        return stripped_match if stripped_match

        raise_not_found_error(file_abs)
      end

      attr_reader :cov_data

      private def find_direct_match(file_abs)
        entry = cov_data[file_abs]
        lines_from_entry(entry)
      end

      private def find_stripped_match(file_abs)
        return unless file_abs.start_with?(cwd_with_slash)

        relative_path = file_abs[(cwd.length + 1)..]
        entry = cov_data[relative_path]
        lines_from_entry(entry)
      end

      private def cwd
        @cwd ||= Dir.pwd
      end

      private def cwd_with_slash
        @cwd_with_slash ||= "#{cwd}/"
      end

      private def raise_not_found_error(file_abs)
        raise FileError, "No coverage entry found for #{file_abs}"
      end

      # Entry may store exact line coverage, branch-only coverage, or neither.
      # Prefer the provided `lines` array but fall back to synthesizing one so
      # callers always receive something enumerable.
      #
      # Returning nil tells callers to keep searching; the resolver will raise
      # a FileError if no variant yields coverage data.
      private def lines_from_entry(entry)
        return unless entry.is_a?(Hash)

        lines = entry['lines']
        return lines if lines.is_a?(Array)

        synthesize_lines_from_branches(entry['branches'])
      end

      # Some SimpleCov configurations track only branch coverage. When the
      # resultset omits the legacy `lines` array we rebuild a minimal substitute
      # so the rest of the pipeline (summaries, uncovered lines, staleness) can
      # continue to operate.
      #
      # Branch data looks like:
      #   "[:if, 0, 12, 4, 20, 29]" => { "[:then, ...]" => hits, ... }
      # We care about the third tuple element (line number). We sum branch-leg
      # hits per line so the synthetic array still behaves like legacy line
      # coverage (any positive value counts as executed).
      private def synthesize_lines_from_branches(branch_data)
        # Detailed shape and rationale documented in docs/BRANCH_ONLY_COVERAGE.md
        return unless branch_data.is_a?(Hash) && branch_data.any?

        line_hits = {}

        branch_data
          .values
          .select { |targets| targets.is_a?(Hash) } # ignore malformed branch entries
          .flat_map(&:to_a) # flatten each branch target into [meta, hits]
          .filter_map do |meta, hits|
            # Extract the covered line; filter_map discards nil results.
            line_number = extract_line_number(meta)
            line_number && [line_number, hits.to_i]
          end
          .each do |line_number, hits|
            line_hits[line_number] = line_hits.fetch(line_number, 0) + hits
          end

        return if line_hits.empty?

        max_line = line_hits.keys.max
        # Build a dense array up to the highest line recorded so downstream
        # consumers see the familiar SimpleCov shape (nil for untouched lines).
        Array.new(max_line) { |idx| line_hits[idx + 1] }
      end

      # Branch metadata arrives as either the raw SimpleCov array
      # (e.g. [:if, 0, 12, 4, 20, 29]) or the stringified JSON version
      # ("[:if, 0, 12, 4, 20, 29]"). We normalize both forms and pull the line.
      private def extract_line_number(meta)
        if meta.is_a?(Array)
          line_token = meta[2]
          # Integer(..., exception: false) returns nil on failure, so malformed
          # tuples quietly drop out of the synthesized array.
          return Integer(line_token, exception: false)
        end

        tokens = meta.to_s.tr('[]', '').split(',').map(&:strip)
        return if tokens.length < 3

        Integer(tokens[2], exception: false)
        # Any parsing errors result in nil; callers treat that as "no line".
      rescue ArgumentError, TypeError
        nil
      end
    end
  end
end
