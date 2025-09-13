# frozen_string_literal: true

module Simplecov
  module Mcp
    RESULTSET_CANDIDATES = [
      ".resultset.json",
      "coverage/.resultset.json",
      "tmp/.resultset.json"
    ].freeze

    module CovUtil
      module_function

      def log(msg)
        path = File.expand_path("~/coverage_mcp.log")
        File.open(path, "a") { |f| f.puts "[#{Time.now.iso8601}] #{msg}" }
      rescue StandardError
        # ignore logging failures
      end

      def find_resultset(root)
        if (env = ENV["SIMPLECOV_RESULTSET"]) && !env.empty?
          path = File.absolute_path(env, root)
          return path if File.file?(path)
        end
        RESULTSET_CANDIDATES
          .map { |p| File.absolute_path(p, root) }
          .find { |p| File.file?(p) } or
          raise "Could not find .resultset.json under #{root.inspect}; run tests or set SIMPLECOV_RESULTSET"
      end

      # returns { abs_path => {"lines" => [hits|nil,...]} }
      def load_latest_coverage(root)
        rs = find_resultset(root)
        raw = JSON.parse(File.read(rs))
        _suite, data = raw.max_by { |_k, v| (v["timestamp"] || v["created_at"] || 0).to_i }
        cov = data["coverage"] or raise "No 'coverage' key in .resultset.json"
        cov.transform_keys { |k| File.absolute_path(k, root) }
      end

      def lookup_lines(cov, file_abs)
        if (h = cov[file_abs]) && h["lines"].is_a?(Array)
          return h["lines"]
        end

        # try without current working directory prefix
        cwd = Dir.pwd
        without = file_abs.sub(/\A#{Regexp.escape(cwd)}\//, "")
        if (h = cov[without]) && h["lines"].is_a?(Array)
          return h["lines"]
        end

        # fallback: basename match
        base = File.basename(file_abs)
        kv = cov.find { |k, v| File.basename(k) == base && v["lines"].is_a?(Array) }
        kv and return kv[1]["lines"]

        raise "No coverage entry found for #{file_abs}"
      end

      def summary(arr)
        total = 0
        covered = 0
        arr.each do |hits|
          next if hits.nil?
          total += 1
          covered += 1 if hits.to_i > 0
        end
        pct = total.zero? ? 100.0 : ((covered.to_f * 100.0 / total) * 100).round / 100.0
        { "covered" => covered, "total" => total, "pct" => pct }
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
          next if hits.nil?
          h = hits.to_i
          rows << { line: i + 1, hits: h, covered: h.positive? }
        end
        rows
      end
    end
  end
end

