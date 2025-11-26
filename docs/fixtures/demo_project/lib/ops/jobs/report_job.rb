# frozen_string_literal: true

module Ops
  module Jobs
    class ReportJob
      def initialize(exporter:)
        @exporter = exporter
      end

      def perform(rows)
        return :no_data if rows.empty?

        @exporter.export(rows)
      end
    end
  end
end
