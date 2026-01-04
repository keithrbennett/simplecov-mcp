# frozen_string_literal: true

require 'digest'
require_relative 'model_data'
require_relative 'repositories/coverage_repository'

module CovLoupe
  # Thread-safe singleton cache for ModelData instances.
  # Entries are keyed by [resultset_path, volume_case_sensitive] and automatically invalidated
  # when the file changes.
  #
  # On every get() call, the cache checks the resultset file's signature (mtime/size/inode)
  # and digest (MD5) to ensure the data is current. If the file has changed, fresh data
  # is loaded automatically.
  #
  # The cache key includes volume_case_sensitive because path collision detection depends on
  # whether the volume is case-sensitive. SimpleCov generates absolute paths, so different
  # project roots can share cached data if they're on volumes with the same case-sensitivity.
  class ModelDataCache
    def initialize
      @entries = {}
      @mutex = Mutex.new
    end

    # Returns the singleton instance
    def self.instance
      @instance ||= new
    end

    # Fetches ModelData for the given resultset path.
    # Checks signature/digest on every call and reloads if the file has changed.
    #
    # @param resultset_path [String] Absolute path to .resultset.json
    # @param root [String] Project root directory for path normalization
    # @param volume_case_sensitive [Boolean] Whether the volume is case-sensitive
    # @return [ModelData] The cached or freshly loaded data
    def get(resultset_path, root:, volume_case_sensitive:)
      @mutex.synchronize do
        # Cache key includes volume_case_sensitive because path collision detection
        # depends on it. SimpleCov generates absolute paths, so different roots can
        # share cached data if they're on volumes with the same case-sensitivity.
        cache_key = [resultset_path, volume_case_sensitive]
        entry = @entries[cache_key]

        # Compute current signature and digest
        signature = compute_signature(resultset_path)
        digest = compute_digest(resultset_path)

        # Return cached data if it matches
        if entry && signature && digest &&
           entry[:signature] == signature &&
           entry[:digest] == digest
          return entry[:data]
        end

        # Load fresh data
        data = load_data(resultset_path, root)

        # Store with signature/digest if we computed them
        if signature && digest
          @entries[cache_key] = {
            data: data,
            signature: signature,
            digest: digest
          }
        end

        data
      end
    end

    # Clears all cached entries (primarily for testing)
    def clear
      @mutex.synchronize { @entries.clear }
    end

    private def load_data(resultset_path, root)
      repo = Repositories::CoverageRepository.new(
        root: root,
        resultset_path: resultset_path,
        logger: CovLoupe.logger
      )

      ModelData.new(
        coverage_map: repo.coverage_map,
        timestamp: repo.timestamp,
        resultset_path: resultset_path
      )
    end

    private def compute_signature(resultset_path)
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
    private def compute_digest(resultset_path)
      Digest::MD5.file(resultset_path).hexdigest
    rescue Errno::ENOENT, Errno::EACCES
      nil
    end
  end
end
