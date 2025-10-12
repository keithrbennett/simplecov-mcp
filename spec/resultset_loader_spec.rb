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
end
