# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CovLoupe::StaleStatus do
  describe '.stale?' do
    it 'returns false for ok status' do
      expect(described_class.stale?('ok')).to be(false)
    end

    it 'returns true for stale statuses' do
      %w[missing newer length_mismatch error].each do |status|
        expect(described_class.stale?(status)).to be(true)
      end
    end

    it 'raises when status is missing' do
      expect { described_class.stale?(nil) }
        .to raise_error(ArgumentError, /Stale status is missing/)
    end

    it 'raises when status is not a string' do
      expect { described_class.stale?(:ok) }
        .to raise_error(ArgumentError, /Stale status must be a String/)
    end

    it 'raises when status is unknown' do
      expect { described_class.stale?('stale') }
        .to raise_error(ArgumentError, /Unknown stale status/)
    end
  end
end
