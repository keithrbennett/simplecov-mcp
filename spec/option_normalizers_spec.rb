# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CovLoupe::OptionNormalizers do
  describe '.normalize_sort_order' do
    context 'with strict mode (default)' do
      [
        ['a', :ascending],
        ['ascending', :ascending],
        ['d', :descending],
        ['descending', :descending],
        ['ASCENDING', :ascending],
        ['Descending', :descending]
      ].each do |input, expected|
        it "normalizes '#{input}' to #{expected}" do
          expect(described_class.normalize_sort_order(input)).to eq(expected)
        end
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
      [nil, ''].each do |input|
        it "raises OptionParser::InvalidArgument for #{input.inspect}" do
          expect { described_class.normalize_source_mode(input) }
            .to raise_error(OptionParser::InvalidArgument, /invalid argument/)
        end
      end

      [
        ['f', :full],
        ['full', :full],
        ['u', :uncovered],
        ['uncovered', :uncovered],
        ['FULL', :full],
        ['Uncovered', :uncovered]
      ].each do |input, expected|
        it "normalizes '#{input}' to #{expected}" do
          expect(described_class.normalize_source_mode(input)).to eq(expected)
        end
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

  describe '.normalize_error_mode' do
    context 'with strict mode (default)' do
      [
        ['off', :off],
        ['o', :off],
        ['log', :log],
        ['l', :log],
        ['debug', :debug],
        ['d', :debug],
        ['OFF', :off],
        ['Log', :log],
        ['DEBUG', :debug]
      ].each do |input, expected|
        it "normalizes '#{input}' to #{expected}" do
          expect(described_class.normalize_error_mode(input)).to eq(expected)
        end
      end

      ['invalid', 'on', 'trace'].each do |input|
        it "raises OptionParser::InvalidArgument for '#{input}'" do
          expect { described_class.normalize_error_mode(input) }
            .to raise_error(OptionParser::InvalidArgument, /invalid argument: #{input}/)
        end
      end
    end

    context 'with strict: false and default: :log' do
      [['invalid', :log], [nil, :log]].each do |input, expected|
        it "returns default #{expected} for #{input.inspect}" do
          expect(described_class.normalize_error_mode(input, strict: false,
            default: :log)).to eq(expected)
        end
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

  describe '.normalize_format' do
    context 'with strict mode (default)' do
      [
        ['t', :table],
        ['table', :table],
        ['j', :json],
        ['json', :json],
        ['pretty_json', :pretty_json],
        ['pretty-json', :pretty_json],
        ['y', :yaml],
        ['yaml', :yaml],
        ['a', :awesome_print],
        ['awesome_print', :awesome_print],
        ['ap', :awesome_print],
        ['TABLE', :table],
        ['Json', :json]
      ].each do |input, expected|
        it "normalizes '#{input}' to #{expected}" do
          expect(described_class.normalize_format(input)).to eq(expected)
        end
      end

      it 'raises OptionParser::InvalidArgument for invalid values' do
        expect { described_class.normalize_format('invalid') }
          .to raise_error(OptionParser::InvalidArgument, /invalid argument: invalid/)
      end
    end

    context 'with strict: false' do
      it 'returns nil for invalid values' do
        expect(described_class.normalize_format('invalid', strict: false)).to be_nil
      end

      it 'still normalizes valid values' do
        expect(described_class.normalize_format('json', strict: false)).to eq(:json)
      end
    end
  end

  describe 'constant maps' do
    [:SORT_ORDER_MAP, :SOURCE_MODE_MAP, :ERROR_MODE_MAP,
     :FORMAT_MAP].each do |const|
      it "has frozen #{const}" do
        expect(described_class.const_get(const)).to be_frozen
      end
    end
  end
end
