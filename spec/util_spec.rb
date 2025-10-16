# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe SimpleCovMcp::CovUtil do
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
    end.to raise_error(SimpleCovMcp::FileError, /No coverage entry found/)

    # Missing raises a FileError
    cov = {}
    expect do
      described_class.lookup_lines(cov, '/nowhere/foo.rb')
    end.to raise_error(SimpleCovMcp::FileError, /No coverage entry found/)
  end

  it 'summary handles edge cases and coercion' do
    expect(described_class.summary([])).to include('pct' => 100.0, 'total' => 0, 'covered' => 0)
    expect(described_class.summary([nil, nil])) \
      .to include('pct' => 100.0, 'total' => 0, 'covered' => 0)
    expect(described_class.summary(['1', '0', nil])) \
      .to include('pct' => 50.0, 'total' => 2, 'covered' => 1)
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
        SimpleCovMcp::CoverageModel.new(root: root, resultset: dir)
      end.to raise_error(SimpleCovMcp::CoverageDataError, /Invalid coverage data format/)
    end
  end

  describe 'logging configuration' do
    let(:test_message) { 'test log message' }

    around(:each) do |example|
      # Reset logging settings so each example starts clean.
      old_default = SimpleCovMcp.default_log_file
      old_active = SimpleCovMcp.active_log_file
      SimpleCovMcp.default_log_file = nil
      SimpleCovMcp.active_log_file = nil

      example.run

      # Restore state
      SimpleCovMcp.default_log_file = old_default
      SimpleCovMcp.active_log_file = old_active
    end



    it "logs to stdout when active_log_file is 'stdout'" do
      SimpleCovMcp.active_log_file = 'stdout'
      expect(File).not_to receive(:open)
      expect { described_class.log(test_message) }
        .to output(/#{Regexp.escape(test_message)}/).to_stdout
    end

    it "logs to stderr when active_log_file is 'stderr'" do
      SimpleCovMcp.active_log_file = 'stderr'
      expect(File).not_to receive(:open)
      expect { described_class.log(test_message) }
        .to output(/#{Regexp.escape(test_message)}/).to_stderr
    end

    it 'log writes to file when path is configured' do
      tmp = Tempfile.new('simplecov_mcp-log')
      log_path = tmp.path
      tmp.close

      SimpleCovMcp.active_log_file = log_path

      described_class.log(test_message)

      expect(File.exist?(log_path)).to be true
      content = File.read(log_path)
      expect(content).to include(test_message)
      expect(content).to match(TIMESTAMP_REGEX)
    ensure
      tmp&.unlink
    end

    it 'log respects runtime changes disabling logging mid-run' do
      tmp = Tempfile.new('simplecov_mcp-log')
      log_path = tmp.path
      tmp.close

      SimpleCovMcp.active_log_file = log_path

      described_class.log('first entry')
      expect(File.exist?(log_path)).to be true
      first_content = File.read(log_path)
      expect(first_content).to include('first entry')

      SimpleCovMcp.active_log_file = 'stderr'

      expect { described_class.log('second entry') }
        .to output(/second entry/).to_stderr
      expect(File.exist?(log_path)).to be true
      expect(File.read(log_path)).to eq(first_content)
    ensure
      tmp&.unlink
    end

    it 'exposes default log file configuration separately' do
      original_default = SimpleCovMcp.default_log_file
      SimpleCovMcp.default_log_file = 'stderr'
      expect(SimpleCovMcp.default_log_file).to eq('stderr')
      expect(SimpleCovMcp.active_log_file).to eq('stderr')
    ensure
      SimpleCovMcp.default_log_file = original_default
    end

    it 'allows adjusting the active log target without touching the default' do
      original_default = SimpleCovMcp.default_log_file
      SimpleCovMcp.active_log_file = 'stdout'
      expect(SimpleCovMcp.active_log_file).to eq('stdout')
      expect(SimpleCovMcp.default_log_file).to eq(original_default)
    end
  end
end
