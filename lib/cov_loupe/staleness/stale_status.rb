# frozen_string_literal: true

module CovLoupe
  # Helpers for working with staleness status values.
  module StaleStatus
    module_function def stale?(value)
      value && value != :ok
    end
  end
end
