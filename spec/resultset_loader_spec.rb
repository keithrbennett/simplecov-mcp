# frozen_string_literal: true

require 'json'
require 'tmpdir'

RSpec.describe SimpleCovMcp::ResultsetLoader do
  describe '.load' do
    it 'parses a single suite and returns coverage map and timestamp' do
      Dir.mktmpdir do |dir|
        resultset_path = File.join(dir, '.resultset.json')
        coverage = {
          File.join(dir, 'lib', 'foo.rb') => { 'lines' => [1, 0, nil, 2] }
        }
        data = {
          'SuiteA' => {
            'timestamp' => 123,
            'coverage' => coverage
          }
        }
        File.write(resultset_path, JSON.generate(data))

        result = described_class.load(resultset_path: resultset_path)

        expect(result.coverage_map).to eq(coverage)
        expect(result.timestamp).to eq(123)
        expect(result.suite_names).to eq(['SuiteA'])
      end
    end

    it 'merges multiple suites and combines coverage' do
      Dir.mktmpdir do |dir|
        resultset_path = File.join(dir, '.resultset.json')
        foo_path = File.join(dir, 'lib', 'foo.rb')
        bar_path = File.join(dir, 'lib', 'bar.rb')

        data = {
          'RSpec' => {
            'timestamp' => 100,
            'coverage' => {
              foo_path => { 'lines' => [1, 0, nil, 0] }
            }
          },
          'Cucumber' => {
            'timestamp' => 200,
            'coverage' => {
              foo_path => { 'lines' => [0, 3, nil, 1] },
              bar_path => { 'lines' => [0, 1, 1] }
            }
          }
        }
        File.write(resultset_path, JSON.generate(data))

        result = described_class.load(resultset_path: resultset_path)
        expect(result.coverage_map[foo_path]['lines']).to eq([1, 3, nil, 1])
        expect(result.coverage_map[bar_path]['lines']).to eq([0, 1, 1])
        expect(result.timestamp).to eq(200)
        expect(result.suite_names).to contain_exactly('RSpec', 'Cucumber')
      end
    end

    it 'adapts legacy array coverage entries' do
      Dir.mktmpdir do |dir|
        resultset_path = File.join(dir, '.resultset.json')
        foo_path = File.join(dir, 'lib', 'foo.rb')
        data = {
          'SuiteA' => {
            'timestamp' => 50,
            'coverage' => {
              foo_path => [1, 0, nil, 2]
            }
          }
        }
        File.write(resultset_path, JSON.generate(data))

        result = described_class.load(resultset_path: resultset_path)
        expect(result.coverage_map[foo_path]).to eq('lines' => [1, 0, nil, 2])
      end
    end

    it 'raises CoverageDataError when no suites are present' do
      Dir.mktmpdir do |dir|
        resultset_path = File.join(dir, '.resultset.json')
        File.write(resultset_path, '{}')

        expect {
          described_class.load(resultset_path: resultset_path)
        }.to raise_error(SimpleCovMcp::CoverageDataError, /No test suite/)
      end
    end
  end

  describe 'SimpleCov loading and logging' do
    it 'raises CoverageDataError when SimpleCov cannot be required' do
      singleton = class << described_class; self; end
      singleton.send(:define_method, :require) do |name|
        raise LoadError if name == 'simplecov'
        Kernel.require(name)
      end

      expect {
        described_class.send(:require_simplecov_for_merge!, '/tmp/resultset.json')
      }.to raise_error(SimpleCovMcp::CoverageDataError, /Install simplecov/)
    ensure
      if singleton.method_defined?(:require)
        singleton.send(:remove_method, :require)
      end
    end

    it 'logs duplicate suite names when merging coverage' do
      suites = [
        described_class::SuiteEntry.new(name: 'RSpec', coverage: {}, timestamp: 0),
        described_class::SuiteEntry.new(name: 'RSpec', coverage: {}, timestamp: 0),
        described_class::SuiteEntry.new(name: 'Cucumber', coverage: {}, timestamp: 0)
      ]

      expect(SimpleCovMcp::CovUtil).to receive(:log).with(include('Merging duplicate coverage suites for RSpec'))
      described_class.send(:log_duplicate_suite_names, suites)
    end
  end

  describe 'timestamp normalization' do
    it 'handles float timestamps' do
      value = described_class.send(:normalize_coverage_timestamp, 123.9, nil)
      expect(value).to eq(123)
    end

    it 'handles Time objects' do
      time = Time.at(456)
      value = described_class.send(:normalize_coverage_timestamp, time, nil)
      expect(value).to eq(456)
    end

    it 'parses numeric string timestamps' do
      value = described_class.send(:normalize_coverage_timestamp, '789.42', nil)
      expect(value).to eq(789)
    end

    it 'falls back to created_at when timestamp missing' do
      value = described_class.send(:normalize_coverage_timestamp, nil, 321)
      expect(value).to eq(321)
    end

    it 'logs warning and returns zero for invalid timestamp strings' do
      messages = []
      allow(SimpleCovMcp::CovUtil).to receive(:log) { |msg| messages << msg }

      value = described_class.send(:normalize_coverage_timestamp, 'not-a-timestamp', nil)

      expect(value).to eq(0)
      expect(messages.join).to include('Coverage resultset timestamp could not be parsed')
      expect(messages.join).to include('not-a-timestamp')
    end

    it 'logs warning and returns zero for unsupported types' do
      messages = []
      allow(SimpleCovMcp::CovUtil).to receive(:log) { |msg| messages << msg }

      value = described_class.send(:normalize_coverage_timestamp, [:invalid], nil)

      expect(value).to eq(0)
      expect(messages.join).to include('Coverage resultset timestamp could not be parsed')
      expect(messages.join).to include('[:invalid]')
    end
  end
end
