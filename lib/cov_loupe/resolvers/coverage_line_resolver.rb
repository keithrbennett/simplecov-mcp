# frozen_string_literal: true

module CovLoupe
  module Resolvers
    class CoverageLineResolver
      def initialize(cov_data, root:)
        @cov_data = cov_data
        @root = root
      end

      def lookup_lines(file_abs)
        # First try exact match
        direct_match = find_direct_match(file_abs)
        return direct_match if direct_match

        # Then try without current working directory prefix
        stripped_match = find_stripped_match(file_abs)
        return stripped_match if stripped_match

        # Finally try matching by basename
        basename_match = find_basename_match(file_abs)
        return basename_match if basename_match

        raise_not_found_error(file_abs)
      end

      attr_reader :cov_data

      private def find_direct_match(file_abs)
        fetch_lines_for_path(file_abs)
      end

      private def find_stripped_match(file_abs)
        return unless @root
        return unless file_abs.start_with?(resolution_root_with_slash)

        relative_path = file_abs[(resolution_root.length + 1)..]
        fetch_lines_for_path(relative_path)
      end

      private def find_basename_match(file_abs)
        target_basename = File.basename(file_abs)

        # Look for any key that ends with /target_basename or is exactly target_basename
        match_keys = cov_data.each_key.select do |key|
          key == target_basename || key.end_with?("/#{target_basename}")
        end

        return fetch_lines_for_path(match_keys.first) if match_keys.length == 1
        return if match_keys.empty?

        raise FileError, "Multiple coverage entries match basename #{target_basename}: #{match_keys.join(', ')}"
      end

      private def fetch_lines_for_path(path)
        return unless cov_data.key?(path)

        entry = cov_data[path]
        lines = lines_from_entry(entry)
        return lines if lines

        raise CorruptCoverageDataError, "Entry for #{path} has no valid lines or branches"
      end

      private def resolution_root
        @resolution_root ||= @root
      end

      private def resolution_root_with_slash
        return unless resolution_root

        @resolution_root_with_slash ||= "#{resolution_root}/"
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
      #
      # The synthesis process:
      # 1. Flatten the branch hash into [metadata, hits] pairs.
      # 2. Extract the line number from the metadata (handling both Array and String formats).
      # 3. Sum hits for each line.
      # 4. Construct a dense array matching SimpleCov's line-based format.
      private def synthesize_lines_from_branches(branch_data)
        # Detailed shape and rationale documented in docs/BRANCH_ONLY_COVERAGE.md
        return unless branch_data.is_a?(Hash) && branch_data.any?

        line_hits = {}

        branch_data
          .values # Extract all branch target hashes, discarding the metadata keys
          .select { |targets| targets.is_a?(Hash) } # ignore malformed branch entries
          .flat_map(&:to_a) # flatten each branch target into [meta, hits] pairs
          .filter_map do |meta, hits|
            # Extract the covered line; filter_map discards nil results.
            line_number = extract_line_number(meta)
            line_number && [line_number, hits.to_i]
          end
          .each do |line_number, hits|
            # Accumulate hits for each line (multiple branches may execute on the same line)
            line_hits[line_number] = line_hits.fetch(line_number, 0) + hits
          end

        return if line_hits.empty?

        max_line = line_hits.keys.max
        # Build a dense array up to the highest line recorded so downstream
        # consumers see the familiar SimpleCov shape (nil for untouched lines).
        # Uses idx + 1 because SimpleCov line numbers are 1-based (array indices are 0-based).
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

        # Parse stringified metadata by removing brackets and splitting on commas
        # E.g., "[:if, 0, 12, 4, 20, 29]" becomes [":if", "0", "12", "4", "20", "29"]
        tokens = meta.to_s.tr('[]', '').split(',').map(&:strip)
        return if tokens.length < 3 # Need at least 3 elements to access index 2

        Integer(tokens[2], exception: false)
        # Any parsing errors result in nil; callers treat that as "no line".
      rescue ArgumentError, TypeError
        nil
      end
    end
  end
end
