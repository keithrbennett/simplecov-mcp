# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CovLoupe::Formatters do
  describe '.formatter_for' do
    it 'returns a lambda for known format' do
      expect(described_class.formatter_for(:json)).to respond_to(:call)
    end

    it 'raises ArgumentError for unknown format' do
      expect { described_class.formatter_for(:unknown) }
        .to raise_error(ArgumentError, /Unknown format: unknown/)
    end
  end

  describe '.ensure_requirements_for' do
    it 'requires the library if needed' do
      # We rely on the fact that 'yaml' is in FORMAT_REQUIRES
      expect(described_class).to receive(:require).with('yaml')
      described_class.ensure_requirements_for(:yaml)
    end

    it 'does nothing if no requirement' do
      expect(described_class).not_to receive(:require)
      described_class.ensure_requirements_for(:json) # JSON already required by app
    end
  end

  describe '.format' do
    let(:obj) { { 'foo' => 'bar' } }

    [
      [:json, '{"foo":"bar"}', :eq],
      [:pretty_json, "{\n  \"foo\": \"bar\"\n}", :include],
      [:table, { 'foo' => 'bar' }, :eq],
      [:yaml, "---\nfoo: bar\n", :include]
    ].each do |format, expected, matcher|
      it "formats as #{format}" do
        result = described_class.format(obj, format)
        expect(result).to send(matcher, expected)
      end
    end

    context 'when a required gem is missing' do
      before do
        error = LoadError.new('cannot load such file -- awesome_print')
        allow(described_class).to receive(:require).with('awesome_print').and_raise(error)
      end

      it 'raises a helpful LoadError' do
        expect { described_class.format(obj, :awesome_print) }
          .to raise_error(LoadError, /requires the 'awesome_print' gem/)
      end
    end

    context 'when awesome_print is available' do
      before do
        # Stub require on the module for ensure_requirements_for
        allow(described_class).to receive(:require).with('awesome_print')

        # Stub global require for the lambda's internal require
        allow(Kernel).to receive(:require).and_call_original
        allow(Kernel).to receive(:require).with('awesome_print').and_return(true)

        # Mock .ai on the object
        allow(obj).to receive(:ai).and_return('awesome output')
      end

      it 'formats using awesome_print' do
        result = described_class.format(obj, :awesome_print)
        expect(result).to eq('awesome output')
      end
    end
  end
end
