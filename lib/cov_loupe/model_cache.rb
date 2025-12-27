# frozen_string_literal: true

require_relative 'resolvers/resolver_helpers'

module CovLoupe
  # Caches CoverageModel instances keyed by resolved resultset path and root.
  # Entries are invalidated when the resultset mtime changes.
  class ModelCache
    def initialize
      @entries = {}
    end

    def fetch(config)
      cache_key = build_cache_key(config)
      entry = @entries[cache_key]
      return unless entry

      signature = resultset_signature(cache_key[:resultset_path])
      cached_signature = entry[:signature]
      return unless signature && cached_signature && signature == cached_signature

      entry[:model]
    end

    def store(config, model)
      cache_key = build_cache_key(config)
      signature = resultset_signature(cache_key[:resultset_path])
      return model unless signature

      @entries[cache_key] = {
        model: model,
        signature: signature
      }
      model
    end

    private def build_cache_key(config)
      root = File.absolute_path(config[:root] || '.')
      resultset_path = Resolvers::ResolverHelpers.find_resultset(
        root, resultset: config[:resultset]
      )
      { root: root, resultset_path: resultset_path }
    end

    private def resultset_signature(resultset_path)
      stat = File.stat(resultset_path)
      {
        mtime: stat.mtime,
        mtime_nsec: stat.respond_to?(:mtime_nsec) ? stat.mtime_nsec : stat.mtime.nsec,
        size: stat.size,
        inode: stat.respond_to?(:ino) ? stat.ino : nil
      }.compact
    rescue Errno::ENOENT, Errno::EACCES
      nil
    end
  end
end
