# frozen_string_literal: true

module SimpleCovMcp
  # Shared normalization logic for CLI options.
  # Provides both strict (raise on invalid) and lenient (default on invalid) modes.
  module OptionNormalizers
    SORT_ORDER_MAP = {
      'a'          => :ascending,
      'ascending'  => :ascending,
      'd'          => :descending,
      'descending' => :descending
    }.freeze

    SOURCE_MODE_MAP = {
      'f'         => :full,
      'full'      => :full,
      'u'         => :uncovered,
      'uncovered' => :uncovered
    }.freeze

    STALE_MODE_MAP = {
      'o'     => :off,
      'off'   => :off,
      'e'     => :error,
      'error' => :error
    }.freeze

    ERROR_MODE_MAP = {
      'off'   => :off,
      'on'    => :on,
      't'     => :trace,
      'trace' => :trace
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
      return :full if value.nil? || value == ''
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
    def normalize_stale_mode(value, strict: true)
      normalized = STALE_MODE_MAP[value.to_s.downcase]
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
    def normalize_error_mode(value, strict: true, default: :on)
      normalized = ERROR_MODE_MAP[value&.downcase]
      return normalized if normalized
      raise OptionParser::InvalidArgument, "invalid argument: #{value}" if strict
      default
    end
  end
end
