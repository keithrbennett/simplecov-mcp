# frozen_string_literal: true

require 'pathname'

require_relative '../errors'
require_relative '../path_utils'

module CovLoupe
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

      private def resolve_candidate(path, strict:)
        return path if File.file?(path)
        return resolve_directory(path) if File.directory?(path)

        raise_not_found_error_for_file(path) if strict
        nil
      end

      private def resolve_directory(path)
        candidate = File.join(path, '.resultset.json')
        return candidate if File.file?(candidate)

        raise ResultsetNotFoundError, "No .resultset.json found in directory: #{path}"
      end

      private def raise_not_found_error_for_file(path)
        raise ResultsetNotFoundError, "Specified resultset not found: #{path}"
      end

      private def resolve_fallback
        @candidates
          .map { |p| PathUtils.expand(p, @root) }
          .find { |p| File.file?(p) }
      end

      private def normalize_resultset_path(resultset)
        Pathname.new(resultset)
        expanded_resultset = PathUtils.expand(resultset, Dir.pwd)
        expanded_root = PathUtils.expand(resultset, @root)

        if ambiguous_resultset_path?(expanded_resultset, expanded_root)
          raise_ambiguous_resultset_error(expanded_resultset, expanded_root)
        end

        return expanded_resultset if valid_resultset_location?(expanded_resultset)
        return expanded_root if valid_resultset_location?(expanded_root)

        return expanded_resultset if within_root?(expanded_resultset)

        expanded_root
      end

      private def within_root?(path)
        PathUtils.within_root?(path, @root)
      end

      private def ambiguous_resultset_path?(expanded_pwd, expanded_root)
        return false if expanded_pwd == expanded_root

        valid_resultset_location?(expanded_pwd) && valid_resultset_location?(expanded_root)
      end

      private def valid_resultset_location?(path)
        return true if File.file?(path)
        return false unless File.directory?(path)

        File.file?(File.join(path, '.resultset.json'))
      end

      private def raise_ambiguous_resultset_error(expanded_pwd, expanded_root)
        raise ConfigurationError, "Ambiguous resultset location specified. Both #{expanded_pwd} and #{expanded_root} exist. " \
                                  'Use `./` or an absolute filespec to disambiguate.'
      end

      private def raise_not_found_error
        message = "Could not find .resultset.json under #{@root.inspect}; run tests or set --resultset option"
        CovLoupe.logger.error(message) if CovLoupe.logger
        raise ResultsetNotFoundError, message
      end
    end
  end
end
