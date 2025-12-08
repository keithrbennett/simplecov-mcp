# frozen_string_literal: true

require 'json'

module CovLoupe
  module Formatters
    # Maps format symbols to their formatter lambdas
    # Following the rexe pattern for simple, extensible formatting
    FORMATTERS = {
      table: ->(obj) { obj }, # Pass through - table formatting handled elsewhere
      json: lambda(&:to_json),
      pretty_json: ->(obj) { JSON.pretty_generate(obj) },
      yaml: ->(obj) {
        require 'yaml'
        obj.to_yaml
      },
      awesome_print: ->(obj) {
        require 'awesome_print'
        obj.ai
      }
    }.freeze

    # Maps format symbols to their required libraries
    # Only loaded when the format is actually used
    FORMAT_REQUIRES = {
      yaml: 'yaml',
      awesome_print: 'awesome_print'
    }.freeze

    # Returns the formatter lambda for the given format
    def self.formatter_for(format)
      FORMATTERS[format] or raise ArgumentError, "Unknown format: #{format}"
    end

    # Ensures required libraries are loaded for the given format
    def self.ensure_requirements_for(format)
      requirement = FORMAT_REQUIRES[format]
      require requirement if requirement
    end

    # Formats an object using the specified format
    def self.format(obj, format)
      ensure_requirements_for(format)
      formatter_for(format).call(obj)
    rescue LoadError => e
      gem_name = e.message[/-- (\S+)/, 1] || 'required gem'
      raise LoadError, "The #{format} format requires the '#{gem_name}' gem. " \
                       "Install it with: gem install #{gem_name}"
    end
  end
end
