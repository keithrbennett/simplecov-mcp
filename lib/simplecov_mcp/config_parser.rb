# frozen_string_literal: true

require_relative 'app_config'
require_relative 'option_parser_builder'

module SimpleCovMcp
  # Centralized configuration parser for both CLI and MCP modes
  # Parses argv (which should already include environment options merged by caller)
  class ConfigParser
    attr_reader :config, :argv

    def initialize(argv)
      @argv = argv
      @config = AppConfig.new
    end

    # Parse argv (with env opts already merged) and return config
    # @param argv [Array<String>] command-line arguments (should include env opts if needed)
    # @return [AppConfig] populated configuration object
    def self.parse(argv)
      new(argv).parse
    end

    def parse
      # Build and execute the option parser
      parser = OptionParserBuilder.new(config).build_option_parser
      parser.parse!(argv)

      config
    rescue OptionParser::ParseError => e
      # Re-raise with original error for caller to handle
      raise e
    end
  end
end
