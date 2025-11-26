# frozen_string_literal: true

module Payments
  class RefundService
    def initialize(processor:)
      @processor = processor
    end

    def refund(order_id:, cents:)
      return :invalid if cents.to_i <= 0

      @processor.refund(order_id: order_id, cents: cents)
    end
  end
end
