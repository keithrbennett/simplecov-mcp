# frozen_string_literal: true

module SimpleCovMcp
  # Shared normalization logic for CLI options.
  # Provides both strict (raise on invalid) and lenient (default on invalid) modes.
  module OptionNormalizers
    SORT_ORDER_MAP = {
      'a' => :ascending,
      'ascending' => :ascending,
      'd' => :descending,
      'descending' => :descending
    }.freeze

    SOURCE_MODE_MAP = {
      'f' => :full,
      'full' => :full,
      'u' => :uncovered,
      'uncovered' => :uncovered
    }.freeze

    STALENESS_MAP = {
      'o' => :off,
      'off' => :off,
      'e' => :error,
      'error' => :error
    }.freeze

    ERROR_MODE_MAP = {
      'off' => :off,
      'o' => :off,
      'log' => :log,
      'l' => :log,
      'debug' => :debug,
      'd' => :debug
    }.freeze

    FORMAT_MAP = {
      't' => :table,
      'table' => :table,
      'j' => :json,
      'json' => :json,
      'J' => :pretty_json,
      'pretty_json' => :pretty_json,
      'pretty-json' => :pretty_json,
      'y' => :yaml,
      'yaml' => :yaml,
      'a' => :awesome_print,
      'awesome_print' => :awesome_print,
      'ap' => :awesome_print
    }.freeze

    module_function

    # Normalize sort order value.
    # @param value [String, Symbol] The value to normalize
    # @param strict [Boolean] If true, raises on invalid value; if false, returns nil
    # @return [Symbol, nil] The normalized symbol or nil if invalid and not strict
    # @raise [OptionParser::InvalidArgument] If strict and value is invalid
    def normalize_sort_order(value, strict: true)
      normalized = SORT_ORDER_MAP[value.to_s.downcase]
      return normalized if normalized
      raise OptionParser::InvalidArgument, "invalid argument: #{value}" if strict

      nil
    end

    # Normalize source mode value.
    # @param value [String, Symbol, nil] The value to normalize
    # @param strict [Boolean] If true, raises on invalid value; if false, returns nil
    # @return [Symbol, nil] The normalized symbol or nil if invalid and not strict
    # @raise [OptionParser::InvalidArgument] If strict and value is invalid
    def normalize_source_mode(value, strict: true)
      normalized = SOURCE_MODE_MAP[value.to_s.downcase]
      return normalized if normalized
      raise OptionParser::InvalidArgument, "invalid argument: #{value}" if strict

      nil
    end

    # Normalize stale mode value.
    # @param value [String, Symbol] The value to normalize
    # @param strict [Boolean] If true, raises on invalid value; if false, returns nil
    # @return [Symbol, nil] The normalized symbol or nil if invalid and not strict
    # @raise [OptionParser::InvalidArgument] If strict and value is invalid
    def normalize_staleness(value, strict: true)
      normalized = STALENESS_MAP[value.to_s.downcase]
      return normalized if normalized
      raise OptionParser::InvalidArgument, "invalid argument: #{value}" if strict

      nil
    end

    # Normalize error mode value.
    # @param value [String, Symbol, nil] The value to normalize
    # @param strict [Boolean] If true, raises on invalid value; if false, returns default
    # @param default [Symbol] The default value to return if invalid and not strict
    # @return [Symbol] The normalized symbol or default if invalid and not strict
    # @raise [OptionParser::InvalidArgument] If strict and value is invalid
    def normalize_error_mode(value, strict: true, default: :log)
      normalized = ERROR_MODE_MAP[value.to_s.downcase]
      return normalized if normalized
      raise OptionParser::InvalidArgument, "invalid argument: #{value}" if strict

      default
    end

    # Normalize format value.
    # @param value [String, Symbol] The value to normalize
    # @param strict [Boolean] If true, raises on invalid value; if false, returns nil
    # @return [Symbol, nil] The normalized symbol or nil if invalid and not strict
    # @raise [OptionParser::InvalidArgument] If strict and value is invalid
    def normalize_format(value, strict: true)
      normalized = FORMAT_MAP[value.to_s.downcase]
      return normalized if normalized
      raise OptionParser::InvalidArgument, "invalid argument: #{value}" if strict

      nil
    end
  end
end
