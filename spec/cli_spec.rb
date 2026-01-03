# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe CovLoupe::CoverageCLI do
  let(:fixture_root) { File.dirname(FIXTURE_PROJECT1_RESULTSET_PATH, 2) }

  # Windows refuses to delete a temporary directory while a file handle inside it
  # remains open, so we ensure the logger (and its file) are closed after each use.
  # We do this so that the tests will run on Windows (including for CI),
  # but this workaround should not be necessary for a Windows production system
  # since the log file is not created by Dir.mktmpdir.
  def with_temp_cli_log_file(file_name = 'custom.log')
    Dir.mktmpdir do |dir|
      log_path = File.join(dir, file_name)
      captured_std_logger = nil
      begin
        yield log_path, ->(logger) { captured_std_logger = logger.instance_variable_get(:@logger) }
      ensure
        captured_std_logger&.close
      end
    end
  end

  def run_cli(*argv)
    run_fixture_cli_output(*argv)
  end

  describe 'JSON output' do
    def with_json_output(command, *args)
      output = run_cli('--format', 'json', command, *args)
      yield JSON.parse(output)
    end

    [
      { cmd: 'summary', args: ['lib/foo.rb'], key: 'summary', check: ->(d) {
        d['summary']['covered'] == 2
      } },
      { cmd: 'raw', args: ['lib/foo.rb'], key: 'lines', check: ->(d) {
        d['lines'] == [nil, nil, 1, 0, nil, 2]
      } },
      { cmd: 'uncovered', args: ['lib/foo.rb'], key: 'uncovered', check: ->(d) {
        d['uncovered'] == [4]
      } },
      { cmd: 'detailed', args: ['lib/foo.rb'], key: 'lines', check: ->(d) {
        d['lines'].is_a?(Array)
      } }
    ].each do |tc|
      it "prints #{tc[:cmd]} as JSON" do
        with_json_output(tc[:cmd], *tc[:args]) do |data|
          expect(tc[:check].call(data)).to be true
        end
      end
    end

    it 'prints totals as JSON' do
      with_json_output('totals') do |data|
        expect(data['lines']).to include(
          'total' => 6,
          'covered' => 3,
          'uncovered' => 3,
          'percent_covered' => be_within(0.01).of(50.0)
        )
        expect(data['tracking']).to include('enabled' => true)
        expect(data['files']).to include('total' => 3)
        expect(data['files']['with_coverage']).to include('total' => 2, 'ok' => 2)
        expect(data['files']['without_coverage']).to include('total' => 1)
        expect(data['files']['without_coverage']['by_type'])
          .to include('missing_from_coverage' => 1)
      end
    end
  end

  it 'prints raw lines as text' do
    output = run_cli('raw', 'lib/foo.rb')
    expect(output).to include('File: lib/foo.rb', '│') # Table format
  end

  it 'list subcommand with --json outputs JSON with sort order' do
    output = run_cli(
      '--format', 'json', '--sort-order', 'a', 'list'
    )
    asc = JSON.parse(output)
    expect(asc['files']).to be_an(Array)
    expect(asc['files'].first['file']).to end_with('lib/bar.rb')

    # Includes counts for total/ok/stale and they are consistent
    expect(asc['counts']).to include('total', 'ok', 'stale')
    total = asc['counts']['total']
    ok = asc['counts']['ok']
    stale = asc['counts']['stale']
    expect(total).to eq(asc['files'].length)
    expect(ok + stale).to eq(total)

    output = run_cli(
      '--format', 'json', '--sort-order', 'd', 'list'
    )
    desc = JSON.parse(output)
    expect(desc['files'].first['file']).to end_with('lib/foo.rb')
  end

  it 'list subcommand outputs formatted table' do
    output = run_cli('list')
    expect(output).to include('File', 'lib/foo.rb', 'lib/bar.rb')
    expect(output).to match(/Files: total \d+/)
  end

  it 'list subcommand retains rows when using an absolute tracked glob' do
    absolute_glob = File.join(fixture_root, 'lib', '**', '*.rb')
    output = run_cli('--tracked-globs',
      absolute_glob, 'list')
    expect(output).not_to include('No coverage data found')
    expect(output).to include('lib/foo.rb', 'lib/bar.rb')
  end

  it 'totals subcommand prints a readable summary by default' do
    output = run_cli('totals')
    expect(output).to include('│', 'Lines') # Table format
    # expect(output).to include('Average coverage:')  # Not in table version
  end

  it 'can include source in JSON payload (nil if file missing)' do
    output = run_cli('--format', 'json', '--source', 'full', 'summary', 'lib/foo.rb')
    data = JSON.parse(output)
    expect(data).to have_key('source')
  end

  describe 'log file configuration' do
    it 'passes --log-file path into the CLI execution context' do
      original_target = CovLoupe.active_log_file
      with_temp_cli_log_file do |log_path, capture_logger|
        expect(CovLoupe).to receive(:create_context)
          .and_wrap_original do |m, error_handler:, log_target:, mode:|
          # Ensure CLI forwards the requested log path into the context without changing other fields.
          expect(log_target).to eq(log_path)
          context = m.call(error_handler: error_handler, log_target: log_target, mode: mode)
          capture_logger.call(context.logger)
          context
        end
        run_cli('--format', 'json', '--log-file', log_path, 'summary', 'lib/foo.rb')
        expect(CovLoupe.active_log_file).to eq(original_target)
      end
    end

    it 'supports stdout logging within the CLI context' do
      expect(CovLoupe).to receive(:create_context)
        .and_wrap_original do |m, error_handler:, log_target:, mode:|
        # For stdout logging, verify the context is still constructed with the expected value.
        expect(log_target).to eq('stdout')
        m.call(error_handler: error_handler, log_target: log_target, mode: mode)
      end
      original_target = CovLoupe.active_log_file
      run_cli('--format', 'json', '--log-file', 'stdout', 'summary', 'lib/foo.rb')
      expect(CovLoupe.active_log_file).to eq(original_target)
    end
  end

  describe 'version command' do
    it 'prints version as plain text by default' do
      output = run_cli('version')
      expect(output).to include('│', CovLoupe::VERSION) # Table format
      expect(output).not_to include('{')
      expect(output).not_to include('}')
    end

    it 'prints version as JSON when --json flag is used' do
      output = run_cli('--format', 'json', 'version')
      data = JSON.parse(output)
      expect(data).to have_key('version')
      expect(data['version']).to eq(CovLoupe::VERSION)
    end

    it 'works with version command and other flags' do
      output = run_cli('--color=false', 'version')
      expect(output).to include('│', CovLoupe::VERSION) # Table format
    end
  end

  describe 'version option (-v)' do
    it 'prints the same version info as the version subcommand' do
      output = run_cli('-v')
      expect(output).to include('│', CovLoupe::VERSION) # Table format
    end

    it 'respects --json when -v is used' do
      output = run_cli('-v', '--format', 'json')
      data = JSON.parse(output)
      expect(data['version']).to eq(CovLoupe::VERSION)
    end
  end
end
