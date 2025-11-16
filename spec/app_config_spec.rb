# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::AppConfig do
  describe '#initialize' do
    it 'creates a config with default values' do
      config = described_class.new
      expect(config.root).to eq('.')
      expect(config.json).to be false
      expect(config.sort_order).to eq(:ascending)
      expect(config.source_context).to eq(2)
      expect(config.error_mode).to eq(:on)
      expect(config.stale_mode).to eq(:off)
      expect(config.resultset).to be_nil
      expect(config.source_mode).to be_nil
      expect(config.tracked_globs).to be_nil
      expect(config.log_file).to be_nil
      expect(config.success_predicate).to be_nil
    end

    it 'allows overriding defaults via keyword arguments' do
      config = described_class.new(
        root: '/custom',
        json: true,
        sort_order: :descending,
        stale_mode: :error
      )
      expect(config.root).to eq('/custom')
      expect(config.json).to be true
      expect(config.sort_order).to eq(:descending)
      expect(config.stale_mode).to eq(:error)
    end

    it 'is mutable (struct fields can be changed)' do
      config = described_class.new
      config.root = '/new/root'
      config.json = true
      expect(config.root).to eq('/new/root')
      expect(config.json).to be true
    end
  end

  describe '#model_options' do
    it 'returns hash suitable for CoverageModel.new' do
      config = described_class.new(
        root: '/custom/root',
        resultset: '/custom/.resultset.json',
        stale_mode: :error,
        tracked_globs: ['lib/**/*.rb']
      )

      options = config.model_options
      expect(options).to eq({
        root: '/custom/root',
        resultset: '/custom/.resultset.json',
        staleness: :error,
        tracked_globs: ['lib/**/*.rb']
      })
    end

    it 'handles nil values correctly' do
      config = described_class.new
      options = config.model_options
      expect(options[:root]).to eq('.')
      expect(options[:resultset]).to be_nil
      expect(options[:staleness]).to eq(:off)
      expect(options[:tracked_globs]).to be_nil
    end
  end

  describe '#formatter_options' do
    it 'returns hash suitable for SourceFormatter.new' do
      config = described_class.new(color: true)
      options = config.formatter_options
      expect(options).to eq({ color_enabled: true })
    end

    it 'handles false color setting' do
      config = described_class.new(color: false)
      options = config.formatter_options
      expect(options).to eq({ color_enabled: false })
    end
  end

  describe 'struct behavior' do
    it 'supports equality comparison' do
      config1 = described_class.new(root: '/foo', json: true)
      config2 = described_class.new(root: '/foo', json: true)
      config3 = described_class.new(root: '/bar', json: true)

      expect(config1).to eq(config2)
      expect(config1).not_to eq(config3)
    end

    it 'provides readable inspect output' do
      config = described_class.new(root: '/test', json: true)
      output = config.inspect
      expect(output).to include('root="/test"')
      expect(output).to include('json=true')
    end

    it 'converts to hash' do
      config = described_class.new(root: '/test', json: true)
      hash = config.to_h
      expect(hash).to be_a(Hash)
      expect(hash[:root]).to eq('/test')
      expect(hash[:json]).to be true
    end
  end

  describe 'symbol enumerated values' do
    it 'uses symbols for sort_order' do
      config = described_class.new(sort_order: :descending)
      expect(config.sort_order).to eq(:descending)
      expect(config.sort_order).to be_a(Symbol)
    end

    it 'uses symbols for stale_mode' do
      config = described_class.new(stale_mode: :error)
      expect(config.stale_mode).to eq(:error)
      expect(config.stale_mode).to be_a(Symbol)
    end

    it 'uses symbols for error_mode' do
      config = described_class.new(error_mode: :trace)
      expect(config.error_mode).to eq(:trace)
      expect(config.error_mode).to be_a(Symbol)
    end

    it 'uses symbols for source_mode' do
      config = described_class.new(source_mode: :uncovered)
      expect(config.source_mode).to eq(:uncovered)
      expect(config.source_mode).to be_a(Symbol)
    end
  end
end
