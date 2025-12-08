# frozen_string_literal: true

require_relative 'resolvers/resolver_factory'

module CovLoupe
  RESULTSET_CANDIDATES = [
    '.resultset.json',
    'coverage/.resultset.json',
    'tmp/.resultset.json'
  ].freeze

  DEFAULT_LOG_FILESPEC = './cov_loupe.log'

  module CovUtil
    module_function def log(msg)
      log_file = CovLoupe.active_log_file

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
    rescue => e
      # Fallback to stderr if file logging fails, but suppress in MCP mode
      # to avoid interfering with JSON-RPC protocol
      unless CovLoupe.context.mcp_mode?
        begin
          $stderr.puts "[#{Time.now.iso8601}] LOGGING ERROR: #{e.message}"
          $stderr.puts "[#{Time.now.iso8601}] #{msg}"
        rescue
          # Silently ignore only stderr fallback failures
        end
      end
    end

    # Safe logging that never raises - use when logging should not interrupt execution.
    # Unlike `log`, this method guarantees it will never propagate exceptions.
    module_function def safe_log(msg)
      log(msg)
    rescue
      # Silently ignore all logging failures
    end

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
