# frozen_string_literal: true

require_relative 'resolvers/resolver_helpers'
require 'digest'

module CovLoupe
  # Caches CoverageModel instances keyed by resolved resultset path and root.
  # Entries are invalidated when the resultset signature or digest changes.
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
      return unless signature && cached_signature

      # If signature changed, cache is invalid
      return unless signature == cached_signature

      # Signature matches - verify content hasn't changed
      digest = resultset_digest(cache_key[:resultset_path])
      cached_digest = entry[:digest]
      return unless digest && cached_digest && digest == cached_digest

      entry[:model]
    end

    def store(config, model)
      cache_key = build_cache_key(config)
      signature = resultset_signature(cache_key[:resultset_path])
      return model unless signature

      digest = resultset_digest(cache_key[:resultset_path])
      return model unless digest

      @entries[cache_key] = {
        model: model,
        signature: signature,
        digest: digest
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

    # Compute a fast digest of the resultset file.
    # Uses MD5 which is fast and sufficient for cache validation
    # (we don't need cryptographic security, just change detection).
    private def resultset_digest(resultset_path)
      Digest::MD5.file(resultset_path).hexdigest
    rescue Errno::ENOENT, Errno::EACCES
      nil
    end
  end
end
