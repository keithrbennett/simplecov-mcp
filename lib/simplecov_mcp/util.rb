# frozen_string_literal: true

require_relative 'resolvers/resolver_factory'

module SimpleCovMcp
  RESULTSET_CANDIDATES = [
    '.resultset.json',
    'coverage/.resultset.json',
    'tmp/.resultset.json'
  ].freeze

  DEFAULT_LOG_FILESPEC = './simplecov_mcp.log'

  module CovUtil
    module_function

    def log_path
      unless SimpleCovMcp.respond_to?(:log_file)
        return File.expand_path(DEFAULT_LOG_FILESPEC)
      end

      log_file = SimpleCovMcp.log_file
      if log_file && !log_file.empty?
        log_file == '-' ? nil : File.expand_path(log_file)
      else
        File.expand_path(DEFAULT_LOG_FILESPEC)
      end
    end

    def log(msg)
      path = log_path
      return if path.nil? # Skip logging if path is nil (stderr mode or disabled)

      File.open(path, 'a') { |f| f.puts "[#{Time.now.iso8601}] #{msg}" }
    rescue StandardError
      # ignore logging failures
    end

    def find_resultset(root, resultset: nil)
      Resolvers::ResolverFactory.find_resultset(root, resultset: resultset)
    end

    def resolve_resultset_candidate(path, strict:)
      Resolvers::ResolverFactory.resolve_resultset_candidate(path, strict: strict)
    end

    def lookup_lines(cov, file_abs)
      Resolvers::ResolverFactory.lookup_lines(cov, file_abs)
    end

    def summary(arr)
      total = 0
      covered = 0
      arr.compact.each do |hits|
        total += 1
        covered += 1 if hits.to_i > 0
      end
      pct = total.zero? ? 100.0 : ((covered.to_f * 100.0 / total) * 100).round / 100.0
      { 'covered' => covered, 'total' => total, 'pct' => pct }
    end

    def uncovered(arr)
      out = []

      arr.each_with_index do |hits, i|
        next if hits.nil?
        out << (i + 1) if hits.to_i.zero?
      end
      out
    end

    def detailed(arr)
      rows = []
      arr.each_with_index do |hits, i|
        h = hits&.to_i
        rows << { 'line' => i + 1, 'hits' => h, 'covered' => h.positive? } if h
      end
      rows
    end
end
end
