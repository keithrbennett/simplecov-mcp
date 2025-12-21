# frozen_string_literal: true

require_relative 'resolvers/resolver_helpers'

module CovLoupe
  # Caches CoverageModel instances keyed by resolved resultset path.
  # Entries are invalidated when the resultset mtime changes.
  class ModelCache
    def initialize
      @entries = {}
    end

    def fetch(config)
      resultset_path = resolve_resultset_path(config)
      entry = @entries[resultset_path]
      return unless entry

      current_mtime = resultset_mtime(resultset_path)
      return unless entry[:mtime] == current_mtime

      entry[:model]
    end

    def store(config, model)
      resultset_path = resolve_resultset_path(config)
      @entries[resultset_path] = {
        model: model,
        mtime: resultset_mtime(resultset_path)
      }
      model
    end

    private def resolve_resultset_path(config)
      root = File.absolute_path(config[:root] || '.')
      Resolvers::ResolverHelpers.find_resultset(root, resultset: config[:resultset])
    end

    private def resultset_mtime(resultset_path)
      File.mtime(resultset_path).to_i
    end
  end
end
