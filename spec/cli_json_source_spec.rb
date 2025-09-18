# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SimpleCovMcp::CoverageCLI do
  let(:root) { (FIXTURES / 'project1').to_s }

  def run_cli_json(*argv)
    cli = described_class.new
    out = nil
    silence_output do |stdout, _stderr|
      cli.run(argv.flatten)
      out = stdout.string
    end
    JSON.parse(out)
  end

  it 'includes source rows in JSON for summary --source=full' do
    data = run_cli_json('summary', 'lib/foo.rb', '--root', root, '--resultset', 'coverage', '--json', '--source=full')
    expect(data['file']).to eq('lib/foo.rb')
    expect(data['source']).to be_an(Array)
    expect(data['source'].first).to include('line', 'code', 'hits', 'covered')
  end

  it 'includes source rows in JSON for uncovered --source=uncovered' do
    data = run_cli_json('uncovered', 'lib/foo.rb', '--root', root, '--resultset', 'coverage', '--json', '--source=uncovered', '--source-context', '1')
    expect(data['file']).to eq('lib/foo.rb')
    expect(data['source']).to be_an(Array)
    # Only a subset of lines around uncovered should appear
    lines = data['source'].map { |h| h['line'] }
    expect(lines).to include(2) # the uncovered line
  end

  it 'includes source rows in JSON for detailed --source=full' do
    data = run_cli_json('detailed', 'lib/foo.rb', '--root', root, '--resultset', 'coverage', '--json', '--source=full')
    expect(data['file']).to eq('lib/foo.rb')
    expect(data['lines']).to be_an(Array)
    expect(data['source']).to be_an(Array)
  end

  it 'renders uncovered source with various context sizes without error' do
    [0, -5, 50].each do |ctx|
      out, err, status = begin
        cli = described_class.new
        s = nil
        o = e = nil
        silence_output do |stdout, stderr|
          begin
            cli.run(['uncovered', 'lib/foo.rb', '--root', root, '--resultset', 'coverage', '--source=uncovered', '--source-context', ctx.to_s, '--no-color'])
            s = 0
          rescue SystemExit => ex
            s = ex.status
          end
          o = stdout.string
          e = stderr.string
        end
        [o, e, s]
      end
      expect(status).to eq(0)
      expect(err).to eq("")
      expect(out).to include('File: lib/foo.rb')
      expect(out).to include('Uncovered lines: 2')
    end
  end

  it 'respects --color and --no-color for source rendering' do
    # Force color on
    out_color = begin
      cli = described_class.new
      silence_output do |stdout, _stderr|
        cli.run(['summary', 'lib/foo.rb', '--root', root, '--resultset', 'coverage', '--source', '--color'])
        stdout.string
      end
    end
    # If source table is rendered, it should contain ANSI escapes when color is on
    if out_color.include?('Line') && out_color.include?('|')
      expect(out_color).to match(/\e\[\d+m/)
    else
      expect(out_color).to include('[source not available]')
    end

    # Force color off: expect no ANSI sequences
    out_nocolor = begin
      cli = described_class.new
      silence_output do |stdout, _stderr|
        cli.run(['summary', 'lib/foo.rb', '--root', root, '--resultset', 'coverage', '--source', '--no-color'])
        stdout.string
      end
    end
    expect(out_nocolor).not_to match(/\e\[\d+m/)
  end
end
