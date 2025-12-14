# frozen_string_literal: true

# rubocop:disable Style/CaseEquality

require 'spec_helper'
require 'cov_loupe/boolean_type'

RSpec.describe CovLoupe::BooleanType do
  describe 'Constants' do
    it 'display string includes all valid values' do
      display_values = described_class::BOOLEAN_VALUES_DISPLAY_STRING.split('/')
      expect(display_values).to match_array(described_class::VALID_VALUES)
    end
  end

  describe '.parse' do
    it 'raises a helpful error for invalid values' do
      expect do
        described_class.parse('maybe')
      end.to raise_error(ArgumentError) do |error|
        expect(error.message).to include('invalid boolean value: "maybe"')
        expect(error.message).to include(described_class::VALID_VALUES.join(', '))
      end
    end
  end

  describe '.===' do
    it 'returns true for "true" values' do
      expect(described_class === 'yes').to be(true)
      expect(described_class === 'true').to be(true)
      expect(described_class === '1').to be(true)
    end

    it 'returns true for "false" values' do
      # This is the bug: it currently returns the *parsed value* (false),
      # but OptionParser expects true to indicate "match found".
      expect(described_class === 'no').to be(true)
      expect(described_class === 'false').to be(true)
      expect(described_class === '0').to be(true)
    end

    it 'returns nil for invalid values' do
      expect(described_class === 'foo').to be_nil
    end

    it 'returns true for nil (optional argument missing)' do
      # rubocop:disable Style/NilComparison
      expect(described_class === nil).to be(true)
      # rubocop:enable Style/NilComparison
    end
  end
end

# rubocop:enable Style/CaseEquality
