# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::OptionNormalizers do
  describe '.normalize_sort_order' do
    context 'with strict mode (default)' do
      it 'normalizes "a" to :ascending' do
        expect(described_class.normalize_sort_order('a')).to eq(:ascending)
      end

      it 'normalizes "ascending" to :ascending' do
        expect(described_class.normalize_sort_order('ascending')).to eq(:ascending)
      end

      it 'normalizes "d" to :descending' do
        expect(described_class.normalize_sort_order('d')).to eq(:descending)
      end

      it 'normalizes "descending" to :descending' do
        expect(described_class.normalize_sort_order('descending')).to eq(:descending)
      end

      it 'is case-insensitive' do
        expect(described_class.normalize_sort_order('ASCENDING')).to eq(:ascending)
        expect(described_class.normalize_sort_order('Descending')).to eq(:descending)
      end

      it 'raises OptionParser::InvalidArgument for invalid values' do
        expect { described_class.normalize_sort_order('invalid') }
          .to raise_error(OptionParser::InvalidArgument, /invalid argument: invalid/)
      end
    end

    context 'with strict: false' do
      it 'returns nil for invalid values' do
        expect(described_class.normalize_sort_order('invalid', strict: false)).to be_nil
      end

      it 'still normalizes valid values' do
        expect(described_class.normalize_sort_order('a', strict: false)).to eq(:ascending)
      end
    end
  end

  describe '.normalize_source_mode' do
    context 'with strict mode (default)' do
      it 'normalizes nil to :full' do
        expect(described_class.normalize_source_mode(nil)).to eq(:full)
      end

      it 'normalizes empty string to :full' do
        expect(described_class.normalize_source_mode('')).to eq(:full)
      end

      it 'normalizes "f" to :full' do
        expect(described_class.normalize_source_mode('f')).to eq(:full)
      end

      it 'normalizes "full" to :full' do
        expect(described_class.normalize_source_mode('full')).to eq(:full)
      end

      it 'normalizes "u" to :uncovered' do
        expect(described_class.normalize_source_mode('u')).to eq(:uncovered)
      end

      it 'normalizes "uncovered" to :uncovered' do
        expect(described_class.normalize_source_mode('uncovered')).to eq(:uncovered)
      end

      it 'is case-insensitive' do
        expect(described_class.normalize_source_mode('FULL')).to eq(:full)
        expect(described_class.normalize_source_mode('Uncovered')).to eq(:uncovered)
      end

      it 'raises OptionParser::InvalidArgument for invalid values' do
        expect { described_class.normalize_source_mode('invalid') }
          .to raise_error(OptionParser::InvalidArgument, /invalid argument: invalid/)
      end
    end

    context 'with strict: false' do
      it 'returns nil for invalid values' do
        expect(described_class.normalize_source_mode('invalid', strict: false)).to be_nil
      end

      it 'still normalizes valid values' do
        expect(described_class.normalize_source_mode('u', strict: false)).to eq(:uncovered)
      end
    end
  end

  describe '.normalize_stale_mode' do
    context 'with strict mode (default)' do
      it 'normalizes "o" to :off' do
        expect(described_class.normalize_stale_mode('o')).to eq(:off)
      end

      it 'normalizes "off" to :off' do
        expect(described_class.normalize_stale_mode('off')).to eq(:off)
      end

      it 'normalizes "e" to :error' do
        expect(described_class.normalize_stale_mode('e')).to eq(:error)
      end

      it 'normalizes "error" to :error' do
        expect(described_class.normalize_stale_mode('error')).to eq(:error)
      end

      it 'is case-insensitive' do
        expect(described_class.normalize_stale_mode('OFF')).to eq(:off)
        expect(described_class.normalize_stale_mode('Error')).to eq(:error)
      end

      it 'raises OptionParser::InvalidArgument for invalid values' do
        expect { described_class.normalize_stale_mode('invalid') }
          .to raise_error(OptionParser::InvalidArgument, /invalid argument: invalid/)
      end
    end

    context 'with strict: false' do
      it 'returns nil for invalid values' do
        expect(described_class.normalize_stale_mode('invalid', strict: false)).to be_nil
      end

      it 'still normalizes valid values' do
        expect(described_class.normalize_stale_mode('e', strict: false)).to eq(:error)
      end
    end
  end

  describe '.normalize_error_mode' do
    context 'with strict mode (default)' do
      it 'normalizes "off" to :off' do
        expect(described_class.normalize_error_mode('off')).to eq(:off)
      end

      it 'normalizes "on" to :on' do
        expect(described_class.normalize_error_mode('on')).to eq(:on)
      end

      it 'normalizes "trace" to :trace' do
        expect(described_class.normalize_error_mode('trace')).to eq(:trace)
      end

      it 'normalizes "t" to :trace' do
        expect(described_class.normalize_error_mode('t')).to eq(:trace)
      end

      it 'is case-insensitive' do
        expect(described_class.normalize_error_mode('OFF')).to eq(:off)
        expect(described_class.normalize_error_mode('On')).to eq(:on)
        expect(described_class.normalize_error_mode('TRACE')).to eq(:trace)
      end

      it 'raises OptionParser::InvalidArgument for invalid values' do
        expect { described_class.normalize_error_mode('invalid') }
          .to raise_error(OptionParser::InvalidArgument, /invalid argument: invalid/)
      end
    end

    context 'with strict: false and default: :on' do
      it 'returns default for invalid values' do
        expect(described_class.normalize_error_mode('invalid', strict: false, 
          default: :on)).to eq(:on)
      end

      it 'returns default for nil' do
        expect(described_class.normalize_error_mode(nil, strict: false, default: :on)).to eq(:on)
      end

      it 'still normalizes valid values' do
        expect(described_class.normalize_error_mode('off', strict: false)).to eq(:off)
      end
    end

    context 'with custom default' do
      it 'returns custom default for invalid values when not strict' do
        expect(described_class.normalize_error_mode('invalid', strict: false, 
          default: :off)).to eq(:off)
      end
    end
  end

  describe 'constant maps' do
    it 'has frozen SORT_ORDER_MAP' do
      expect(described_class::SORT_ORDER_MAP).to be_frozen
    end

    it 'has frozen SOURCE_MODE_MAP' do
      expect(described_class::SOURCE_MODE_MAP).to be_frozen
    end

    it 'has frozen STALE_MODE_MAP' do
      expect(described_class::STALE_MODE_MAP).to be_frozen
    end

    it 'has frozen ERROR_MODE_MAP' do
      expect(described_class::ERROR_MODE_MAP).to be_frozen
    end
  end
end
