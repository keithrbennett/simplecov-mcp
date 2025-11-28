# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe SimpleCovMcp::CoverageCLI do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }

  def run_cli(*argv)
    cli = described_class.new
    silence_output do |out, _err|
      begin
        cli.run(argv.flatten)
      rescue SystemExit
        # Ignore exit, just capture output
      end
      return out.string
    end
  end

  it 'prints summary as JSON for a file' do
    output = run_cli('--json', '--root', root, '--resultset', 'coverage', 'summary', 'lib/foo.rb')
    data = JSON.parse(output)
    expect(data['file']).to end_with('lib/foo.rb')
    expect(data['summary']).to include('covered' => 2, 'total' => 3)
  end

  it 'prints raw lines as JSON' do
    output = run_cli('--json', '--root', root, '--resultset', 'coverage', 'raw', 'lib/foo.rb')
    data = JSON.parse(output)
    expect(data['file']).to end_with('lib/foo.rb')
    expect(data['lines']).to eq([1, 0, nil, 2])
  end

  it 'prints raw lines as text' do
    output = run_cli('--root', root, '--resultset', 'coverage', 'raw', 'lib/foo.rb')
    expect(output).to include('File: lib/foo.rb')
    expect(output).to include('[1, 0, nil, 2]')
  end

  it 'prints uncovered lines as JSON' do
    output = run_cli('--json', '--root', root, '--resultset', 'coverage', 'uncovered', 'lib/foo.rb')
    data = JSON.parse(output)
    expect(data['uncovered']).to eq([2])
    expect(data['summary']).to include('total' => 3)
  end

  it 'prints detailed rows as JSON' do
    output = run_cli('--json', '--root', root, '--resultset', 'coverage', 'detailed', 'lib/foo.rb')
    data = JSON.parse(output)
    expect(data['lines']).to be_an(Array)
    expect(data['lines'].first).to include('line', 'hits', 'covered')
  end

  it 'list subcommand with --json outputs JSON with sort order' do
    output = run_cli('--json', '--root', root, '--resultset', 'coverage', '--sort-order', 'a',
      'list')
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

    output = run_cli('--json', '--root', root, '--resultset', 'coverage', '--sort-order', 'd',
      'list')
    desc = JSON.parse(output)
    expect(desc['files'].first['file']).to end_with('lib/foo.rb')
  end

  it 'list subcommand outputs formatted table' do
    output = run_cli('--root', root, '--resultset', 'coverage', 'list')
    expect(output).to include('File')
    expect(output).to include('lib/foo.rb')
    expect(output).to include('lib/bar.rb')
    expect(output).to match(/Files: total \d+/)
  end

  it 'list subcommand retains rows when using an absolute tracked glob' do
    absolute_glob = File.join(root, 'lib', '**', '*.rb')
    output = run_cli('--root', root, '--resultset', 'coverage', '--tracked-globs',
      absolute_glob, 'list')
    expect(output).not_to include('No coverage data found')
    expect(output).to include('lib/foo.rb')
    expect(output).to include('lib/bar.rb')
  end

  it 'total subcommand outputs JSON totals when requested' do
    output = run_cli('--json', '--root', root, '--resultset', 'coverage', 'total')
    data = JSON.parse(output)
    expect(data['lines']).to include('total' => 6, 'covered' => 3, 'uncovered' => 3)
    expect(data['files']).to include('total' => 2)
    expect(data['files']['ok'] + data['files']['stale']).to eq(data['files']['total'])
  end

  it 'total subcommand prints a readable summary by default' do
    output = run_cli('--root', root, '--resultset', 'coverage', 'total')
    expect(output).to include('Lines:')
    expect(output).to include('Average coverage:')
  end

  it 'can include source in JSON payload (nil if file missing)' do
    output = run_cli('--json', '--root', root, '--resultset', 'coverage',
      '--source', 'summary', 'lib/foo.rb')
    data = JSON.parse(output)
    expect(data).to have_key('source')
  end

  describe 'log file configuration' do
    it 'passes --log-file path into the CLI execution context' do
      Dir.mktmpdir do |dir|
        log_path = File.join(dir, 'custom.log')
        expect(SimpleCovMcp).to receive(:create_context)
          .and_wrap_original do |m, error_handler:, log_target:, mode:|
          # Ensure CLI forwards the requested log path into the context without changing other fields.
          expect(log_target).to eq(log_path)
          m.call(error_handler: error_handler, log_target: log_target, mode: mode)
        end
        original_target = SimpleCovMcp.active_log_file
        run_cli('--json', '--root', root, '--resultset', 'coverage',
          '--log-file', log_path, 'summary', 'lib/foo.rb')
        expect(SimpleCovMcp.active_log_file).to eq(original_target)
      end
    end

    it 'supports stdout logging within the CLI context' do
      expect(SimpleCovMcp).to receive(:create_context)
        .and_wrap_original do |m, error_handler:, log_target:, mode:|
        # For stdout logging, verify the context is still constructed with the expected value.
        expect(log_target).to eq('stdout')
        m.call(error_handler: error_handler, log_target: log_target, mode: mode)
      end
      original_target = SimpleCovMcp.active_log_file
      run_cli('--json', '--root', root, '--resultset', 'coverage',
        '--log-file', 'stdout', 'summary', 'lib/foo.rb')
      expect(SimpleCovMcp.active_log_file).to eq(original_target)
    end
  end





  describe 'version command' do
    it 'prints version as plain text by default' do
      output = run_cli('version')
      expect(output).to include('SimpleCovMcp version')
      expect(output).to include(SimpleCovMcp::VERSION)
      expect(output).not_to include('{')
      expect(output).not_to include('}')
    end

    it 'prints version as JSON when --json flag is used' do
      output = run_cli('--json', 'version')
      data = JSON.parse(output)
      expect(data).to have_key('version')
      expect(data['version']).to eq(SimpleCovMcp::VERSION)
    end

    it 'works with version command and other flags' do
      output = run_cli('version', '--root', root)
      expect(output).to include('SimpleCovMcp version')
      expect(output).to include(SimpleCovMcp::VERSION)
    end
  end

  describe 'version option (-v)' do
    it 'prints the same version info as the version subcommand' do
      output = run_cli('-v')
      expect(output).to include('SimpleCovMcp version')
      expect(output).to include(SimpleCovMcp::VERSION)
    end

    it 'respects --json when -v is used' do
      output = run_cli('-v', '--json')
      data = JSON.parse(output)
      expect(data['version']).to eq(SimpleCovMcp::VERSION)
    end
  end
end
