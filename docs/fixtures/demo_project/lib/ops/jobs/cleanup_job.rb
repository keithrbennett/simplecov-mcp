# frozen_string_literal: true

module Ops
  module Jobs
    class CleanupJob
      def initialize(storage:)
        @storage = storage
      end

      def perform
        @storage.prune!
        :ok
      end
    end
  end
end
