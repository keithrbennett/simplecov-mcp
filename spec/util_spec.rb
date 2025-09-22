# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::CovUtil do
  let(:root) { (FIXTURES / 'project1').to_s }
  let(:resultset_file) { File.join(root, 'coverage', '.resultset.json') }

  it 'latest_timestamp returns integer from fixture' do
    ts = described_class.latest_timestamp(root, resultset: 'coverage')
    expect(ts).to be_a(Integer)
    expect(ts).to eq(FIXTURE_COVERAGE_TIMESTAMP)
  end

  it 'find_resultset honors SIMPLECOV_RESULTSET file path' do
    begin
      ENV['SIMPLECOV_RESULTSET'] = resultset_file
      path = described_class.find_resultset(root)
      expect(path).to eq(File.absolute_path(resultset_file, root))
    ensure
      ENV.delete('SIMPLECOV_RESULTSET')
    end
  end

  it 'lookup_lines supports cwd-stripping and basename fallbacks' do
    lines = [1, 0]

    # Exact key
    cov = { '/abs/path/foo.rb' => { 'lines' => lines } }
    expect(described_class.lookup_lines(cov, '/abs/path/foo.rb')).to eq(lines)

    # CWD strip fallback
    begin
      allow(Dir).to receive(:pwd).and_return('/cwd')
      cov = { 'sub/foo.rb' => { 'lines' => lines } }
      expect(described_class.lookup_lines(cov, '/cwd/sub/foo.rb')).to eq(lines)
    ensure
      # no-op
    end

    # Basename fallback
    cov = { '/some/where/else/foo.rb' => { 'lines' => lines } }
    expect(described_class.lookup_lines(cov, '/another/place/foo.rb')).to eq(lines)

    # Missing raises a helpful string error
    cov = {}
    expect {
      described_class.lookup_lines(cov, '/nowhere/foo.rb')
    }.to raise_error(RuntimeError, /No coverage entry found/)
  end

  it 'summary handles edge cases and coercion' do
    expect(described_class.summary([])).to include('pct' => 100.0, 'total' => 0, 'covered' => 0)
    expect(described_class.summary([nil, nil])).to include('pct' => 100.0, 'total' => 0, 'covered' => 0)
    expect(described_class.summary(['1', '0', nil])).to include('pct' => 50.0, 'total' => 2, 'covered' => 1)
  end

  it 'uncovered and detailed ignore nils' do
    arr = [1, 0, nil, 2]
    expect(described_class.uncovered(arr)).to eq([2])
    expect(described_class.detailed(arr)).to eq([
      { 'line' => 1, 'hits' => 1, 'covered' => true },
      { 'line' => 2, 'hits' => 0, 'covered' => false },
      { 'line' => 4, 'hits' => 2, 'covered' => true }
    ])
  end

  it 'load_latest_coverage raises CoverageDataError on invalid JSON via model' do
    Dir.mktmpdir do |dir|
      bad = File.join(dir, '.resultset.json')
      File.write(bad, '{not-json')
      expect {
        SimpleCovMcp::CoverageModel.new(root: root, resultset: dir)
      }.to raise_error(SimpleCovMcp::CoverageDataError, /Invalid coverage data format/)
    end
  end
end

