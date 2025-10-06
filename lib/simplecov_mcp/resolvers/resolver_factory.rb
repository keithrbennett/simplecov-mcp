# frozen_string_literal: true

require_relative 'resultset_path_resolver'
require_relative 'coverage_line_resolver'

module SimpleCovMcp
  module Resolvers
    class ResolverFactory
      def self.create_resultset_resolver(root: Dir.pwd, resultset: nil, candidates: nil)
        resolver_class = candidates ? ResultsetPathResolver.new(root: root, candidates: candidates) : ResultsetPathResolver.new(root: root)
      end

      def self.create_coverage_resolver(cov_data)
        CoverageLineResolver.new(cov_data)
      end

      # Legacy compatibility methods for CovUtil
      def self.find_resultset(root, resultset: nil)
        ResultsetPathResolver.new(root: root).find_resultset(resultset: resultset)
      end

      def self.resolve_resultset_candidate(path, strict:)
        ResultsetPathResolver.new.resolve_candidate(path, strict: strict)
      end

      def self.lookup_lines(cov, file_abs)
        CoverageLineResolver.new(cov).lookup_lines(file_abs)
      end
    end
  end
end