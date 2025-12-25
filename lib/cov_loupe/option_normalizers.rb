# frozen_string_literal: true

module CovLoupe
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
      'a' => :amazing_print,
      'awesome_print' => :amazing_print,
      'ap' => :amazing_print,
      'amazing_print' => :amazing_print
    }.freeze

    MODE_MAP = {
      'cli' => :cli,
      'c' => :cli,
      'mcp' => :mcp,
      'm' => :mcp
    }.freeze

    module_function def normalize_sort_order(value, strict: true)
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
    module_function def normalize_source_mode(value, strict: true)
      normalized = SOURCE_MODE_MAP[value.to_s.downcase]
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
    module_function def normalize_error_mode(value, strict: true, default: :log)
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
    module_function def normalize_format(value, strict: true)
      normalized = FORMAT_MAP[value.to_s.downcase]
      return normalized if normalized

      raise OptionParser::InvalidArgument, "invalid argument: #{value}" if strict

      nil
    end

    # Normalize mode value (cli or mcp).
    # @param value [String, Symbol] The value to normalize
    # @param strict [Boolean] If true, raises on invalid value; if false, returns default
    # @param default [Symbol] The default value to return if invalid and not strict
    # @return [Symbol] The normalized symbol (:cli or :mcp)
    # @raise [OptionParser::InvalidArgument] If strict and value is invalid
    module_function def normalize_mode(value, strict: true, default: :cli)
      normalized = MODE_MAP[value.to_s.downcase]
      return normalized if normalized

      raise OptionParser::InvalidArgument, "invalid argument: #{value}" if strict

      default
    end
  end
end
