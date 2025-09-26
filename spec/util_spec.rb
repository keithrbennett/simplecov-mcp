# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::CovUtil do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }
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

  describe 'logging configuration' do
    let(:test_message) { 'test log message' }

    around(:each) do |example|
      # Reset SimpleCovMcp.log_file and clean environment
      old_log_file = SimpleCovMcp.log_file
      old_env = ENV['SIMPLECOV_MCP_LOG']
      ENV.delete('SIMPLECOV_MCP_LOG')
      SimpleCovMcp.log_file = nil

      example.run

      # Restore state
      SimpleCovMcp.log_file = old_log_file
      if old_env
        ENV['SIMPLECOV_MCP_LOG'] = old_env
      else
        ENV.delete('SIMPLECOV_MCP_LOG')
      end
    end

    it 'log_path uses default path when no configuration' do
      expect(described_class.log_path).to eq(File.expand_path('~/simplecov_mcp.log'))
    end

    it 'log_path respects SIMPLECOV_MCP_LOG environment variable' do
      ENV['SIMPLECOV_MCP_LOG'] = '/custom/log/path.log'
      expect(described_class.log_path).to eq('/custom/log/path.log')
    end

    it 'log_path returns nil for SIMPLECOV_MCP_LOG="-" (disable logging)' do
      ENV['SIMPLECOV_MCP_LOG'] = '-'
      expect(described_class.log_path).to be_nil
    end

    it 'log_path respects SimpleCovMcp.log_file setting' do
      SimpleCovMcp.log_file = '/module/log/path.log'
      expect(described_class.log_path).to eq('/module/log/path.log')
    end

    it 'log_path returns nil for SimpleCovMcp.log_file="-" (disable logging)' do
      SimpleCovMcp.log_file = '-'
      expect(described_class.log_path).to be_nil
    end

    it 'log_path prioritizes environment variable over SimpleCovMcp.log_file' do
      SimpleCovMcp.log_file = '/module/path.log'
      ENV['SIMPLECOV_MCP_LOG'] = '/env/path.log'
      expect(described_class.log_path).to eq('/env/path.log')
    end

    it 'log does not write when path is nil' do
      allow(described_class).to receive(:log_path).and_return(nil)
      expect(File).not_to receive(:open)
      described_class.log(test_message)
    end

    it 'log writes to file when path is configured' do
      Dir.mktmpdir do |dir|
        log_path = File.join(dir, 'test.log')
        allow(described_class).to receive(:log_path).and_return(log_path)

        described_class.log(test_message)

        expect(File.exist?(log_path)).to be true
        content = File.read(log_path)
        expect(content).to include(test_message)
        # TODO: Move that regex to a constant.
        expect(content).to match(/\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}\]/)
      end
    end
  end
end

