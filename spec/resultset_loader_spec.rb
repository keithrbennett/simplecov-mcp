# frozen_string_literal: true

require 'json'
require 'tmpdir'

RSpec.describe CovLoupe::ResultsetLoader do
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

        expect do
          described_class.load(resultset_path: resultset_path)
        end.to raise_error(CovLoupe::CoverageDataError, /No test suite/)
      end
    end

    it 'raises CoverageDataError when coverage data is not a hash' do
      Dir.mktmpdir do |dir|
        resultset_path = File.join(dir, '.resultset.json')
        data = {
          'SuiteA' => {
            'timestamp' => 10,
            'coverage' => []
          }
        }
        File.write(resultset_path, JSON.generate(data))

        expect do
          described_class.load(resultset_path: resultset_path)
        end.to raise_error(CovLoupe::CoverageDataError, /Invalid coverage data structure/)
      end
    end
  end

  describe 'SimpleCov loading and logging' do
    let(:mock_logger) { instance_double(CovLoupe::Logger, safe_log: nil) }
    let(:loader) { described_class.new(resultset_path: '/tmp/resultset.json', logger: mock_logger) }

    it 'raises CoverageDataError when SimpleCov cannot be required' do
      # We need to mock require on the instance or Kernel, but require is private.
      # The original test mocked it on described_class singleton?
      # Wait, require_simplecov_for_merge! calls `require 'simplecov'`.
      # That's Kernel.require.

      # The previous test did: singleton.send(:define_method, :require) ...
      # But now it's an instance method.

      allow(loader).to receive(:require).with('simplecov').and_raise(LoadError)

      expect do
        loader.send(:require_simplecov_for_merge!)
      end.to raise_error(CovLoupe::CoverageDataError, /Install simplecov/)
    end

    it 'logs duplicate suite names when merging coverage' do
      suites = [
        described_class::SuiteEntry.new(name: 'RSpec', coverage: {}, timestamp: 0),
        described_class::SuiteEntry.new(name: 'RSpec', coverage: {}, timestamp: 0),
        described_class::SuiteEntry.new(name: 'Cucumber', coverage: {}, timestamp: 0)
      ]

      expect(mock_logger).to receive(:safe_log)
        .with(include('Merging duplicate coverage suites for RSpec'))
      loader.send(:log_duplicate_suite_names, suites)
    end
  end

  describe 'timestamp normalization' do
    let(:mock_logger) { instance_double(CovLoupe::Logger, safe_log: nil) }
    let(:loader) { described_class.new(resultset_path: 'dummy', logger: mock_logger) }

    it 'handles float timestamps' do
      value = loader.send(:normalize_coverage_timestamp, 123.9, nil)
      expect(value).to eq(123)
    end

    it 'handles Time objects' do
      time = Time.at(456)
      value = loader.send(:normalize_coverage_timestamp, time, nil)
      expect(value).to eq(456)
    end

    it 'parses numeric string timestamps' do
      value = loader.send(:normalize_coverage_timestamp, '789.42', nil)
      expect(value).to eq(789)
    end

    it 'falls back to created_at when timestamp missing' do
      value = loader.send(:normalize_coverage_timestamp, nil, 321)
      expect(value).to eq(321)
    end

    it 'logs warning and returns zero for invalid timestamp strings' do
      messages = []
      allow(mock_logger).to receive(:safe_log) { |msg| messages << msg }

      value = loader.send(:normalize_coverage_timestamp, 'not-a-timestamp', nil)

      expect(value).to eq(0)
      expect(messages.join).to include('Coverage resultset timestamp could not be parsed')
      expect(messages.join).to include('not-a-timestamp')
    end

    it 'logs warning and returns zero for unsupported types' do
      messages = []
      allow(mock_logger).to receive(:safe_log) { |msg| messages << msg }

      value = loader.send(:normalize_coverage_timestamp, [:invalid], nil)

      expect(value).to eq(0)
      expect(messages.join).to include('Coverage resultset timestamp could not be parsed')
      expect(messages.join).to include('[:invalid]')
    end

    it 'returns zero for blank string timestamps' do
      value = loader.send(:normalize_coverage_timestamp, '   ', nil)
      expect(value).to eq(0)
    end
  end

  describe 'security: json_class protection' do
    it 'does not instantiate arbitrary objects from json_class attributes' do
      Dir.mktmpdir do |dir|
        resultset_path = File.join(dir, '.resultset.json')
        foo_path = File.join(dir, 'lib', 'foo.rb')
        # Create a malicious payload that would execute code if JSON.load_file were used
        # With JSON.parse, json_class is just treated as a regular string key
        malicious_json = <<~JSON
          {
            "RSpec": {
              "json_class": "File",
              "args": ["/etc/passwd"],
              "timestamp": 123,
              "coverage": {
                "#{foo_path}": { "lines": [1, 0] }
              }
            }
          }
        JSON
        File.write(resultset_path, malicious_json)

        # Should parse successfully without instantiating File class
        result = described_class.load(resultset_path: resultset_path)
        expect(result.coverage_map).to be_a(Hash)
        expect(result.coverage_map[foo_path]).to eq('lines' => [1, 0])
        expect(result.suite_names).to eq(['RSpec'])
      end
    end

    it 'treats json_class as ordinary string keys in coverage data' do
      Dir.mktmpdir do |dir|
        resultset_path = File.join(dir, '.resultset.json')
        foo_path = File.join(dir, 'lib', 'foo.rb')
        # Coverage data that includes json_class as a harmless string key
        data = {
          'SuiteA' => {
            'timestamp' => 100,
            'coverage' => {
              foo_path => { 'lines' => [1, 0], 'json_class' => 'IgnoredString' }
            }
          }
        }
        File.write(resultset_path, JSON.generate(data))

        result = described_class.load(resultset_path: resultset_path)
        expect(result.coverage_map[foo_path]['lines']).to eq([1, 0])
        expect(result.coverage_map[foo_path]['json_class']).to eq('IgnoredString')
      end
    end
  end
end
