# frozen_string_literal: true

module DemoApp
  module Controllers
    module Admin
      class AuditLogsController
        def initialize(logger:)
          @logger = logger
        end

        def capture(event)
          return if event.nil? || event[:action].to_s.empty?

          @logger.info("audit=#{event[:action]} user=#{event[:user]}")
        end
      end
    end
  end
end
