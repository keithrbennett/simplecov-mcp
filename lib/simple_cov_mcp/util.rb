# frozen_string_literal: true

module SimpleCovMcp
    RESULTSET_CANDIDATES = [
      '.resultset.json',
      'coverage/.resultset.json',
      'tmp/.resultset.json'
    ].freeze

    DEFAULT_LOG_FILESPEC = '~/simplecov_mcp.log'

    module CovUtil
      module_function

      def log_path
        if (env = ENV['SIMPLECOV_MCP_LOG']) && !env.empty?
          return env == '-' ? nil : File.expand_path(env)
        end

        # Check if we have a global log file setting
        if SimpleCovMcp.respond_to?(:log_file) && (log_file = SimpleCovMcp.log_file) && !log_file.empty?
          return log_file == '-' ? nil : File.expand_path(log_file)
        end
        File.expand_path(DEFAULT_LOG_FILESPEC)
      end

      def log(msg)
        # TODO: Memoize log_path
        path = log_path
        return if path.nil? # Skip logging if path is nil (stderr mode or disabled)

        File.open(path, 'a') { |f| f.puts "[#{Time.now.iso8601}] #{msg}" }
      rescue StandardError
        # ignore logging failures
      end

      def find_resultset(root, resultset: nil)
        # TODO: Remove this to_s. Maybe ensure somewhere else that resultset is either nil or a string
        if resultset && !resultset.to_s.empty?
          path = File.absolute_path(resultset, root)
          if (resolved = resolve_resultset_candidate(path, strict: true))
            return resolved
          end
        end

        if (env = ENV['SIMPLECOV_RESULTSET']) && !env.empty?
          path = File.absolute_path(env, root)
          if (resolved = resolve_resultset_candidate(path, strict: false))
            return resolved
          end
        end

        RESULTSET_CANDIDATES
          .map { |p| File.absolute_path(p, root) }
          .find { |p| File.file?(p) } or
          raise "Could not find .resultset.json under #{root.inspect}; run tests or set SIMPLECOV_RESULTSET"
      end


      def resolve_resultset_candidate(path, strict:)
        return path if File.file?(path)
        if File.directory?(path)
          candidate = File.join(path, '.resultset.json')
          return candidate if File.file?(candidate)
          raise "No .resultset.json found in directory: #{path}" if strict
          return nil
        end
        raise "Specified resultset not found: #{path}" if strict
        nil
      end

      def lookup_lines(cov, file_abs)
        if (h = cov[file_abs]) && h['lines'].is_a?(Array)
          return h['lines']
        end

        # try without current working directory prefix
        cwd = Dir.pwd
        # TODO - can the line below be simplified?
        without = file_abs.sub(/\A#{Regexp.escape(cwd)}\//, '')
        if (h = cov[without]) && h['lines'].is_a?(Array)
          return h['lines']
        end

        # fallback: basename match
        # TODO - Isn't this the same as what we did before, removing the pwd?
        base = File.basename(file_abs)
        kv = cov.find { |k, v| File.basename(k) == base && v['lines'].is_a?(Array) }
        kv and return kv[1]['lines']

        raise "No coverage entry found for #{file_abs}"
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
          # TODO - Can we simplify this with `if hits&.to_i.zero?`
          next if hits.nil?
          out << (i + 1) if hits.to_i.zero?
        end
        out
      end

      def detailed(arr)
        rows = []
        arr.each_with_index do |hits, i|
          # TODO - Can we simplify this with `if hits&.to_i.zero?`
          next if hits.nil?
          h = hits.to_i
          rows << { 'line' => i + 1, 'hits' => h, 'covered' => h.positive? }
        end
        rows
      end
    end
end
