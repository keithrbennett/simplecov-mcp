# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe CovLoupe::CovUtil do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }
  let(:resultset_file) { File.join(root, 'coverage', '.resultset.json') }



  it 'lookup_lines supports cwd-stripping' do
    lines = [1, 0]

    # Exact key
    cov = { '/abs/path/foo.rb' => { 'lines' => lines } }
    expect(described_class.lookup_lines(cov, '/abs/path/foo.rb')).to eq(lines)

    # CWD strip fallback
    allow(Dir).to receive(:pwd).and_return('/cwd')
    cov = { 'sub/foo.rb' => { 'lines' => lines } }
    expect(described_class.lookup_lines(cov, '/cwd/sub/foo.rb')).to eq(lines)

    # Different paths with same basename should not match
    cov = { '/some/where/else/foo.rb' => { 'lines' => lines } }
    expect do
      described_class.lookup_lines(cov, '/another/place/foo.rb')
    end.to raise_error(CovLoupe::FileError, /No coverage entry found/)

    # Missing raises a FileError
    cov = {}
    expect do
      described_class.lookup_lines(cov, '/nowhere/foo.rb')
    end.to raise_error(CovLoupe::FileError, /No coverage entry found/)
  end

  it 'summary handles edge cases and coercion' do
    expect(described_class.summary([]))
      .to include('percentage' => 100.0, 'total' => 0, 'covered' => 0)
    expect(described_class.summary([nil, nil]))
      .to include('percentage' => 100.0, 'total' => 0, 'covered' => 0)
    expect(described_class.summary(['1', '0', nil]))
      .to include('percentage' => 50.0, 'total' => 2, 'covered' => 1)
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

  it 'load_coverage raises CoverageDataError on invalid JSON via model' do
    Dir.mktmpdir do |dir|
      bad = File.join(dir, '.resultset.json')
      File.write(bad, '{not-json')
      expect do
        CovLoupe::CoverageModel.new(root: root, resultset: dir)
      end.to raise_error(CovLoupe::CoverageDataError, /Invalid coverage data format/)
    end
  end
end
