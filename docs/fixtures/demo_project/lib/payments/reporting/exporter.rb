# frozen_string_literal: true

module Payments
  module Reporting
    class Exporter
      def initialize(writer:)
        @writer = writer
      end

      def export(rows)
        rows.each { |row| @writer.write(row) }
        @writer.flush
      end
    end
  end
end
