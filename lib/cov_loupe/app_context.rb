# frozen_string_literal: true

module CovLoupe
  # Encapsulates per-request configuration such as error handling and logging.
  class AppContext
    attr_reader :error_handler, :log_target, :mode

    def initialize(error_handler:, log_target: nil, mode: :library)
      @error_handler = error_handler
      @log_target = log_target
      @mode = mode
    end

    def with_error_handler(handler)
      self.class.new(error_handler: handler, log_target: log_target, mode: mode)
    end

    def with_log_target(target)
      self.class.new(error_handler: error_handler, log_target: target, mode: mode)
    end

    def mcp_mode? = mode == :mcp
    def cli_mode? = mode == :cli
    def library_mode? = mode == :library
  end
end
