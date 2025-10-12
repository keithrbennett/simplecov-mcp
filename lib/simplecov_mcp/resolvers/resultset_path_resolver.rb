# frozen_string_literal: true

require 'pathname'

module SimpleCovMcp
  module Resolvers
    class ResultsetPathResolver
      DEFAULT_CANDIDATES = [
        '.resultset.json',
        'coverage/.resultset.json',
        'tmp/.resultset.json'
      ].freeze

      def initialize(root: Dir.pwd, candidates: DEFAULT_CANDIDATES)
        @root = root
        @candidates = candidates
      end

      def find_resultset(resultset: nil)
        if resultset && !resultset.empty?
          path = normalize_resultset_path(resultset)
          if (resolved = resolve_candidate(path, strict: true))
            return resolved
          end
        end

        resolve_fallback or raise_not_found_error
      end

      private

      def resolve_candidate(path, strict:)
        return path if File.file?(path)
        return resolve_directory(path) if File.directory?(path)
        raise_not_found_error_for_file(path) if strict
        nil
      end

      def resolve_directory(path)
        candidate = File.join(path, '.resultset.json')
        return candidate if File.file?(candidate)
        raise "No .resultset.json found in directory: #{path}"
      end

      def raise_not_found_error_for_file(path)
        raise "Specified resultset not found: #{path}"
      end

      def resolve_fallback
        @candidates
          .map { |p| File.absolute_path(p, @root) }
          .find { |p| File.file?(p) }
      end

      def normalize_resultset_path(resultset)
        candidate = Pathname.new(resultset)
        return candidate.cleanpath.to_s if candidate.absolute?

        expanded = File.expand_path(resultset, Dir.pwd)
        return expanded if within_root?(expanded)

        File.absolute_path(resultset, @root)
      end

      def within_root?(path)
        normalized_root = Pathname.new(@root).cleanpath.to_s
        root_with_sep = normalized_root.end_with?(File::SEPARATOR) ? normalized_root : "#{normalized_root}#{File::SEPARATOR}"
        path == normalized_root || path.start_with?(root_with_sep)
      end

      def raise_not_found_error
        raise "Could not find .resultset.json under #{@root.inspect}; run tests or set --resultset option"
      end
    end
  end
end
