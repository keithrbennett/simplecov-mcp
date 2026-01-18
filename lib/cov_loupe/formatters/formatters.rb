# frozen_string_literal: true

require 'json'
require_relative '../output_chars'

module CovLoupe
  module Formatters
    # Maps format symbols to their required libraries
    # Only loaded when the format is actually used
    FORMAT_REQUIRES = {
      yaml: 'yaml',
      amazing_print: 'amazing_print'
    }.freeze

    # Ensures required libraries are loaded for the given format
    def self.ensure_requirements_for(format)
      requirement = FORMAT_REQUIRES[format]
      require requirement if requirement
    end

    # Formats an object using the specified format.
    #
    # @param obj [Object] The object to format
    # @param format [Symbol] Format type (:table, :json, :pretty_json, :yaml, :amazing_print)
    # @param output_chars [Symbol] Output character mode (:default, :fancy, :ascii)
    # @return [String] Formatted output
    def self.format(obj, format, output_chars: :default)
      ensure_requirements_for(format)
      ascii_mode = OutputChars.ascii_mode?(output_chars)

      case format
      when :table
        # Pass through - table formatting handled elsewhere with its own output_chars
        obj
      when :json
        ascii_mode ? JSON.generate(obj, ascii_only: true) : obj.to_json
      when :pretty_json
        ascii_mode ? JSON.pretty_generate(obj, ascii_only: true) : JSON.pretty_generate(obj)
      when :yaml
        format_yaml(obj, ascii_mode: ascii_mode)
      when :amazing_print
        require 'amazing_print'
        result = obj.ai
        # AmazingPrint doesn't have native ASCII mode; convert if needed
        ascii_mode ? OutputChars.convert(result, :ascii) : result
      else
        raise ArgumentError, "Unknown format: #{format}"
      end
    rescue LoadError => e
      gem_name = e.message[/-- (\S+)/, 1] || 'required gem'
      raise LoadError, "The #{format} format requires the '#{gem_name}' gem. " \
                       "Install it with: gem install #{gem_name}"
    end

    # Formats an object as YAML, with optional ASCII-only output.
    #
    # YAML doesn't have a native ASCII-only mode, so for ASCII mode we:
    # 1. Generate standard YAML
    # 2. Convert any non-ASCII characters using OutputChars.convert
    #
    # This approach preserves YAML structure while ensuring ASCII-only output.
    # Note: This may affect string values containing Unicode, but YAML structure
    # (which is ASCII) remains valid.
    #
    # @param obj [Object] The object to format
    # @param ascii_mode [Boolean] If true, ensure ASCII-only output
    # @return [String] YAML-formatted output
    def self.format_yaml(obj, ascii_mode: false)
      require 'yaml'
      yaml = obj.to_yaml
      ascii_mode ? OutputChars.convert(yaml, :ascii) : yaml
    end
    private_class_method :format_yaml
  end
end
