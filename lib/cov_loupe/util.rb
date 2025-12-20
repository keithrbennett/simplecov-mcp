# frozen_string_literal: true

require_relative 'resolvers/resolver_factory'

module CovLoupe
  RESULTSET_CANDIDATES = [
    '.resultset.json',
    'coverage/.resultset.json',
    'tmp/.resultset.json'
  ].freeze

  module CovUtil
    module_function def find_resultset(root, resultset: nil)
      Resolvers::ResolverFactory.find_resultset(root, resultset: resultset)
    end

    module_function def lookup_lines(cov, file_abs)
      Resolvers::ResolverFactory.lookup_lines(cov, file_abs)
    end

    module_function def summary(arr)
      total = 0
      covered = 0
      arr.compact.each do |hits|
        total += 1
        covered += 1 if hits.to_i > 0
      end
      percentage = total.zero? ? 100.0 : ((covered.to_f * 100.0 / total) * 100).round / 100.0
      { 'covered' => covered, 'total' => total, 'percentage' => percentage }
    end

    module_function def uncovered(arr)
      out = []

      arr.each_with_index do |hits, i|
        next if hits.nil?

        out << (i + 1) if hits.to_i.zero?
      end
      out
    end

    module_function def detailed(arr)
      rows = []
      arr.each_with_index do |hits, i|
        h = hits&.to_i
        rows << { 'line' => i + 1, 'hits' => h, 'covered' => h.positive? } if h
      end
      rows
    end
  end
end
