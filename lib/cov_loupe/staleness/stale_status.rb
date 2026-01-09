# frozen_string_literal: true

module CovLoupe
  # Helpers for working with staleness status values.
  module StaleStatus
    VALID_STATUSES = %w[ok missing newer length_mismatch error].freeze

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
