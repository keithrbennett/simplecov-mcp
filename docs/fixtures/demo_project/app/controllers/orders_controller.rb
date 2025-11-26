# frozen_string_literal: true

module DemoApp
  module Controllers
    class OrdersController
      def initialize(repo:)
        @repo = repo
      end

      def index
        @repo.all
      end

      def show(id)
        @repo.find(id)
      end

      def cancel(id)
        order = @repo.find(id)
        return :missing unless order

        @repo.cancel(id)
      end
    end
  end
end
