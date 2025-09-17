# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::CoverageCLI do
  let(:root) { (FIXTURES / 'project1').to_s }

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

  it 'lists all files as JSON with sort order' do
    output = run_cli('list', '--json', '--root', root, '--resultset', 'coverage', '--sort-order', 'ascending')
    asc = JSON.parse(output)
    expect(asc['files']).to be_an(Array)
    expect(asc['files'].first['file']).to end_with('lib/bar.rb')

    output = run_cli('list', '--json', '--root', root, '--resultset', 'coverage', '--sort-order', 'descending')
    desc = JSON.parse(output)
    expect(desc['files'].first['file']).to end_with('lib/foo.rb')
  end

  it 'exposes expected subcommands via constant' do
    expect(described_class::SUBCOMMANDS).to eq(%w[list summary raw uncovered detailed version])
  end

  it 'can include source in JSON payload (nil if file missing)' do
    output = run_cli('summary', 'lib/foo.rb', '--json', '--root', root, '--resultset', 'coverage', '--source')
    data = JSON.parse(output)
    expect(data).to have_key('source')
  end
end
