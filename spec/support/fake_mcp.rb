# frozen_string_literal: true

module FakeMCP
  # Fake server captures the last created instance so we can assert on the
  # name/version/tools passed in by CovLoupe::MCPServer.
  class Server
    class << self
      attr_accessor :last_instance
    end
    attr_reader :params

    def initialize(name:, version:, tools:)
      @params = { name: name, version: version, tools: tools }
      self.class.last_instance = self
    end
  end

  # Fake stdio transport records whether `open` was called and the server
  # it was initialized with.
  class StdioTransport
    class << self
      attr_accessor :last_instance
    end
    attr_reader :server, :opened

    def initialize(server)
      @server = server
      @opened = false
      self.class.last_instance = self
    end

    def open
      @opened = true
    end

    def opened?
      @opened
    end
  end
end
