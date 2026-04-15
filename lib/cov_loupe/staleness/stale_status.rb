# frozen_string_literal: true

module CovLoupe
  # Helpers for working with staleness status values.
  #
  # Status values used across the codebase:
  #   - 'ok'             → file is fresh, coverage matches source
  #   - 'missing'        → source file has been deleted
  #   - 'newer'          → source file mtime exceeds coverage timestamp
  #   - 'length_mismatch'→ source line count differs from coverage array length
  #   - 'error'          → source file could not be read
  #
  # Additional status values used in project totals (not per-file):
  #   - MISSING_FROM_DISK, NEWER, LENGTH_MISMATCH, UNREADABLE  → labels for stale breakdown
  #   - MISSING_FROM_COVERAGE → tracked file not found in coverage data
  #   - SKIPPED              → file skipped due to processing error
  module StaleStatus
    VALID_STATUSES = %w[ok missing newer length_mismatch error].freeze
    MISSING_FROM_DISK = 'missing_from_disk'
    NEWER = 'newer'
    LENGTH_MISMATCH = 'length_mismatch'
    UNREADABLE = 'unreadable'
    MISSING_FROM_COVERAGE = 'missing_from_coverage'
    SKIPPED = 'skipped'

    module_function def stale?(value)
      normalize(value) != 'ok'
    end

    module_function def normalize(value)
      raise ArgumentError, 'Stale status is missing' if value.nil?
      unless value.is_a?(String)
        raise ArgumentError, "Stale status must be a String, got #{value.class} (value: #{value.inspect})"
      end
      return value if VALID_STATUSES.include?(value)

      raise ArgumentError, "Unknown stale status: #{value.inspect}. " \
                           "Permitted values: #{VALID_STATUSES.join(', ')}"
    end
  end
end
