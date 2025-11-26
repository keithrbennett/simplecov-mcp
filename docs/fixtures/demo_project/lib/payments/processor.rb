# frozen_string_literal: true

module Payments
  class Processor
    def initialize(gateway:)
      @gateway = gateway
    end

    def charge(user_id:, cents:)
      raise ArgumentError, "amount must be positive" if cents.to_i <= 0

      @gateway.charge(user_id: user_id, cents: cents)
    end
  end
end
