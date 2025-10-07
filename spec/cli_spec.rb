# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe SimpleCovMcp::CoverageCLI do
  let(:root) { (FIXTURES_DIR / 'project1').to_s }

  def run_cli(*argv)
    cli = described_class.new
    silence_output do |out, _err|
      cli.run(argv.flatten)
      return out.string
    end
  end

  it 'prints summary as JSON for a file' do
    output = run_cli('summary', 'lib/foo.rb', '--json', '--root', root, '--resultset', 'coverage')
    data = JSON.parse(output)
    expect(data['file']).to end_with('lib/foo.rb')
    expect(data['summary']).to include('covered' => 2, 'total' => 3)
  end

  it 'prints raw lines as JSON' do
    output = run_cli('raw', 'lib/foo.rb', '--json', '--root', root, '--resultset', 'coverage')
    data = JSON.parse(output)
    expect(data['file']).to end_with('lib/foo.rb')
    expect(data['lines']).to eq([1, 0, nil, 2])
  end

  it 'prints raw lines as text' do
    output = run_cli('raw', 'lib/foo.rb', '--root', root, '--resultset', 'coverage')
    expect(output).to include('File: lib/foo.rb')
    expect(output).to include('[1, 0, nil, 2]')
  end

  it 'prints uncovered lines as JSON' do
    output = run_cli('uncovered', 'lib/foo.rb', '--json', '--root', root, '--resultset', 'coverage')
    data = JSON.parse(output)
    expect(data['uncovered']).to eq([2])
    expect(data['summary']).to include('total' => 3)
  end

  it 'prints detailed rows as JSON' do
    output = run_cli('detailed', 'lib/foo.rb', '--json', '--root', root, '--resultset', 'coverage')
    data = JSON.parse(output)
    expect(data['lines']).to be_an(Array)
    expect(data['lines'].first).to include('line', 'hits', 'covered')
  end

  it 'list subcommand with --json outputs JSON with sort order' do
    output = run_cli('list', '--json', '--root', root, '--resultset', 'coverage', '--sort-order', 'a')
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

    output = run_cli('list', '--json', '--root', root, '--resultset', 'coverage', '--sort-order', 'd')
    desc = JSON.parse(output)
    expect(desc['files'].first['file']).to end_with('lib/foo.rb')
  end

  it 'list subcommand outputs formatted table' do
    output = run_cli('list', '--root', root, '--resultset', 'coverage')
    expect(output).to include('File')
    expect(output).to include('lib/foo.rb')
    expect(output).to include('lib/bar.rb')
    expect(output).to match(/Files: total \d+/)
  end

  it 'exposes expected subcommands via constant' do
    expect(described_class::SUBCOMMANDS).to eq(%w[list summary raw uncovered detailed version])
  end

  it 'can include source in JSON payload (nil if file missing)' do
    output = run_cli('summary', 'lib/foo.rb', '--json', '--root', root, '--resultset', 'coverage', '--source')
    data = JSON.parse(output)
    expect(data).to have_key('source')
  end

  describe 'log file configuration' do
    around(:each) do |example|
      # Reset SimpleCovMcp.log_file
      old_log_file = SimpleCovMcp.log_file
      SimpleCovMcp.log_file = nil
      example.run
      SimpleCovMcp.log_file = old_log_file
    end

    it 'sets global log file from --log-file option' do
      Dir.mktmpdir do |dir|
        log_path = File.join(dir, 'custom.log')
        run_cli('summary', 'lib/foo.rb', '--json', '--root', root, '--resultset', 'coverage', '--log-file', log_path)
        expect(SimpleCovMcp.log_file).to eq(log_path)
      end
    end

    it 'handles --log-file - (disable logging)' do
      run_cli('summary', 'lib/foo.rb', '--json', '--root', root, '--resultset', 'coverage', '--log-file', '-')
      expect(SimpleCovMcp.log_file).to eq('-')
    end
  end

  describe '#load_success_predicate' do
    let(:cli) { described_class.new }

    def with_temp_predicate(content)
      Tempfile.create(['predicate', '.rb']) do |file|
        file.write(content)
        file.flush
        yield file.path
      end
    end

    it 'loads a callable predicate from file' do
      with_temp_predicate("->(model) { model }\n") do |path|
        predicate = cli.send(:load_success_predicate, path)
        expect(predicate).to respond_to(:call)
        expect(predicate.call(:ok)).to eq(:ok)
      end
    end

    it 'raises when file does not return callable' do
      with_temp_predicate(":not_callable\n") do |path|
        expect { cli.send(:load_success_predicate, path) }
          .to raise_error(RuntimeError, include('Success predicate must be callable'))
      end
    end

    it 'wraps syntax errors with friendly message' do
      with_temp_predicate("->(model) {\n") do |path|
        expect { cli.send(:load_success_predicate, path) }
          .to raise_error(RuntimeError, include('Syntax error in success predicate file'))
      end
    end
  end
end
