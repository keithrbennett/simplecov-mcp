# frozen_string_literal: true

module DemoApp
  module Models
    class User
      def initialize(attrs = {})
        @attrs = attrs
      end

      def admin?
        @attrs.fetch(:role, 'user') == 'admin'
      end

      def active?
        @attrs.fetch(:status, 'active') == 'active'
      end
    end
  end
end
