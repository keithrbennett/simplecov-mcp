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

    def log(msg)
      log_file = SimpleCovMcp.active_log_file

      case log_file
      when 'stdout'
        $stdout.puts "[#{Time.now.iso8601}] #{msg}"
      when 'stderr'
        $stderr.puts "[#{Time.now.iso8601}] #{msg}"
      else
        # Handles both nil (default) and custom file paths
        path_to_log = log_file || DEFAULT_LOG_FILESPEC
        File.open(File.expand_path(path_to_log), 'a') { |f| f.puts "[#{Time.now.iso8601}] #{msg}" }
      end
    rescue StandardError
      # ignore logging failures
    end

    def find_resultset(root, resultset: nil)
      Resolvers::ResolverFactory.find_resultset(root, resultset: resultset)
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
