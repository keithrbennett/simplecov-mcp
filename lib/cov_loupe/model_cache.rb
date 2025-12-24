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

      current_mtime = resultset_mtime(cache_key[:resultset_path])
      return unless entry[:mtime] == current_mtime

      entry[:model]
    end

    def store(config, model)
      cache_key = build_cache_key(config)
      @entries[cache_key] = {
        model: model,
        mtime: resultset_mtime(cache_key[:resultset_path])
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

    private def resultset_mtime(resultset_path)
      File.mtime(resultset_path)
    end
  end
end
