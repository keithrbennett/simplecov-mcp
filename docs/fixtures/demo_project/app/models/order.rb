# frozen_string_literal: true

module DemoApp
  module Models
    class Order
      def initialize(id:, total_cents:)
        @id = id
        @total_cents = total_cents
      end

      def total_dollars
        (@total_cents / 100.0).round(2)
      end

      def expensive?(threshold_cents = 10_000)
        @total_cents >= threshold_cents
      end
    end
  end
end
